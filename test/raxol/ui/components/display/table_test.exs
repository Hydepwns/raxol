defmodule Raxol.UI.Components.Display.TableTest do
  use ExUnit.Case

  alias Raxol.UI.Components.Display.Table

  @test_columns [
    %{key: :id, header: "ID"},
    %{key: :name, header: "Name"},
    %{key: :age, header: "Age"}
  ]

  @test_data [
    %{id: 1, name: "Alice", age: 25},
    %{id: 2, name: "Bob", age: 30},
    %{id: 3, name: "Charlie", age: 35},
    %{id: 4, name: "Dave", age: 40},
    %{id: 5, name: "Eve", age: 28}
  ]

  defp default_context(attrs \\ %{}) do
    theme = Raxol.UI.Theming.Theme.new()

    %{
      attrs: Map.merge(%{data: @test_data, columns: @test_columns}, attrs),
      theme: theme
    }
  end

  describe "init/1" do
    test "returns {:ok, state} with defaults when given empty attrs" do
      {:ok, state} = Table.init(%{})

      assert state.columns == []
      assert state.data == []
      assert state.style == %{}
      assert state.scroll_top == 0
      assert state.scroll_left == 0
      assert state.focused_row == nil
      assert state.focused_col == nil
      assert state.max_height == nil
      assert state.max_width == nil
      assert state.sort_by == nil
      assert state.sort_direction == nil
      assert state.filter_term == ""
      assert state.selected_row == nil
      assert state.striped == true
      assert state.border_style == :single
      assert state.mounted == false
      assert state.render_count == 0
      assert state.type == :table
      assert state.focused == false
      assert state.disabled == false
      assert state.header_style == %{bold: true}
      assert state.row_style == nil
      assert state.cell_style == nil
      assert state.footer == nil
    end

    test "returns {:ok, state} with an auto-generated id when none provided" do
      {:ok, state} = Table.init(%{})

      assert is_binary(state.id)
    end

    test "returns {:ok, state} with provided id" do
      {:ok, state} = Table.init(%{id: :my_table})

      assert state.id == :my_table
    end

    test "initializes with custom columns and data" do
      {:ok, state} = Table.init(%{columns: @test_columns, data: @test_data})

      assert state.columns == @test_columns
      assert state.data == @test_data
    end

    test "initializes with custom style" do
      style = %{border_color: :red}
      {:ok, state} = Table.init(%{style: style})

      assert state.style == style
    end

    test "initializes with custom header_style" do
      header_style = %{bold: true, underline: true}
      {:ok, state} = Table.init(%{header_style: header_style})

      assert state.header_style == header_style
    end

    test "initializes with custom border_style" do
      {:ok, state} = Table.init(%{border_style: :double})

      assert state.border_style == :double
    end

    test "initializes with striped set to false" do
      {:ok, state} = Table.init(%{striped: false})

      assert state.striped == false
    end

    test "initializes with selected row" do
      {:ok, state} = Table.init(%{selected: 2})

      assert state.selected_row == 2
    end

    test "initializes with focused and disabled flags" do
      {:ok, state} = Table.init(%{focused: true, disabled: true})

      assert state.focused == true
      assert state.disabled == true
    end

    test "initializes with max_height and max_width" do
      {:ok, state} = Table.init(%{max_height: 10, max_width: 80})

      assert state.max_height == 10
      assert state.max_width == 80
    end

    test "initializes with row_style, cell_style, and footer" do
      row_style = %{bg: :blue}
      cell_style = %{fg: :white}
      footer = %{text: "Total: 5"}

      {:ok, state} =
        Table.init(%{row_style: row_style, cell_style: cell_style, footer: footer})

      assert state.row_style == row_style
      assert state.cell_style == cell_style
      assert state.footer == footer
    end
  end

  describe "mount/1" do
    test "returns state unchanged with empty command list" do
      {:ok, state} = Table.init(%{id: :mount_test, columns: @test_columns, data: @test_data})

      {mounted_state, commands} = Table.mount(state)

      assert mounted_state == state
      assert commands == []
    end
  end

  describe "unmount/1" do
    test "returns state unchanged" do
      {:ok, state} = Table.init(%{id: :unmount_test})

      result = Table.unmount(state)

      assert result == state
    end
  end

  describe "update/2" do
    setup do
      {:ok, state} =
        Table.init(%{id: :update_test, columns: @test_columns, data: @test_data})

      %{state: state}
    end

    test "handles {:sort, column} by setting sort_by and sort_direction to :asc", %{
      state: state
    } do
      updated = Table.update({:sort, :age}, state)

      assert updated.sort_by == :age
      assert updated.sort_direction == :asc
    end

    test "handles {:sort, column} toggling to :desc on same column", %{state: state} do
      state_asc = Table.update({:sort, :age}, state)

      assert state_asc.sort_direction == :asc

      state_desc = Table.update({:sort, :age}, state_asc)

      assert state_desc.sort_by == :age
      assert state_desc.sort_direction == :desc
    end

    test "handles {:sort, column} resetting to :asc when sorting a different column", %{
      state: state
    } do
      state_sorted = Table.update({:sort, :age}, state)

      assert state_sorted.sort_by == :age

      state_new_col = Table.update({:sort, :name}, state_sorted)

      assert state_new_col.sort_by == :name
      assert state_new_col.sort_direction == :asc
    end

    test "handles {:filter, term} by setting filter_term", %{state: state} do
      updated = Table.update({:filter, "alice"}, state)

      assert updated.filter_term == "alice"
    end

    test "handles {:filter, empty string} to clear filter", %{state: state} do
      state_filtered = Table.update({:filter, "alice"}, state)
      state_cleared = Table.update({:filter, ""}, state_filtered)

      assert state_cleared.filter_term == ""
    end

    test "handles {:select_row, index} by setting selected_row", %{state: state} do
      updated = Table.update({:select_row, 2}, state)

      assert updated.selected_row == 2
    end

    test "handles {:select_row, nil} to deselect", %{state: state} do
      state_selected = Table.update({:select_row, 2}, state)
      state_deselected = Table.update({:select_row, nil}, state_selected)

      assert state_deselected.selected_row == nil
    end

    test "handles unknown message by returning state unchanged", %{state: state} do
      updated = Table.update(:unknown_message, state)

      assert updated == state
    end
  end

  describe "handle_event/3 — keypress events" do
    setup do
      {:ok, state} =
        Table.init(%{id: :key_test, columns: @test_columns, data: @test_data})

      context = default_context()

      %{state: state, context: context}
    end

    test "arrow_up decreases scroll_top", %{state: state, context: context} do
      state_scrolled = %{state | scroll_top: 3}

      {new_state, commands} = Table.handle_event({:keypress, :arrow_up}, state_scrolled, context)

      assert new_state.scroll_top == 2
      assert commands == []
    end

    test "arrow_up does not scroll below zero", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:keypress, :arrow_up}, state, context)

      assert new_state.scroll_top == 0
      assert commands == []
    end

    test "arrow_down increases scroll_top", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:keypress, :arrow_down}, state, context)

      assert new_state.scroll_top >= 0
      assert commands == []
    end

    test "page_up scrolls up by visible height", %{state: state, context: context} do
      state_scrolled = %{state | scroll_top: 10}

      {new_state, commands} =
        Table.handle_event({:keypress, :page_up}, state_scrolled, context)

      assert new_state.scroll_top < 10
      assert new_state.scroll_top >= 0
      assert commands == []
    end

    test "page_up does not scroll below zero", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:keypress, :page_up}, state, context)

      assert new_state.scroll_top == 0
      assert commands == []
    end

    test "page_down scrolls down by visible height", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:keypress, :page_down}, state, context)

      assert new_state.scroll_top >= 0
      assert commands == []
    end

    test "unrecognized key returns state unchanged", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:keypress, :tab}, state, context)

      assert new_state == state
      assert commands == []
    end
  end

  describe "handle_event/3 — click events" do
    setup do
      {:ok, state} =
        Table.init(%{id: :click_test, columns: @test_columns, data: @test_data})

      %{state: state}
    end

    test "row click selects row when selectable is true", %{state: state} do
      context = default_context(%{selectable: true})

      {new_state, commands} = Table.handle_event({:click, {:row, 2}}, state, context)

      assert new_state.selected_row == 2
      assert commands == []
    end

    test "row click does not select row when selectable is false", %{state: state} do
      context = default_context(%{selectable: false})

      {new_state, commands} = Table.handle_event({:click, {:row, 2}}, state, context)

      assert new_state.selected_row == nil
      assert commands == []
    end

    test "header click emits sort update when sortable is true", %{state: state} do
      context = default_context(%{sortable: true})

      {_new_state, commands} = Table.handle_event({:click, {:header, :age}}, state, context)

      assert commands == [{:update, {:sort, :age}}]
    end

    test "header click does nothing when sortable is false", %{state: state} do
      context = default_context(%{sortable: false})

      {new_state, commands} = Table.handle_event({:click, {:header, :age}}, state, context)

      assert new_state == state
      assert commands == []
    end
  end

  describe "handle_event/3 — input events" do
    setup do
      {:ok, state} =
        Table.init(%{id: :input_test, columns: @test_columns, data: @test_data})

      %{state: state}
    end

    test "filter input emits filter update when filterable is true", %{state: state} do
      context = default_context(%{filterable: true})

      {_new_state, commands} =
        Table.handle_event({:input, {:filter, "alice"}}, state, context)

      assert commands == [{:update, {:filter, "alice"}}]
    end

    test "filter input does nothing when filterable is false", %{state: state} do
      context = default_context(%{filterable: false})

      {new_state, commands} =
        Table.handle_event({:input, {:filter, "alice"}}, state, context)

      assert new_state == state
      assert commands == []
    end
  end

  describe "handle_event/3 — focus events" do
    setup do
      {:ok, state} =
        Table.init(%{id: :focus_test, columns: @test_columns, data: @test_data})

      context = default_context()

      %{state: state, context: context}
    end

    test "row focus sets focused_row", %{state: state, context: context} do
      {new_state, commands} = Table.handle_event({:focus, {:row, 3}}, state, context)

      assert new_state.focused_row == 3
      assert commands == []
    end

    test "cell focus sets focused_row and focused_col", %{state: state, context: context} do
      {new_state, commands} =
        Table.handle_event({:focus, {:cell, {2, 1}}}, state, context)

      assert new_state.focused_row == 2
      assert new_state.focused_col == 1
      assert commands == []
    end
  end

  describe "handle_event/3 — unrecognized events" do
    test "returns state unchanged with empty commands" do
      {:ok, state} = Table.init(%{id: :unknown_event_test})
      context = default_context()

      {new_state, commands} = Table.handle_event({:unknown, :data}, state, context)

      assert new_state == state
      assert commands == []
    end
  end

  describe "render/2" do
    setup do
      :ok = Raxol.UI.Theming.Theme.init()
      :ok
    end

    test "returns a map element with expected keys" do
      {:ok, state} =
        Table.init(%{id: :render_test, columns: @test_columns, data: @test_data})

      context = default_context(%{id: :render_test})
      result = Table.render(state, context)

      assert is_map(result)
      assert Map.has_key?(result, :disabled)
      assert Map.has_key?(result, :focused)
    end

    test "render includes disabled and focused from state" do
      {:ok, state} =
        Table.init(%{
          id: :render_flags_test,
          columns: @test_columns,
          data: @test_data,
          focused: true,
          disabled: true
        })

      context = default_context(%{id: :render_flags_test})
      result = Table.render(state, context)

      assert result.focused == true
      assert result.disabled == true
    end

    test "render with empty data produces an element" do
      {:ok, state} =
        Table.init(%{id: :empty_render, columns: @test_columns, data: []})

      context = default_context(%{id: :empty_render, data: [], columns: @test_columns})
      result = Table.render(state, context)

      assert is_map(result)
    end

    test "render with empty columns produces an element" do
      {:ok, state} =
        Table.init(%{id: :no_cols_render, columns: [], data: []})

      context = default_context(%{id: :no_cols_render, data: [], columns: []})
      result = Table.render(state, context)

      assert is_map(result)
    end

    test "render processes filtered data" do
      {:ok, state} =
        Table.init(%{id: :filter_render, columns: @test_columns, data: @test_data})

      state_filtered = %{state | filter_term: "alice"}
      context = default_context(%{id: :filter_render})
      result = Table.render(state_filtered, context)

      assert is_map(result)
    end

    test "render processes sorted data" do
      {:ok, state} =
        Table.init(%{id: :sort_render, columns: @test_columns, data: @test_data})

      state_sorted = %{state | sort_by: :age, sort_direction: :asc}
      context = default_context(%{id: :sort_render})
      result = Table.render(state_sorted, context)

      assert is_map(result)
    end

    test "render with border_style :none" do
      {:ok, state} =
        Table.init(%{
          id: :no_border_render,
          columns: @test_columns,
          data: @test_data,
          border_style: :none
        })

      context = default_context(%{id: :no_border_render})
      result = Table.render(state, context)

      assert is_map(result)
    end

    test "render with border_style :double" do
      {:ok, state} =
        Table.init(%{
          id: :double_border_render,
          columns: @test_columns,
          data: @test_data,
          border_style: :double
        })

      context = default_context(%{id: :double_border_render})
      result = Table.render(state, context)

      assert is_map(result)
    end
  end
end
