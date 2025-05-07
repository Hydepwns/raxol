defmodule Raxol.UI.Components.Display.TableTest do
  use ExUnit.Case, async: true
  doctest Raxol.UI.Components.Display.Table

  alias Raxol.UI.Components.Display.Table
  # Assuming Theme structure for context
  alias Raxol.UI.Theming.Theme

  # Helper to extract text content from rendered elements at a specific line
  # defp get_line_text(elements, y) do
  #   elements
  #   |> Enum.filter(&(&1.y == y && &1.type == :text))
  #   |> Enum.sort_by(&(&1.x || 0))
  #   |> Enum.map_join(& &1.text)
  # end

  # Helper to find a specific cell element
  # defp find_cell(elements, y, text_content) do
  #   Enum.find(elements, fn el ->
  #     el.y == y && el.type == :text && el.text == text_content
  #   end)
  # end

  # Basic rendering context
  defp default_context(width \\ 80, height \\ 24) do
    %{
      theme: Raxol.Style.Colors.Theme.standard_theme(),
      available_space: %{width: width, height: height},
      # Add other necessary context fields if needed
      attrs: %{} # Placeholder for component attributes
    }
  end

  # --- Tests ---

  describe "Table Rendering" do
    @describetag :component
    setup do
      # Basic state/context for rendering
      state = %{scroll_top: 0} # Minimal internal state
      # Pass data/columns via context attrs
      basic_attrs = %{
        id: :basic_table,
        columns: [%{header: "Col A", key: :a}, %{header: "Col B", key: :b}],
        data: [%{a: 1, b: 2}, %{a: 3, b: 4}],
        style: %{border: :single} # Example style
      }
      # Use default_context helper defined in the test file
      full_context = Map.merge(default_context(), %{attrs: basic_attrs})
      {:ok, state: state, context: full_context}
    end

    # Updated test to check the returned structure
    test "renders basic table structure", %{state: state, context: context} do
      rendered_element = Table.render(state, context)

      assert rendered_element.type == :table
      assert rendered_element.id == :basic_table
      assert rendered_element.style == %{border: :single} # Check style passed through
      assert rendered_element.columns == [%{header: "Col A", key: :a}, %{header: "Col B", key: :b}]
      assert rendered_element.data == [%{a: 1, b: 2}, %{a: 3, b: 4}]
      # Check internal state passed via underscored attr (as per render function)
      assert rendered_element._scroll_top == 0
    end

    # Updated test to check the style attribute in the returned element instead of rendered characters
    test "renders without borders", %{state: state, context: context} do
      # Update context attrs for no border
      no_border_attrs = Map.put(context.attrs, :style, %{border: :none})
      no_border_context = Map.put(context, :attrs, no_border_attrs)

      rendered_element = Table.render(state, no_border_context)

      # Assert the returned element has border: :none style
      assert rendered_element.type == :table
      assert rendered_element.style == %{border: :none}

      # Cannot assert on rendered characters here, that's Renderer's job
      # Flawed assertion:
      # assert Enum.empty?(Enum.filter(elements, &(&1.text =~ ~r/[┌┐└┘─│┼┬┴]/)))
    end
  end

  # TODO: Add tests for handle_event (scrolling)
  # These would check the internal state (:scroll_top) changes
end
