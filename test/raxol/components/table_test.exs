defmodule Raxol.UI.Components.TableTest do
  use ExUnit.Case
  import Raxol.Guards
  alias Raxol.UI.Components.Table

  @test_columns [
    %{
      id: :id,
      label: "ID",
      width: 4,
      align: :right,
      format: &String.Chars.to_string/1
    },
    %{
      id: :name,
      label: "Name",
      width: 10,
      align: :left,
      format: &String.Chars.to_string/1
    },
    %{
      id: :age,
      label: "Age",
      width: 5,
      align: :center,
      format: &String.Chars.to_string/1
    }
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

    case Raxol.Core.UserPreferences.start_link(test_mode?: true) do
      {:ok, _pid} ->
        :ok

      # Ignore if already started
      {:error, {:already_started, _pid}} ->
        :ok

      other_error ->
        flunk("UserPreferences failed to start: #{inspect(other_error)}")
    end

    case Raxol.Core.Renderer.Manager.start_link([]) do
      {:ok, _pid} ->
        :ok

      # Ignore if already started
      {:error, {:already_started, _pid}} ->
        :ok

      other_error ->
        flunk("Renderer.Manager failed to start: #{inspect(other_error)}")
    end

    # Return the test context
    {:ok,
     %{
       columns: @test_columns,
       data: @test_data
     }}
  end

  describe "initialization" do
    test "initializes with default options", %{columns: columns, data: data} do
      result =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

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
      result =
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

      assert match?({:ok, _}, result)
      {:ok, state} = result

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
      result =
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

      assert match?({:ok, _}, result)
      {:ok, state} = result

      {:ok, %{state: state}}
    end

    test "filtering works correctly", %{state: state} do
      result = Table.update({:filter, "alice"}, state)
      assert match?({:ok, _}, result)
      {:ok, updated_state} = result
      rendered = Table.render(updated_state, %{})

      assert map?(rendered)
      assert Map.has_key?(rendered, :type)
      assert rendered.type == :box
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | rows] = flex.children
      assert length(rows) == 1
      first_row = List.first(rows)
      assert map?(first_row)
      assert Map.has_key?(first_row, :type)
      assert first_row.type == :flex
      assert length(first_row.children) == 3
      assert Enum.at(first_row.children, 1).content == "Alice      "
    end

    test "sorting works correctly", %{columns: columns, data: data} do
      # Create a separate state for sorting test with pagination disabled
      result =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data,
          options: %{
            # Disable pagination for sorting test
            paginate: false,
            searchable: true,
            sortable: true,
            page_size: 10
          }
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

      result = Table.update({:sort, :age}, state)
      assert match?({:ok, _}, result)
      {:ok, updated_state} = result
      rendered = Table.render(updated_state, %{available_width: 80})

      # Verify sort order through row content
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | rows] = flex.children
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 2).content == " 25 "
      last_row = List.last(rows)
      assert Enum.at(last_row.children, 2).content == " 40 "
    end

    test "pagination works correctly", %{state: state} do
      result = Table.update({:set_page, 1}, state)
      assert match?({:ok, _}, result)
      {:ok, page1_state} = result
      rendered = Table.render(page1_state, %{available_width: 80})

      # Verify first page content
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | rows] = flex.children
      assert length(rows) == 2
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 1).content == "Alice      "
      second_row = Enum.at(rows, 1)
      assert Enum.at(second_row.children, 1).content == "Bob        "

      # Verify second page content
      result = Table.update({:set_page, 2}, state)
      assert match?({:ok, _}, result)
      {:ok, page2_state} = result
      rendered = Table.render(page2_state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | rows] = flex.children
      assert length(rows) == 2
      first_row = List.first(rows)
      assert Enum.at(first_row.children, 1).content == "Charlie    "
    end
  end

  describe "event handling" do
    setup %{columns: columns, data: data} do
      result =
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

      assert match?({:ok, _}, result)
      {:ok, state} = result

      {:ok, %{state: state}}
    end

    test "handles arrow key navigation for pagination", %{state: state} do
      assert state.current_page == 1

      result = Table.handle_event({:key, {:arrow_right, []}}, %{}, state)
      assert match?({:ok, _}, result)
      {:ok, state_after_right} = result

      assert state_after_right.current_page == 2

      result =
        Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_right)

      assert match?({:ok, _}, result)
      {:ok, state_after_left} = result

      assert state_after_left.current_page == 1

      result =
        Table.handle_event({:key, {:arrow_left, []}}, %{}, state_after_left)

      assert match?({:ok, _}, result)
      {:ok, state_after_left_again} = result

      assert state_after_left_again.current_page == 1
    end

    test "handles button clicks for pagination", %{state: state} do
      result =
        Table.handle_event({:button_click, "test_table_next_page"}, %{}, state)

      assert match?({:ok, _}, result)
      {:ok, state_after_next} = result

      assert state_after_next.current_page == 2

      result =
        Table.handle_event(
          {:button_click, "test_table_prev_page"},
          %{},
          state_after_next
        )

      assert match?({:ok, _}, result)
      {:ok, state_after_prev} = result

      assert state_after_prev.current_page == 1
    end

    test "handles sort button clicks", %{state: state} do
      result =
        Table.handle_event({:button_click, "test_table_sort_age"}, %{}, state)

      assert match?({:ok, _}, result)
      {:ok, state_after_sort} = result

      assert state_after_sort.sort_by == :age
      assert state_after_sort.sort_direction == :asc

      result =
        Table.handle_event(
          {:button_click, "test_table_sort_age"},
          %{},
          state_after_sort
        )

      assert match?({:ok, _}, result)
      {:ok, state_after_reverse} = result

      assert state_after_reverse.sort_by == :age
      assert state_after_reverse.sort_direction == :desc
    end

    test "handles search input", %{state: state} do
      result =
        Table.handle_event(
          {:text_input, "test_table_search", "Alice"},
          %{},
          state
        )

      assert match?({:ok, _}, result)
      {:ok, state_after_search} = result

      assert state_after_search.filter_term == "Alice"
      assert state_after_search.current_page == 1
    end
  end

  describe "theming and style" do
    setup %{columns: columns, data: data} do
      result =
        Table.init(%{
          id: :test_table,
          columns: columns,
          data: data,
          options: %{
            paginate: false,
            searchable: false,
            sortable: true,
            page_size: 10
          }
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

      {:ok, %{state: state}}
    end

    test "header is rendered with bold style", %{state: state} do
      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | _] = flex.children
      assert header.type == :flex

      Enum.each(header.children, fn cell ->
        assert :bold in (cell.style || [])
      end)
    end

    test "selected row is rendered with correct background and foreground colors",
         %{state: state} do
      state = %{state | selected_row: 1}
      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [_header | rows] = flex.children
      selected_row = Enum.at(rows, 1)
      assert selected_row.type == :flex

      Enum.each(selected_row.children, fn cell ->
        style = cell.style || []
        assert {:bg, :blue} in style
        assert {:fg, :white} in style
      end)
    end

    test "box style is overridden by style prop", %{
      columns: columns,
      data: data
    } do
      result =
        Table.init(%{
          id: :styled,
          columns: columns,
          data: data,
          style: %{border_color: :red}
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

      rendered = Table.render(state, %{available_width: 80})
      assert Map.get(rendered.style, :border_color) == :red
    end

    test "box style is overridden by theme", %{columns: columns, data: data} do
      theme = %{box: %{border_color: :green}}

      result =
        Table.init(%{id: :themed, columns: columns, data: data, theme: theme})

      assert match?({:ok, _}, result)
      {:ok, state} = result

      rendered = Table.render(state, %{available_width: 80})
      assert Map.get(rendered.style, :border_color) == :green
    end

    test "header style is overridden by theme and style prop", %{
      columns: columns,
      data: data
    } do
      theme = %{header: %{underline: true}}
      style = %{header: %{italic: true}}

      result =
        Table.init(%{
          id: :headerstyled,
          columns: columns,
          data: data,
          theme: theme,
          style: style
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | _] = flex.children

      Enum.each(header.children, fn cell ->
        # Should include :underline and :italic in style keys
        style_keys = cell.style || []
        assert :underline in style_keys
        assert :italic in style_keys
      end)
    end

    test "row and selected row style are overridden by theme", %{
      columns: columns,
      data: data
    } do
      theme = %{row: %{bg: :yellow}, selected_row: %{bg: :red, fg: :black}}

      result =
        Table.init(%{
          id: :rowstyled,
          columns: columns,
          data: data,
          theme: theme,
          style: %{}
        })

      assert match?({:ok, _}, result)
      {:ok, state} = result

      # Unselected row
      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [_header | rows] = flex.children
      first_row = Enum.at(rows, 0)

      Enum.each(first_row.children, fn cell ->
        style = cell.style || []
        assert :yellow in style
      end)

      # Selected row
      state = %{state | selected_row: 2}
      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [_header | rows] = flex.children
      selected_row = Enum.at(rows, 2)

      Enum.each(selected_row.children, fn cell ->
        style = cell.style || []
        assert :red in style
        assert :black in style
      end)
    end

    test "column style and header_style are respected", %{
      columns: columns,
      data: data
    } do
      custom_columns = [
        %{
          id: :id,
          label: "ID",
          width: 4,
          align: :right,
          style: %{color: :magenta},
          header_style: %{bg: :cyan}
        },
        %{id: :name, label: "Name", width: 10, align: :left},
        %{id: :age, label: "Age", width: 5, align: :center}
      ]

      result =
        Table.init(%{id: :colstyled, columns: custom_columns, data: data})

      assert match?({:ok, _}, result)
      {:ok, state} = result

      rendered = Table.render(state, %{available_width: 80})
      flex = get_in(rendered, [:children, Access.at(0)])
      [header | rows] = flex.children
      # Header cell for :id should have :bg in style
      id_header_cell = Enum.at(header.children, 0)
      assert :bg in (id_header_cell.style || [])
      # First row, first cell should have :magenta in style
      first_row = Enum.at(rows, 0)
      id_cell = Enum.at(first_row.children, 0)
      assert :magenta in (id_cell.style || [])
    end
  end
end
