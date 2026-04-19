defmodule Raxol.Property.StylePreservationTest do
  @moduledoc """
  Property tests verifying that style information (colors, text attributes)
  is never silently dropped as data flows through the rendering pipeline.

  Pipeline under test:
    text/2 -> Layout.Engine.process_element -> StyleProcessor.flatten_merged_style
           -> ElementRenderer.render_text -> cell tuples {x, y, char, fg, bg, attrs}

  Bug class: silent data loss through pipeline stages (see issue #209).
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raxol.Core.Renderer.View.Components.Text
  alias Raxol.UI.Layout.Engine
  alias Raxol.UI.ElementRenderer
  alias Raxol.UI.StyleProcessor

  # -- Generators --

  @named_colors [:red, :green, :blue, :yellow, :cyan, :magenta, :white, :black]
  @text_attrs [:bold, :italic, :underline]

  defp color_gen do
    one_of([
      member_of(@named_colors),
      # RGB tuple
      tuple({integer(0..255), integer(0..255), integer(0..255)}),
      # 256-color index
      integer(0..255)
    ])
  end

  defp text_attr_subset_gen do
    # Generate a non-empty subset of text attributes
    list_of(member_of(@text_attrs), min_length: 1, max_length: 3)
    |> map(&Enum.uniq/1)
  end

  defp printable_text_gen do
    string(:printable, min_length: 1, max_length: 20)
    |> filter(fn s -> String.trim(s) != "" end)
  end

  defp layout_space do
    %{x: 0, y: 0, width: 80, height: 24}
  end

  # -- Property 1: Layout engine preserves fg/bg --

  describe "Layout.Engine.process_element/3 style preservation" do
    property "fg color on input element appears on output element" do
      check all(
              content <- printable_text_gen(),
              fg <- color_gen(),
              max_runs: 500
            ) do
        input = %{type: :text, content: content, fg: fg, bg: nil, style: []}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.fg == fg,
               "fg #{inspect(fg)} dropped by layout engine, got #{inspect(output.fg)}"
      end
    end

    property "bg color on input element appears on output element" do
      check all(
              content <- printable_text_gen(),
              bg <- color_gen(),
              max_runs: 500
            ) do
        input = %{type: :text, content: content, fg: nil, bg: bg, style: []}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.bg == bg,
               "bg #{inspect(bg)} dropped by layout engine, got #{inspect(output.bg)}"
      end
    end

    property "style attrs on input element survive as map keys on output" do
      check all(
              content <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 500
            ) do
        input = %{type: :text, content: content, fg: nil, bg: nil, style: attrs}
        [output] = Engine.process_element(input, layout_space(), [])

        # Style list should be normalized to a map with true values
        style_map = output.style

        assert is_map(style_map),
               "style should be a map after layout engine, got #{inspect(style_map)}"

        for attr <- attrs do
          assert Map.get(style_map, attr) == true,
                 "style attr #{inspect(attr)} dropped by layout engine"
        end
      end
    end

    property "content text is never altered by layout engine" do
      check all(
              content <- printable_text_gen(),
              max_runs: 500
            ) do
        input = %{type: :text, content: content, fg: nil, bg: nil, style: []}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.text == content,
               "content altered: expected #{inspect(content)}, got #{inspect(output.text)}"
      end
    end
  end

  # -- Property 2: Widget types preserve fg/bg through layout engine --

  describe "Layout.Engine widget style preservation" do
    property "checkbox preserves fg/bg on generated text element" do
      check all(
              label <- printable_text_gen(),
              fg <- color_gen(),
              bg <- color_gen(),
              checked <- boolean(),
              max_runs: 300
            ) do
        input = %{
          type: :checkbox,
          attrs: %{label: label, checked: checked, fg: fg, bg: bg}
        }

        elements = Engine.process_element(input, layout_space(), [])
        text_el = Enum.find(elements, &(&1.type == :text))

        assert text_el != nil, "checkbox produced no text element"
        assert text_el.fg == fg, "checkbox fg dropped"
        assert text_el.bg == bg, "checkbox bg dropped"
      end
    end

    property "text_input preserves fg/bg on generated text element" do
      check all(
              value <- printable_text_gen(),
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 300
            ) do
        input = %{
          type: :text_input,
          attrs: %{value: value, fg: fg, bg: bg}
        }

        elements = Engine.process_element(input, layout_space(), [])
        text_el = Enum.find(elements, &(&1.type == :text))

        assert text_el != nil, "text_input produced no text element"
        assert text_el.fg == fg, "text_input fg dropped"
        assert text_el.bg == bg, "text_input bg dropped"
      end
    end

    property "button (new format) preserves fg/bg on generated text element" do
      check all(
              label <- printable_text_gen(),
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 300
            ) do
        input = %{type: :button, text: label, fg: fg, bg: bg}

        elements = Engine.process_element(input, layout_space(), [])
        text_el = Enum.find(elements, &(&1.type == :text))

        assert text_el != nil, "button produced no text element"
        assert text_el.fg == fg, "button fg dropped"
        assert text_el.bg == bg, "button bg dropped"
      end
    end

    property "checkbox preserves style attrs on generated text element" do
      check all(
              label <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 300
            ) do
        input = %{
          type: :checkbox,
          attrs: %{label: label, checked: false, style: attrs}
        }

        elements = Engine.process_element(input, layout_space(), [])
        text_el = Enum.find(elements, &(&1.type == :text))

        assert is_map(text_el.style), "checkbox style not normalized to map"

        for attr <- attrs do
          assert Map.get(text_el.style, attr) == true,
                 "checkbox style attr #{inspect(attr)} dropped"
        end
      end
    end
  end

  # -- Property 3: ElementRenderer preserves colors in cell tuples --

  describe "ElementRenderer.render_text/5 color preservation" do
    property "fg color in style map appears in every cell tuple" do
      check all(
              content <- printable_text_gen(),
              fg <- color_gen(),
              max_runs: 500
            ) do
        style = %{fg: fg, bg: :black}
        cells = ElementRenderer.render_text(0, 0, content, style, %{})

        assert length(cells) > 0, "render_text produced no cells"

        for {_x, _y, _char, cell_fg, _bg, _attrs} <- cells do
          assert cell_fg == fg,
                 "fg #{inspect(fg)} not in cell tuple, got #{inspect(cell_fg)}"
        end
      end
    end

    property "bg color in style map appears in every cell tuple" do
      check all(
              content <- printable_text_gen(),
              bg <- color_gen(),
              max_runs: 500
            ) do
        style = %{fg: :white, bg: bg}
        cells = ElementRenderer.render_text(0, 0, content, style, %{})

        assert length(cells) > 0

        for {_x, _y, _char, _fg, cell_bg, _attrs} <- cells do
          assert cell_bg == bg,
                 "bg #{inspect(bg)} not in cell tuple, got #{inspect(cell_bg)}"
        end
      end
    end

    property "text attributes in style map appear in cell tuple attrs" do
      check all(
              content <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 500
            ) do
        style_map =
          Enum.reduce(attrs, %{fg: :white, bg: :black}, fn attr, acc ->
            Map.put(acc, attr, true)
          end)

        cells = ElementRenderer.render_text(0, 0, content, style_map, %{})

        assert length(cells) > 0

        for {_x, _y, _char, _fg, _bg, cell_attrs} <- cells do
          for attr <- attrs do
            assert attr in cell_attrs,
                   "attr #{inspect(attr)} not in cell attrs #{inspect(cell_attrs)}"
          end
        end
      end
    end

    property "absent text attributes do not appear in cell tuple attrs" do
      check all(
              content <- printable_text_gen(),
              max_runs: 200
            ) do
        style = %{fg: :white, bg: :black}
        cells = ElementRenderer.render_text(0, 0, content, style, %{})

        for {_x, _y, _char, _fg, _bg, cell_attrs} <- cells do
          assert cell_attrs == [],
                 "unexpected attrs #{inspect(cell_attrs)} when none were set"
        end
      end
    end
  end

  # -- Property 4: Table cell attrs --

  describe "ElementRenderer table cell attrs" do
    property "table data rows render bold/italic/underline from row_style" do
      check all(
              cell_text <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 300
            ) do
        row_style =
          Enum.reduce(attrs, %{fg: :cyan, bg: :black}, fn attr, acc ->
            Map.put(acc, attr, true)
          end)

        table_attrs = %{
          _headers: [],
          _data: [[cell_text]],
          _col_widths: [20],
          row_style: row_style
        }

        cells = ElementRenderer.render_table(0, 0, 80, 5, table_attrs, %{})

        # All cells from a headerless single-row table are data cells
        assert length(cells) > 0, "table produced no cells"

        for {_x, _y, _char, _fg, _bg, cell_attrs} <- cells do
          for attr <- attrs do
            assert attr in cell_attrs,
                   "table cell attr #{inspect(attr)} missing, got #{inspect(cell_attrs)}"
          end
        end
      end
    end
  end

  # -- Property 5: style_to_map edge cases --

  describe "Layout.Engine.process_element style_to_map robustness" do
    property "empty style list produces empty map" do
      check all(
              content <- printable_text_gen(),
              max_runs: 100
            ) do
        input = %{type: :text, content: content, fg: nil, bg: nil, style: []}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.style == %{}, "empty list should become empty map"
      end
    end

    property "nil style produces empty map" do
      check all(
              content <- printable_text_gen(),
              max_runs: 100
            ) do
        input = %{type: :text, content: content, fg: nil, bg: nil, style: nil}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.style == %{}, "nil style should become empty map"
      end
    end

    property "map style passes through unchanged" do
      check all(
              content <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 300
            ) do
        style_map =
          Enum.reduce(attrs, %{}, fn attr, acc -> Map.put(acc, attr, true) end)

        input = %{type: :text, content: content, fg: nil, bg: nil, style: style_map}
        [output] = Engine.process_element(input, layout_space(), [])

        assert output.style == style_map,
               "map style should pass through unchanged"
      end
    end

    property "non-atom entries in style list are silently skipped" do
      check all(
              content <- printable_text_gen(),
              max_runs: 100
            ) do
        # Mix atoms and non-atoms
        input = %{
          type: :text,
          content: content,
          fg: nil,
          bg: nil,
          style: [:bold, "not_an_atom", 42, :italic]
        }

        [output] = Engine.process_element(input, layout_space(), [])

        assert output.style == %{bold: true, italic: true},
               "non-atoms should be skipped, got #{inspect(output.style)}"
      end
    end
  end

  # -- Property 6: StyleProcessor preserves colors from element --

  describe "StyleProcessor.flatten_merged_style/3 preservation" do
    property "fg/bg on child element survive flattening with empty parent" do
      check all(
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 500
            ) do
        child = %{type: :text, fg: fg, bg: bg, style: %{}}
        result = StyleProcessor.flatten_merged_style(%{}, child, :default)

        result_fg = Map.get(result, :fg) || Map.get(result, :foreground)
        result_bg = Map.get(result, :bg) || Map.get(result, :background)

        assert result_fg == fg,
               "fg #{inspect(fg)} lost after flatten, got #{inspect(result_fg)}"

        assert result_bg == bg,
               "bg #{inspect(bg)} lost after flatten, got #{inspect(result_bg)}"
      end
    end

    property "text attrs in child style map survive flattening" do
      check all(
              attrs <- text_attr_subset_gen(),
              max_runs: 500
            ) do
        style_map =
          Enum.reduce(attrs, %{}, fn attr, acc -> Map.put(acc, attr, true) end)

        child = %{type: :text, style: style_map}
        result = StyleProcessor.flatten_merged_style(%{}, child, :default)

        for attr <- attrs do
          assert Map.get(result, attr) == true,
                 "attr #{inspect(attr)} lost after flatten, got #{inspect(Map.get(result, attr))}"
        end
      end
    end

    property "child fg/bg override parent fg/bg" do
      check all(
              parent_fg <- color_gen(),
              child_fg <- color_gen(),
              max_runs: 500
            ) do
        parent = %{fg: parent_fg}
        child = %{type: :text, fg: child_fg, style: %{}}
        result = StyleProcessor.flatten_merged_style(parent, child, :default)

        result_fg = Map.get(result, :fg) || Map.get(result, :foreground)

        assert result_fg == child_fg,
               "child fg #{inspect(child_fg)} should override parent #{inspect(parent_fg)}, got #{inspect(result_fg)}"
      end
    end

    property "child nil fg/bg inherits from parent" do
      check all(
              parent_fg <- member_of(@named_colors),
              parent_bg <- member_of(@named_colors),
              max_runs: 300
            ) do
        parent = %{fg: parent_fg, bg: parent_bg}
        child = %{type: :text, fg: nil, bg: nil, style: %{}}
        result = StyleProcessor.flatten_merged_style(parent, child, :default)

        result_fg = Map.get(result, :fg) || Map.get(result, :foreground)
        result_bg = Map.get(result, :bg) || Map.get(result, :background)

        assert result_fg == parent_fg,
               "nil child fg should inherit parent #{inspect(parent_fg)}, got #{inspect(result_fg)}"

        assert result_bg == parent_bg,
               "nil child bg should inherit parent #{inspect(parent_bg)}, got #{inspect(result_bg)}"
      end
    end

    property "foreground key takes precedence over fg key" do
      check all(
              fg_color <- member_of(@named_colors),
              foreground_color <- member_of(@named_colors),
              fg_color != foreground_color,
              max_runs: 200
            ) do
        child = %{type: :text, fg: fg_color, foreground: foreground_color, style: %{}}
        result = StyleProcessor.flatten_merged_style(%{}, child, :default)

        # promote_colors checks :foreground before :fg, so :foreground wins
        result_fg = Map.get(result, :fg)

        assert result_fg == foreground_color,
               ":foreground #{inspect(foreground_color)} should take precedence over :fg #{inspect(fg_color)}, got #{inspect(result_fg)}"
      end
    end
  end

  # -- Property 7: End-to-end pipeline --

  describe "end-to-end: text/2 -> layout -> style -> cells" do
    property "fg color survives the full pipeline" do
      check all(
              content <- printable_text_gen(),
              fg <- member_of(@named_colors),
              max_runs: 300
            ) do
        # Step 1: Build element via text/2
        element = Text.new(content, fg: fg)
        assert element.fg == fg, "text/2 dropped fg"

        # Step 2: Layout engine
        [laid_out] = Engine.process_element(element, layout_space(), [])
        assert laid_out.fg == fg, "layout engine dropped fg"

        # Step 3: StyleProcessor
        merged = StyleProcessor.flatten_merged_style(%{}, laid_out, :default)
        merged_fg = Map.get(merged, :fg) || Map.get(merged, :foreground)
        assert merged_fg == fg, "style processor dropped fg"

        # Step 4: ElementRenderer
        cells = ElementRenderer.render_text(0, 0, content, merged, %{})

        for {_x, _y, _char, cell_fg, _bg, _attrs} <- cells do
          assert cell_fg == fg,
                 "cell fg should be #{inspect(fg)}, got #{inspect(cell_fg)}"
        end
      end
    end

    property "bg color survives the full pipeline" do
      check all(
              content <- printable_text_gen(),
              bg <- member_of(@named_colors),
              max_runs: 300
            ) do
        element = Text.new(content, bg: bg)
        [laid_out] = Engine.process_element(element, layout_space(), [])
        merged = StyleProcessor.flatten_merged_style(%{}, laid_out, :default)
        cells = ElementRenderer.render_text(0, 0, content, merged, %{})

        for {_x, _y, _char, _fg, cell_bg, _attrs} <- cells do
          assert cell_bg == bg,
                 "cell bg should be #{inspect(bg)}, got #{inspect(cell_bg)}"
        end
      end
    end

    property "text attrs survive the full pipeline" do
      check all(
              content <- printable_text_gen(),
              attrs <- text_attr_subset_gen(),
              max_runs: 300
            ) do
        element = Text.new(content, style: attrs)

        [laid_out] = Engine.process_element(element, layout_space(), [])

        # Layout engine normalizes list to map
        assert is_map(laid_out.style), "layout should normalize style list to map"

        merged = StyleProcessor.flatten_merged_style(%{}, laid_out, :default)
        cells = ElementRenderer.render_text(0, 0, content, merged, %{})

        for {_x, _y, _char, _fg, _bg, cell_attrs} <- cells do
          for attr <- attrs do
            assert attr in cell_attrs,
                   "attr #{inspect(attr)} lost in pipeline, cell_attrs: #{inspect(cell_attrs)}"
          end
        end
      end
    end

    property "combined fg + bg + attrs all survive the full pipeline" do
      check all(
              content <- printable_text_gen(),
              fg <- member_of(@named_colors),
              bg <- member_of(@named_colors),
              attrs <- text_attr_subset_gen(),
              max_runs: 300
            ) do
        element = Text.new(content, fg: fg, bg: bg, style: attrs)
        [laid_out] = Engine.process_element(element, layout_space(), [])
        merged = StyleProcessor.flatten_merged_style(%{}, laid_out, :default)
        cells = ElementRenderer.render_text(0, 0, content, merged, %{})

        for {_x, _y, _char, cell_fg, cell_bg, cell_attrs} <- cells do
          assert cell_fg == fg, "fg lost: expected #{inspect(fg)}, got #{inspect(cell_fg)}"
          assert cell_bg == bg, "bg lost: expected #{inspect(bg)}, got #{inspect(cell_bg)}"

          for attr <- attrs do
            assert attr in cell_attrs, "attr #{inspect(attr)} lost, got #{inspect(cell_attrs)}"
          end
        end
      end
    end
  end
end
