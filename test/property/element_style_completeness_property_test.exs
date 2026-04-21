defmodule Raxol.Property.ElementStyleCompletenessTest do
  @moduledoc """
  Property tests verifying that ALL element types preserve their :style map
  through the layout engine's process_element/3.

  Bug class: silent style data loss (see issues #217, spacer variant).

  The layout engine transforms View DSL elements into positioned output
  elements. Some element types (divider, spacer) were missing the :style
  key in their output, causing the renderer to fall back to defaults.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Raxol.Test.PropertyGenerators

  alias Raxol.UI.Layout.Engine
  alias Raxol.View.Components

  # -- Property 1: divider preserves :style through layout engine --

  describe "divider style preservation (#217)" do
    property "process_element output contains :style matching input" do
      check all(element <- divider_gen(), max_runs: 500) do
        input_style = element.style
        [output] = Engine.process_element(element, layout_space(), [])

        assert Map.has_key?(output, :style),
               "divider output has no :style key -- style silently dropped by layout engine"

        assert output.style == input_style,
               "divider style mismatch: input #{inspect(input_style)}, output #{inspect(output.style)}"
      end
    end

    property "Components.divider/1 style survives layout engine" do
      check all(
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 300
            ) do
        element = Components.divider(style: %{fg: fg, bg: bg}, char: "-")
        [output] = Engine.process_element(element, layout_space(), [])

        output_style = Map.get(output, :style, %{})

        assert Map.get(output_style, :fg) == fg,
               "divider fg #{inspect(fg)} lost through layout engine"

        assert Map.get(output_style, :bg) == bg,
               "divider bg #{inspect(bg)} lost through layout engine"
      end
    end

    property "divider char is preserved alongside style" do
      check all(element <- divider_gen(), max_runs: 300) do
        [output] = Engine.process_element(element, layout_space(), [])

        assert output.char == element.char,
               "divider char lost: expected #{inspect(element.char)}, got #{inspect(output.char)}"
      end
    end
  end

  # -- Property 2: spacer preserves :style through layout engine --

  describe "spacer style preservation" do
    property "process_element output contains :style matching input" do
      check all(element <- spacer_gen(), max_runs: 500) do
        input_style = element.style
        [output] = Engine.process_element(element, layout_space(), [])

        assert Map.has_key?(output, :style),
               "spacer output has no :style key -- style silently dropped by layout engine"

        assert output.style == input_style,
               "spacer style mismatch: input #{inspect(input_style)}, output #{inspect(output.style)}"
      end
    end
  end

  # -- Property 3: generalized -- every styled element type preserves :style --

  describe "generalized style preservation" do
    property "divider with arbitrary style map preserves all keys" do
      check all(
              style <- style_map_gen(),
              max_runs: 300
            ) do
        element = %{type: :divider, style: style, char: "-"}
        [output] = Engine.process_element(element, layout_space(), [])

        output_style = Map.get(output, :style, %{})

        for {key, value} <- style do
          assert Map.get(output_style, key) == value,
                 "divider style key #{inspect(key)} lost: expected #{inspect(value)}, got #{inspect(Map.get(output_style, key))}"
        end
      end
    end

    property "spacer with arbitrary style map preserves all keys" do
      check all(
              style <- style_map_gen(),
              size <- integer(1..5),
              direction <- member_of([:vertical, :horizontal]),
              max_runs: 300
            ) do
        element = %{type: :spacer, style: style, size: size, direction: direction}
        [output] = Engine.process_element(element, layout_space(), [])

        output_style = Map.get(output, :style, %{})

        for {key, value} <- style do
          assert Map.get(output_style, key) == value,
                 "spacer style key #{inspect(key)} lost: expected #{inspect(value)}, got #{inspect(Map.get(output_style, key))}"
        end
      end
    end
  end

  # -- Property 4: old-format text/label preserves :style --

  describe "old-format text/label style preservation" do
    property "old-format text with attrs preserves fg/bg/style" do
      check all(
              content <- printable_text_gen(),
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 300
            ) do
        element = %{
          type: :text,
          attrs: %{content: content, fg: fg, bg: bg, style: %{bold: true}}
        }

        [output] = Engine.process_element(element, layout_space(), [])

        assert Map.has_key?(output, :style),
               "old-format text output has no :style key"

        assert output.fg == fg, "old-format text fg lost"
        assert output.bg == bg, "old-format text bg lost"
      end
    end
  end

  # -- Property 5: text_input box wrapper preserves :style --

  describe "text_input box wrapper style preservation" do
    property "text_input box element has top-level :style" do
      check all(
              value <- printable_text_gen(),
              fg <- color_gen(),
              bg <- color_gen(),
              max_runs: 300
            ) do
        element = %{
          type: :text_input,
          attrs: %{value: value, fg: fg, bg: bg, style: %{bold: true}}
        }

        elements = Engine.process_element(element, layout_space(), [])
        box_el = Enum.find(elements, &(&1.type == :box))

        assert box_el != nil, "text_input produced no box element"

        assert Map.has_key?(box_el, :style),
               "text_input box wrapper has no :style key"
      end
    end
  end

  # -- Property 6: border offset handles all border value types --

  describe "border offset robustness" do
    property "box_inner_space handles atom, true, false, and :none borders" do
      check all(
              border <-
                member_of([:single, :double, :rounded, :ascii, :none, true, false]),
              padding <- integer(0..3),
              max_runs: 200
            ) do
        box = %{
          type: :box,
          children: [%{type: :text, content: "x", fg: nil, bg: nil, style: []}],
          style: %{},
          border: border,
          padding: padding
        }

        # Should not raise FunctionClauseError
        results = Engine.process_element(box, layout_space(), [])
        assert is_list(results), "process_element should return a list for any border value"
      end
    end
  end
end
