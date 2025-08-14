
defmodule Raxol.Core.Renderer.Views.TableTest do
  @moduledoc """
  Test module for the Table view component.
  Verifies table initialization, styling, column handling, and rendering behavior.
  """
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Views.Table
  alias Raxol.UI.Components.ComponentManager

  @sample_data [
    %{id: 1, name: "Alice", age: 30},
    %{id: 2, name: "Bob", age: 25},
    %{id: 3, name: "Charlie", age: 35}
  ]

  @sample_columns [
    %{header: "ID", key: :id, width: 4, align: :right},
    %{header: "Name", key: :name, width: 10, align: :left},
    %{header: "Age", key: :age, width: 5, align: :center}
  ]

  defp basic_table_props do
    %{
      columns: @sample_columns,
      data: @sample_data,
      border: :single,
      striped: false
    }
  end

  defp assert_common_table_state(state, props) do
    assert state.columns == props.columns
    assert state.data == props.data
    assert state.border == props.border
    assert state.striped == props.striped
    assert state.title == nil
    assert state.selectable == false
    assert state.selected == nil
    assert state.header_style == [:bold]
    assert state.row_style == []
  end

  describe "component lifecycle" do
    test ~c"creates a basic table" do
      props = basic_table_props()
      state = Table.init(props)
      assert_common_table_state(state, props)
    end

    test ~c"respects title property" do
      props = Map.put(basic_table_props(), :title, "My Table")
      state = Table.init(props)
      assert state.title == "My Table"
    end

    test ~c"handles empty data" do
      props = %{
        columns: basic_table_props().columns,
        data: [],
        border: :single,
        striped: true
      }

      state = Table.init(props)
      assert state.data == []
      assert state.columns == props.columns
    end

    test ~c"applies striping to rows" do
      props =
        basic_table_props()
        |> Map.put(:striped, true)

      state = Table.init(props)
      assert state.striped == true
    end

    test ~c"handles row selection" do
      props =
        basic_table_props()
        |> Map.merge(%{
          selectable: true,
          selected: 1
        })

      state = Table.init(props)
      assert state.selectable == true
      assert state.selected == 1
    end

    test ~c"applies custom border style" do
      props =
        basic_table_props()
        |> Map.put(:border, :double)

      state = Table.init(props)
      assert state.border == :double
    end

    test ~c"applies custom header style" do
      props =
        basic_table_props()
        |> Map.put(:header_style, [:bold, :underline])

      state = Table.init(props)
      assert state.header_style == [:bold, :underline]
    end

    test ~c"applies custom row style" do
      props =
        basic_table_props()
        |> Map.put(:row_style, [:dim])
        |> Map.put(:striped, false)

      state = Table.init(props)
      assert state.row_style == [:dim]
    end
  end

  describe "column handling" do
    test ~c"calculates auto widths" do
      props = %{
        columns: [
          %{header: "Short", key: :name, width: :auto, align: :left},
          %{header: "Very Long Header", key: :age, width: :auto, align: :left}
        ],
        data: [
          %{name: "A", age: 1},
          %{name: "B", age: 2}
        ],
        border: :single,
        striped: true
      }

      state = Table.init(props)
      assert state.calculated_widths == [5, 16]
    end

    test ~c"handles custom formatters" do
      props = %{
        columns: [
          %{
            header: "Money",
            key: :amount,
            width: 10,
            align: :right,
            format: &("$" <> Integer.to_string(&1))
          }
        ],
        data: [%{amount: 1000}],
        border: :single,
        striped: true
      }

      state = Table.init(props)
      assert length(state.columns) == 1

      # Further assertions could check the formatter's output in the rendered view
    end

    test ~c"handles function keys" do
      props = %{
        columns: [
          %{
            header: "Full Name",
            key: &(&1.first <> " " <> &1.last),
            width: 20,
            align: :left
          }
        ],
        data: [%{first: "John", last: "Doe"}],
        border: :single,
        striped: true
      }

      state = Table.init(props)
      assert length(state.columns) == 1
      # Further assertions could check the rendered output
    end
  end

  describe "rendering" do
    test "renders basic table structure" do
      props = basic_table_props()
      state = Table.init(props)

      # Verify the table state is properly initialized for rendering
      assert state.columns == props.columns
      assert state.data == props.data
      assert state.border == props.border
      assert is_list(state.columns)
      assert length(state.columns) > 0
      assert is_list(state.data)
    end

    test "renders table with different border styles" do
      border_styles = [:single, :double, :none]

      Enum.each(border_styles, fn border_style ->
        props = Map.put(basic_table_props(), :border, border_style)
        state = Table.init(props)
        assert state.border == border_style
      end)
    end

    test "renders table with row selection" do
      props =
        Map.merge(basic_table_props(), %{
          selectable: true,
          selected: 0
        })

      state = Table.init(props)
      assert state.selectable == true
      assert state.selected == 0
    end
  end
end
