defmodule Raxol.Core.Renderer.Views.TableTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.View
  alias Raxol.Core.Renderer.Views.Table

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

  describe "new/1" do
    test "creates a basic table" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data
        )

      assert view.type == :border
      assert view.border == :single
      [header | rows] = get_in(view, [:children, Access.at(0)])

      # Check header
      assert header.type == :flex
      assert length(header.children) == 3
      # right-aligned
      assert Enum.at(header.children, 0).content == "   1"
      # left-aligned
      assert Enum.at(header.children, 1).content == "ID       "
      # center-aligned
      assert Enum.at(header.children, 2).content == " Age "
    end

    test "handles empty data" do
      view =
        Table.new(
          columns: @sample_columns,
          data: []
        )

      assert view.type == :border
      [header | rows] = get_in(view, [:children, Access.at(0)])
      assert length(rows) == 0
    end

    test "applies striping to rows" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data,
          striped: true
        )

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      # Even rows should have no background
      assert Enum.at(rows, 0).style == []
      # Odd rows should have bright_black background
      assert Enum.at(rows, 1).style == [bg: :bright_black]
    end

    test "handles row selection" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data,
          selectable: true,
          selected: 1
        )

      [_header | rows] = get_in(view, [:children, Access.at(0)])

      # Selected row should have blue background and white text
      assert Enum.at(rows, 1).style == [bg: :blue, fg: :white]
    end

    test "applies custom border style" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data,
          border: :double
        )

      assert view.border == :double
    end

    test "applies custom header style" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data,
          header_style: [:bold, :underline]
        )

      [header | _] = get_in(view, [:children, Access.at(0)])
      assert Enum.all?(header.children, &([:bold, :underline] == &1.style))
    end

    test "applies custom row style" do
      view =
        Table.new(
          columns: @sample_columns,
          data: @sample_data,
          row_style: [:dim]
        )

      [_header | rows] = get_in(view, [:children, Access.at(0)])
      assert Enum.all?(rows, &([:dim] == &1.style))
    end
  end

  describe "column handling" do
    test "calculates auto widths" do
      columns = [
        %{header: "Short", key: :name, width: :auto, align: :left},
        %{header: "Very Long Header", key: :age, width: :auto, align: :left}
      ]

      data = [%{name: "A", age: 1}, %{name: "B", age: 2}]

      view = Table.new(columns: columns, data: data)
      [header | _] = get_in(view, [:children, Access.at(0)])

      # First column should be width of "Short"
      assert String.length(Enum.at(header.children, 0).content) == 5
      # Second column should be width of "Very Long Header"
      assert String.length(Enum.at(header.children, 1).content) == 15
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

      view = Table.new(columns: columns, data: data)
      [_header | rows] = get_in(view, [:children, Access.at(0)])
      row = Enum.at(rows, 0)

      assert Enum.at(row.children, 0).content == "    $1000"
    end

    test "handles function keys" do
      columns = [
        %{
          header: "Full Name",
          key: fn row -> "#{row.first} #{row.last}" end,
          width: 20,
          align: :left
        }
      ]

      data = [%{first: "John", last: "Doe"}]

      view = Table.new(columns: columns, data: data)
      [_header | rows] = get_in(view, [:children, Access.at(0)])
      row = Enum.at(rows, 0)

      assert Enum.at(row.children, 0).content == "John Doe            "
    end
  end

  describe "text alignment" do
    test "aligns text left" do
      text = Table.pad_text("test", 8, :left)
      assert text == "test    "
    end

    test "aligns text right" do
      text = Table.pad_text("test", 8, :right)
      assert text == "    test"
    end

    test "aligns text center" do
      text = Table.pad_text("test", 8, :center)
      assert text == "  test  "
    end

    test "truncates long text" do
      text = Table.pad_text("very long text", 8, :left)
      assert String.length(text) == 8
      assert text == "very lon"
    end
  end
end
