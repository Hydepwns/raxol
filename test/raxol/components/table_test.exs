defmodule Raxol.Components.TableTest do
  use ExUnit.Case, async: true
  alias Raxol.Components.Table

  @test_columns [
    %{id: :id, label: "ID"},
    %{id: :name, label: "Name"},
    %{id: :age, label: "Age"}
  ]

  @test_data [
    %{id: 1, name: "Alice", age: 25},
    %{id: 2, name: "Bob", age: 30},
    %{id: 3, name: "Charlie", age: 35},
    %{id: 4, name: "Dave", age: 40},
    %{id: 5, name: "Eve", age: 28}
  ]

  describe "initialization" do
    test "initializes with default options" do
      state = Table.init(%{
        id: :test_table,
        columns: @test_columns,
        data: @test_data
      })

      assert state.id == :test_table
      assert state.columns == @test_columns
      assert state.data == @test_data
      assert state.options == %{paginate: false, searchable: false, sortable: false}
      assert state.current_page == 1
      assert state.page_size == 10
      assert state.filter_term == ""
    end

    test "initializes with custom options" do
      state = Table.init(%{
        id: :test_table,
        columns: @test_columns,
        data: @test_data,
        options: %{paginate: true, searchable: true, sortable: true, page_size: 2}
      })

      assert state.options == %{paginate: true, searchable: true, sortable: true, page_size: 2}
      assert state.page_size == 2
    end
  end

  describe "data processing" do
    setup do
      state = Table.init(%{
        id: :test_table,
        columns: @test_columns,
        data: @test_data,
        options: %{paginate: true, searchable: true, sortable: true, page_size: 2}
      })
      {:ok, state: state}
    end

    test "filtering works correctly", %{state: state} do
      # Set up filter term
      {updated_state, _} = Table.update({:filter, "alice"}, state)

      # Render to process data
      rendered = Table.render(updated_state, %{})

      # Verify we're displaying a filtered set
      assert String.contains?(inspect(rendered), "Alice")
      refute String.contains?(inspect(rendered), "Bob")
    end

    test "sorting works correctly", %{state: state} do
      # Sort by age descending
      {updated_state, _} = Table.update({:sort, :age}, state)

      # Render to process data
      rendered = Table.render(updated_state, %{})

      # Check for sort indicator
      assert String.contains?(inspect(rendered), "Age ▲")

      # Sort again to change direction
      {updated_state, _} = Table.update({:sort, :age}, updated_state)
      rendered = Table.render(updated_state, %{})

      # Check for reversed sort indicator
      assert String.contains?(inspect(rendered), "Age ▼")
    end

    test "pagination works correctly", %{state: state} do
      # With page size 2, should have 3 pages
      {page1_state, _} = Table.update({:set_page, 1}, state)
      rendered = Table.render(page1_state, %{})

      # Page 1 should show items 1-2
      assert String.contains?(inspect(rendered), "Page 1 of 3")
      assert String.contains?(inspect(rendered), "Alice")
      assert String.contains?(inspect(rendered), "Bob")
      refute String.contains?(inspect(rendered), "Charlie")

      # Go to page 2
      {page2_state, _} = Table.update({:set_page, 2}, state)
      rendered = Table.render(page2_state, %{})

      # Page 2 should show items 3-4
      assert String.contains?(inspect(rendered), "Page 2 of 3")
      assert String.contains?(inspect(rendered), "Charlie")
      assert String.contains?(inspect(rendered), "Dave")
      refute String.contains?(inspect(rendered), "Alice")
    end
  end

  describe "event handling" do
    setup do
      state = Table.init(%{
        id: :test_table,
        columns: @test_columns,
        data: @test_data,
        options: %{paginate: true, searchable: true, sortable: true, page_size: 2}
      })
      {:ok, state: state}
    end

    test "handles arrow key navigation for pagination", %{state: state} do
      # Starting at page 1
      assert state.current_page == 1

      # Arrow right should go to page 2
      {state_after_right, _} = Table.handle_event({:key, {:arrow_right, []}}, %{}, state)
      assert state_after_right.current_page == 2

      # Arrow left should go back to page 1
      {state_after_left, _} = Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_right)
      assert state_after_left.current_page == 1

      # Arrow left at page 1 should stay at page 1
      {state_after_left_again, _} = Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_left)
      assert state_after_left_again.current_page == 1
    end

    test "handles button clicks for pagination", %{state: state} do
      # Click next page button
      {state_after_next, _} = Table.handle_event({:button_click, "test_table_next_page"}, %{}, state)
      assert state_after_next.current_page == 2

      # Click prev page button
      {state_after_prev, _} = Table.handle_event({:button_click, "test_table_prev_page"}, %{}, state_after_next)
      assert state_after_prev.current_page == 1
    end

    test "handles sort button clicks", %{state: state} do
      # Click to sort by age
      {state_after_sort, _} = Table.handle_event({:button_click, "test_table_sort_age"}, %{}, state)
      assert state_after_sort.sort_by == :age
      assert state_after_sort.sort_direction == :asc

      # Click again to reverse sort
      {state_after_reverse, _} = Table.handle_event({:button_click, "test_table_sort_age"}, %{}, state_after_sort)
      assert state_after_reverse.sort_by == :age
      assert state_after_reverse.sort_direction == :desc
    end

    test "handles search input", %{state: state} do
      # Set search text
      {state_after_search, _} = Table.handle_event({:text_input, "test_table_search", "Alice"}, %{}, state)
      assert state_after_search.filter_term == "Alice"
      # Should reset to page 1
      assert state_after_search.current_page == 1
    end
  end
end
