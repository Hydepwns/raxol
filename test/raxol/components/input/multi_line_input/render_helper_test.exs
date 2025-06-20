defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.RenderHelper

  defp normalize_dimensions(%{width: _, height: _} = dims), do: dims

  defp normalize_dimensions({w, h}) when is_integer(w) and is_integer(h),
    do: %{width: w, height: h}

  defp normalize_dimensions(_), do: %{width: 10, height: 5}

  defp create_state(
         lines,
         dimensions \\ {10, 1},
         scroll_offset \\ {0, 0},
         selection_range \\ nil
       ) do
    dims = normalize_dimensions(dimensions)

    %MultiLineInput{
      value: Enum.join(lines, "\n"),
      width: dims.width,
      height: dims.height,
      cursor_pos: {0, 0},
      scroll_offset: scroll_offset,
      selection_start:
        if(selection_range, do: elem(selection_range, 0), else: nil),
      selection_end:
        if(selection_range, do: elem(selection_range, 1), else: nil),
      lines: lines,
      id: "test_mle"
    }
  end

  defp mock_theme do
    %Raxol.UI.Theming.Theme{
      component_styles: %{
        multi_line_input: %{
          text_color: :cyan,
          selection_color: :magenta,
          line_number_color: :yellow
        }
      },
      colors: %{foreground: :white, background: :black}
    }
  end

  defp extract_style(attrs) do
    cond do
      is_list(attrs) -> Keyword.get(attrs, :style)
      is_map(attrs) -> Map.get(attrs, :style)
      true -> nil
    end
  end

  defp assert_rendered_segments(result, expected) do
    Enum.zip(result, expected)
    |> Enum.each(fn {seg, {content, style}} ->
      assert seg.content == content
      assert extract_style(seg.attrs) == style
    end)
  end

  describe "Render Helper Functions" do
    test ~c"render_line/4 applies default style" do
      state = create_state(["hi"])
      line_index = 0
      line_content = "hi"

      theme = %{
        components: %{
          multi_line_input: %{
            text_style: %{color: :white}
          }
        }
      }

      rendered =
        RenderHelper.render_line(line_index, line_content, state, theme)

      assert Enum.at(rendered, 0).content == "hi"
      assert extract_style(Enum.at(rendered, 0).attrs) == %{color: :white}
    end
  end

  describe "render_line/4 edge cases" do
    setup do
      theme = %{
        components: %{
          multi_line_input: %{
            selection_style: %{background: :blue},
            cursor_style: %{background: :red},
            text_style: %{color: :white}
          }
        }
      }

      %{theme: theme}
    end

    test "cursor at start of line", %{theme: theme} do
      state = create_state(["abc"]) |> Map.put(:focused, true)
      line = "abc"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.at(result, 0).content == "a"
      assert extract_style(Enum.at(result, 0).attrs) == %{background: :red}
      assert Enum.at(result, 1).content == "bc"
    end

    test "cursor at end of line", %{theme: theme} do
      state = create_state(["abc"]) |> Map.put(:focused, true)
      line = "abc"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) == 1
      assert Enum.at(result, 0).content == "abc"
    end

    test "selection within single line", %{theme: theme} do
      state = create_state(["abcdef"], {{0, 1}, {0, 3}})
      line = "abcdef"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) == 1
      assert Enum.at(result, 0).content == "abcdef"
    end

    test "selection across multiple lines, only highlights this line's part", %{
      theme: theme
    } do
      state = create_state(["abcdef"], {{0, 2}, {2, 1}})
      line = "abcdef"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) == 1
      assert Enum.at(result, 0).content == "abcdef"
    end

    test "empty line with cursor", %{theme: theme} do
      state = create_state([""]) |> Map.put(:focused, true)
      line = ""

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) == 0 or Enum.at(result, 0).content == ""
    end

    test "out-of-bounds cursor/selection does not crash", %{theme: theme} do
      state =
        create_state(["abc"], {0, 10}, {0, 0}, {{0, 20}, {0, 25}})
        |> Map.put(:focused, true)

      line = "abc"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) >= 1
      assert Enum.at(result, 0).content == "abc"
    end

    test "selection within single line, inspect second label", %{theme: theme} do
      state = create_state(["abcdef"], {{0, 1}, {0, 3}})
      line = "abcdef"

      result =
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          0,
          line,
          state,
          theme
        )

      assert Enum.count(result) == 1
      assert Enum.at(result, 0).content == "abcdef"
    end
  end
end
