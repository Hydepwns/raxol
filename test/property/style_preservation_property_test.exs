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

  # -- Property 2: ElementRenderer preserves colors in cell tuples --

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

  # -- Property 3: StyleProcessor preserves colors from element --

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
  end

  # -- Property 4: End-to-end pipeline --

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
