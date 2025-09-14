defmodule Raxol.UI.Components.Display.TableTest do
  use ExUnit.Case, async: true
  doctest Raxol.UI.Components.Display.Table

  alias Raxol.UI.Components.Display.Table

  import Raxol.Test.UnifiedTestHelper

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
      theme: test_theme(),
      available_space: %{width: width, height: height},
      attrs: %{style: %{}, type: :table}
    }
  end

  # --- Tests ---

  describe "Table Rendering" do
    @describetag :component
    setup do
      {:ok, state} = Table.init(%{})

      basic_attrs = %{
        id: :basic_table,
        columns: [%{header: "Col A", key: :a}, %{header: "Col B", key: :b}],
        data: [%{a: 1, b: 2}, %{a: 3, b: 4}],
        style: %{border: :single},
        type: :table
      }

      full_context = Map.merge(default_context(), %{attrs: basic_attrs})
      {:ok, state: state, context: full_context}
    end

    test "renders basic table structure", %{state: state, context: context} do
      rendered_element = Table.render(state, context)
      assert rendered_element.type == :table
      assert Keyword.get(rendered_element.attrs, :id) == :basic_table
      style_attr = Keyword.get(rendered_element.attrs, :style)

      assert %Raxol.Style{border: %Raxol.Style.Borders{style: :solid}} =
               style_attr

      assert Keyword.get(rendered_element.attrs, :columns) == [
               %{header: "Col A", key: :a},
               %{header: "Col B", key: :b}
             ]

      assert Keyword.get(rendered_element.attrs, :data) == [
               %{a: 1, b: 2},
               %{a: 3, b: 4}
             ]

      assert Keyword.get(rendered_element.attrs, :_scroll_top) == 0
    end

    test "renders without borders", %{context: context} do
      # Initialize a state specifically for testing no borders
      {:ok, state_no_border} = Table.init(%{border_style: :none})

      # The context from setup has context.attrs.style = %{border: :single}
      # This is fine, as state.border_style = :none in state_no_border should take precedence
      # via apply_border_style in the Table.render function.
      rendered_element = Table.render(state_no_border, context)
      assert rendered_element.type == :table
      style_attr = Keyword.get(rendered_element.attrs, :style)

      assert %Raxol.Style{border: %Raxol.Style.Borders{style: :none}} =
               style_attr
    end
  end

  describe "Table Event Handling - Standard Scrolling" do
    @describetag :component
    setup do
      {:ok, initial_component_state} = Table.init(%{id: :event_table_std})

      initial_component_state =
        Map.put_new(initial_component_state, :filter_term, "")

      event_context =
        default_context()
        |> Map.put(
          :attrs,
          %{
            id: :event_table_std,
            columns: [%{header: "Col A", key: :a}],
            # 10 items
            data: Enum.map(1..10, &%{a: &1}),
            # Visible height for 4 data rows + header
            style: %{height: 5},
            type: :table
          }
        )

      {:ok, state: initial_component_state, context: event_context}
    end

    test "handle_event :arrow_down scrolls down one row", %{
      state: state,
      context: context
    } do
      {:noreply, new_state} =
        Table.handle_event(state, {:keypress, :arrow_down}, context)

      assert new_state.scroll_top == 1
    end

    test "handle_event :arrow_down stops at the end", %{
      state: state,
      context: context
    } do
      # Max scroll_top = 10 data - 4 visible_data = 6
      state_at_bottom = %{state | scroll_top: 6}

      {:noreply, new_state} =
        Table.handle_event(state_at_bottom, {:keypress, :arrow_down}, context)

      assert new_state.scroll_top == 6
    end

    test "handle_event :arrow_up scrolls up one row", %{
      state: state,
      context: context
    } do
      state_scrolled_down = %{state | scroll_top: 3}

      {:noreply, new_state} =
        Table.handle_event(state_scrolled_down, {:keypress, :arrow_up}, context)

      assert new_state.scroll_top == 2
    end

    test "handle_event :arrow_up stops at the top", %{
      state: state,
      context: context
    } do
      {:noreply, new_state} =
        Table.handle_event(state, {:keypress, :arrow_up}, context)

      assert new_state.scroll_top == 0
    end

    test "handle_event :page_down scrolls down one page", %{
      state: state,
      context: context
    } do
      {:noreply, new_state} =
        Table.handle_event(state, {:keypress, :page_down}, context)

      # Visible data rows = 4
      assert new_state.scroll_top == 4
    end

    test "handle_event :page_down stops at the end", %{
      state: state,
      context: context
    } do
      # scroll_top 3 + page_size 4 = 7, clamped to 6
      state_near_bottom = %{state | scroll_top: 3}

      {:noreply, new_state} =
        Table.handle_event(state_near_bottom, {:keypress, :page_down}, context)

      assert new_state.scroll_top == 6
    end

    test "handle_event :page_up scrolls up one page", %{
      state: state,
      context: context
    } do
      state_scrolled_down = %{state | scroll_top: 5}

      {:noreply, new_state} =
        Table.handle_event(state_scrolled_down, {:keypress, :page_up}, context)

      # 5 - 4 = 1
      assert new_state.scroll_top == 1
    end

    test "handle_event :page_up stops at the top", %{
      state: state,
      context: context
    } do
      # scroll_top 2 - page_size 4 = -2, clamped to 0
      state_near_top = %{state | scroll_top: 2}

      {:noreply, new_state} =
        Table.handle_event(state_near_top, {:keypress, :page_up}, context)

      assert new_state.scroll_top == 0
    end
  end

  describe "Table Event Handling - Empty or Minimal Data" do
    @describetag :component
    setup do
      {:ok, initial_component_state} = Table.init(%{id: :event_table_minimal})

      initial_component_state =
        Map.put_new(initial_component_state, :filter_term, "")

      # Context with style for 4 visible data rows, but data will be varied per test
      base_context =
        default_context()
        |> Map.put(
          :attrs,
          %{
            id: :event_table_minimal,
            columns: [%{header: "Col A", key: :a}],
            # Visible height for 4 data rows + header
            style: %{height: 5},
            type: :table
          }
        )

      {:ok, state: initial_component_state, base_context: base_context}
    end

    test "all scroll events keep scroll_top at 0 with empty data", %{
      state: state,
      base_context: base_context
    } do
      context =
        Map.put(base_context, :attrs, Map.put(base_context.attrs, :data, []))

      for event_key <- [:arrow_down, :arrow_up, :page_down, :page_up] do
        {:noreply, new_state} =
          Table.handle_event(state, {:keypress, event_key}, context)

        assert new_state.scroll_top == 0,
               "Scroll top failed for #{event_key} with empty data"
      end
    end

    test "all scroll events keep scroll_top at 0 with data less than page size",
         %{state: state, base_context: base_context} do
      # 2 items, visible data height is 4. All items visible.
      context =
        Map.put(
          base_context,
          :attrs,
          Map.put(base_context.attrs, :data, [%{a: 1}, %{a: 2}])
        )

      for event_key <- [:arrow_down, :arrow_up, :page_down, :page_up] do
        {:noreply, new_state} =
          Table.handle_event(state, {:keypress, event_key}, context)

        assert new_state.scroll_top == 0,
               "Scroll top failed for #{event_key} with less data"
      end
    end
  end

  describe "Table Event Handling - Visible Height of 1 (for data)" do
    @describetag :component
    setup do
      {:ok, initial_component_state} = Table.init(%{id: :event_table_h1})

      initial_component_state =
        Map.put_new(initial_component_state, :filter_term, "")

      # Data with 3 items. Style height 2 means 1 data row visible (height - 1 for header).
      context_h1 =
        default_context()
        |> Map.put(
          :attrs,
          %{
            id: :event_table_h1,
            columns: [%{header: "Col A", key: :a}],
            # 3 items
            data: Enum.map(1..3, &%{a: &1}),
            # Visible height for 1 data row + header
            style: %{height: 2},
            type: :table
          }
        )

      {:ok, state: initial_component_state, context: context_h1}
    end

    test "page_down scrolls one by one and stops at end", %{
      state: state,
      context: context
    } do
      # Max scroll is 3 items - 1 visible_data_row = 2
      # scroll_top: 0 -> 1
      {:noreply, state_s1} =
        Table.handle_event(state, {:keypress, :page_down}, context)

      assert state_s1.scroll_top == 1

      # scroll_top: 1 -> 2 (end)
      {:noreply, state_s2} =
        Table.handle_event(state_s1, {:keypress, :page_down}, context)

      assert state_s2.scroll_top == 2

      # scroll_top: 2 -> 2 (still at end)
      {:noreply, state_s3} =
        Table.handle_event(state_s2, {:keypress, :page_down}, context)

      assert state_s3.scroll_top == 2
    end

    test "page_up scrolls one by one and stops at top", %{
      state: state,
      context: context
    } do
      # Max scroll is 2
      state_at_end = %{state | scroll_top: 2}

      # scroll_top: 2 -> 1
      {:noreply, state_s1} =
        Table.handle_event(state_at_end, {:keypress, :page_up}, context)

      assert state_s1.scroll_top == 1

      # scroll_top: 1 -> 0 (top)
      {:noreply, state_s0} =
        Table.handle_event(state_s1, {:keypress, :page_up}, context)

      assert state_s0.scroll_top == 0

      # scroll_top: 0 -> 0 (still at top)
      {:noreply, state_still_top} =
        Table.handle_event(state_s0, {:keypress, :page_up}, context)

      assert state_still_top.scroll_top == 0
    end

    # Arrow key tests for visible height 1
    test "arrow_down scrolls one by one and stops at end (height 1)", %{
      state: state,
      context: context
    } do
      # Max scroll is 3 items - 1 visible_data_row = 2
      # scroll_top: 0 -> 1
      {:noreply, state_s1} =
        Table.handle_event(state, {:keypress, :arrow_down}, context)

      assert state_s1.scroll_top == 1

      # scroll_top: 1 -> 2 (end)
      {:noreply, state_s2} =
        Table.handle_event(state_s1, {:keypress, :arrow_down}, context)

      assert state_s2.scroll_top == 2

      # scroll_top: 2 -> 2 (still at end)
      {:noreply, state_s3} =
        Table.handle_event(state_s2, {:keypress, :arrow_down}, context)

      assert state_s3.scroll_top == 2
    end

    test "arrow_up scrolls one by one and stops at top (height 1)", %{
      state: state,
      context: context
    } do
      # Max scroll is 2
      state_at_end = %{state | scroll_top: 2}

      # scroll_top: 2 -> 1
      {:noreply, state_s1} =
        Table.handle_event(state_at_end, {:keypress, :arrow_up}, context)

      assert state_s1.scroll_top == 1

      # scroll_top: 1 -> 0 (top)
      {:noreply, state_s0} =
        Table.handle_event(state_s1, {:keypress, :arrow_up}, context)

      assert state_s0.scroll_top == 0

      # scroll_top: 0 -> 0 (still at top)
      {:noreply, state_still_top} =
        Table.handle_event(state_s0, {:keypress, :arrow_up}, context)

      assert state_still_top.scroll_top == 0
    end
  end

  describe "Table Lifecycle" do
    @describetag :component
    setup do
      {:ok, initial_component_state} = Table.init(%{id: :lifecycle_table})

      initial_component_state =
        Map.put_new(initial_component_state, :filter_term, "")

      {:ok, state: initial_component_state}
    end

    test "mount/1 returns state and commands (currently empty)", %{state: state} do
      {:ok, mounted_state, commands} = Table.mount(state)
      assert mounted_state == state
      assert commands == []
    end

    test "unmount/1 returns state (currently no-op)", %{state: state} do
      {:ok, unmounted_state} = Table.unmount(state)
      assert unmounted_state == state
    end
  end
end
