defmodule Raxol.Components.TableTest do
  use ExUnit.Case, async: true
  alias Raxol.Components.Table

  @test_columns [
    %{id: :id, label: "ID", width: 4, align: :right, format: &String.Chars.to_string/1},
    %{id: :name, label: "Name", width: 10, align: :left, format: &String.Chars.to_string/1},
    %{id: :age, label: "Age", width: 5, align: :center, format: &String.Chars.to_string/1}
  ]

  @test_data [
    %{id: 1, name: "Alice", age: 25},
    %{id: 2, name: "Bob", age: 30},
    %{id: 3, name: "Charlie", age: 35},
    %{id: 4, name: "Dave", age: 40},
    %{id: 5, name: "Eve", age: 28}
  ]

  setup do
    # Initialize any required dependencies
    :ok = Raxol.UI.Theming.Theme.init()
    :ok = Raxol.Core.UserPreferences.start_link(test_mode?: true)
    {:ok, _} = Raxol.Core.Renderer.Manager.start_link([])

    # Return the test context
    {:ok, %{
      columns: @test_columns,
      data: @test_data
    }}
  end

  describe "initialization" do
    test "initializes with default options", %{columns: columns, data: data} do
      {:ok, state} =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data
        })

      assert state.id == :test_table
      assert state.columns == columns
      assert state.data == data
      assert state.options == %{
               paginate: false,
               searchable: false,
               sortable: false,
               page_size: 10
             }
      assert state.current_page == 1
      assert state.page_size == 10
      assert state.filter_term == ""
    end

    test "initializes with custom options", %{columns: columns, data: data} do
      {:ok, state} =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data,
          options: %{
            paginate: true,
            searchable: true,
            sortable: true,
            page_size: 2
          }
        })

      assert state.options == %{
               paginate: true,
               searchable: true,
               sortable: true,
               page_size: 2
             }
      assert state.page_size == 2
    end
  end

  describe "data processing" do
    setup %{columns: columns, data: data} do
      {:ok, state} =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data,
          options: %{
            paginate: true,
            searchable: true,
            sortable: true,
            page_size: 2
          }
        })

      {:ok, %{state: state}}
    end

    test "filtering works correctly", %{state: state} do
      {:ok, updated_state} = Table.update({:filter, "alice"}, state)
      rendered = Table.render(updated_state, %{})

      # Check rendered content structure instead of string inspection
      assert rendered.type == :border
      [header | rows] = get_in(rendered, [:children, Access.at(0)])
      assert length(rows) == 1
      first_row = List.first(rows)
      assert first_row.type == :flex
      assert length(first_row.children) == 3
      assert Enum.at(first_row.children, 1).content == "Alice      "
    end

    test "sorting works correctly", %{state: state} do
      {:ok, updated_state} = Table.update({:sort, :age}, state)
      rendered = Table.render(updated_state, %{})

      # Verify sort order through row content
      [header | rows] = get_in(rendered, [:children, Access.at(0)])
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 2).content == " 25 "
      last_row = List.last(rows)
      assert Enum.at(last_row.children, 2).content == " 40 "
    end

    test "pagination works correctly", %{state: state} do
      {:ok, page1_state} = Table.update({:set_page, 1}, state)
      rendered = Table.render(page1_state, %{})

      # Verify first page content
      [header | rows] = get_in(rendered, [:children, Access.at(0)])
      assert length(rows) == 2
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 1).content == "Alice      "
      second_row = Enum.at(rows, 1)
      assert Enum.at(second_row.children, 1).content == "Bob        "

      # Verify second page content
      {:ok, page2_state} = Table.update({:set_page, 2}, state)
      rendered = Table.render(page2_state, %{})
      [header | rows] = get_in(rendered, [:children, Access.at(0)])
      assert length(rows) == 2
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 1).content == "Charlie    "
    end
  end

  describe "event handling" do
    setup %{columns: columns, data: data} do
      {:ok, state} =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data,
          options: %{
            paginate: true,
            searchable: true,
            sortable: true,
            page_size: 2
          }
        })

      {:ok, %{state: state}}
    end

    test "handles arrow key navigation for pagination", %{state: state} do
      assert state.current_page == 1

      {:ok, state_after_right} =
        Table.handle_event({:key, {:arrow_right, []}}, %{}, state)
      assert state_after_right.current_page == 2

      {:ok, state_after_left} =
        Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_right)
      assert state_after_left.current_page == 1

      {:ok, state_after_left_again} =
        Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_left)
      assert state_after_left_again.current_page == 1
    end

    test "handles button clicks for pagination", %{state: state} do
      {:ok, state_after_next} =
        Table.handle_event({:button_click, "test_table_next_page"}, %{}, state)
      assert state_after_next.current_page == 2

      {:ok, state_after_prev} =
        Table.handle_event(
          {:button_click, "test_table_prev_page"},
          %{},
          state_after_next
        )
      assert state_after_prev.current_page == 1
    end

    test "handles sort button clicks", %{state: state} do
      {:ok, state_after_sort} =
        Table.handle_event({:button_click, "test_table_sort_age"}, %{}, state)
      assert state_after_sort.sort_by == :age
      assert state_after_sort.sort_direction == :asc

      {:ok, state_after_reverse} =
        Table.handle_event(
          {:button_click, "test_table_sort_age"},
          %{},
          state_after_sort
        )
      assert state_after_reverse.sort_by == :age
      assert state_after_reverse.sort_direction == :desc
    end

    test "handles search input", %{state: state} do
      {:ok, state_after_search} =
        Table.handle_event(
          {:text_input, "test_table_search", "Alice"},
          %{},
          state
        )
      assert state_after_search.filter_term == "Alice"
      assert state_after_search.current_page == 1
    end
  end
end
