defmodule Raxol.Core.Renderer.Views.TableTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.View
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

  describe "component lifecycle" do
    test "creates a basic table" do
      # Add format dynamically
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      assert view.type == :border
      assert view.border == :single
      [header_row | _data_rows] = get_in(view, [:children, Access.at(0)])

      # Check header cells
      assert header_row.type == :flex
      assert length(header_row.children) == 3
      # right-aligned header
      assert Enum.at(header_row.children, 0).content == "  ID"
      # left-aligned header
      assert Enum.at(header_row.children, 1).content == "Name      "
      # center-aligned header
      assert Enum.at(header_row.children, 2).content == " Age "
    end

    test "handles empty data" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: []
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      assert view.type == :border
      [header | rows] = get_in(view, [:children, Access.at(0)])
      assert length(rows) == 0
    end

    test "applies striping to rows" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data,
        striped: true
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      # Even rows should have no background
      assert Enum.at(rows, 0).style == []
      # Odd rows should have bright_black background
      assert Enum.at(rows, 1).style == [bg: :bright_black]
    end

    test "handles row selection" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data,
        selectable: true,
        selected: 1,
        striped: false
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      # Selected row should have blue background and white text
      assert Enum.at(rows, 1).style == [bg: :blue, fg: :white]
    end

    test "applies custom border style" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data,
        border: :double
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      assert view.border == :double
    end

    test "applies custom header style" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data,
        header_style: [:bold, :underline]
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [header | _] = get_in(view, [:children, Access.at(0)])
      assert Enum.all?(header.children, &([:bold, :underline] == &1.style))
    end

    test "applies custom row style" do
      columns_with_format =
        Enum.map(
          @sample_columns,
          &Map.put(&1, :format, fn val -> to_string(val) end)
        )

      props = %{
        columns: columns_with_format,
        data: @sample_data,
        row_style: [:dim],
        striped: false
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [_header | rows] = get_in(view, [:children, Access.at(0)])
      assert Enum.all?(rows, &([:dim] == &1.style))
    end
  end

  describe "column handling" do
    test "calculates auto widths" do
      columns = [
        %{
          header: "Short",
          key: :name,
          width: :auto,
          align: :left,
          format: fn v -> to_string(v) end
        },
        %{
          header: "Very Long Header",
          key: :age,
          width: :auto,
          align: :left,
          format: fn v -> to_string(v) end
        }
      ]

      data = [%{name: "A", age: 1}, %{name: "B", age: 2}]

      props = %{
        columns: columns,
        data: data
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [header | _] = get_in(view, [:children, Access.at(0)])

      # First column should be width of "Short"
      assert String.length(Enum.at(header.children, 0).content) == 5

      # Second column should be width of "Very Long Header"
      assert String.length(Enum.at(header.children, 1).content) == 16
    end

    test "handles custom formatters" do
      columns = [
        %{
          header: "Money",
          key: :amount,
          width: 10,
          align: :right,
          format: &"$#{&1}"
        }
      ]

      data = [%{amount: 1000}]

      props = %{
        columns: columns,
        data: data
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      assert Enum.at(rows, 0).children |> Enum.at(0) |> Map.get(:content) ==
               "    $1000"
    end

    test "handles function keys" do
      columns = [
        %{
          header: "Full Name",
          key: fn row -> "#{row.first} #{row.last}" end,
          width: 20,
          align: :left,
          format: & &1
        }
      ]

      data = [%{first: "John", last: "Doe"}]

      props = %{
        columns: columns,
        data: data
      }

      {:ok, state} = Table.init(props)
      view = Table.render(state)

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      assert Enum.at(rows, 0).children |> Enum.at(0) |> Map.get(:content) ==
               "John Doe             "
    end
  end
end
