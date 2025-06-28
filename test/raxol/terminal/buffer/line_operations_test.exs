defmodule Raxol.Terminal.Buffer.LineOperationsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.LineOperations

  setup do
    buffer = ScreenBuffer.new(10, 5)
    %{buffer: buffer}
  end

  describe "insert_lines/3" do
    test "inserts lines at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.insert_lines(buffer, 2, 2)
      assert get_content(buffer) == "ABCDE\nFGHIJ\n     \n     \nKLMNO\nPQRST"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.insert_lines(original, 5, 2)
      assert buffer == original

      buffer = LineOperations.insert_lines(original, 2, -1)
      assert buffer == original
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.insert_lines(original, 2, 0)
      assert buffer == original
    end
  end

  describe "delete_lines/3" do
    test "deletes lines at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.delete_lines(buffer, 1, 2)
      assert get_content(buffer) == "ABCDE\nPQRST\nUVWXY\n     \n     "
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.delete_lines(original, 5, 2)
      assert buffer == original

      buffer = LineOperations.delete_lines(original, 1, -1)
      assert buffer == original
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.delete_lines(original, 1, 0)
      assert buffer == original
    end
  end

  describe "prepend_lines/2" do
    test "prepends lines", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.prepend_lines(buffer, 2)
      assert get_content(buffer) == "     \n     \nABCDE\nFGHIJ\nKLMNO"
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.prepend_lines(original, 0)
      assert buffer == original
    end
  end

  describe "pop_top_lines/2" do
    test "removes lines from top", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.pop_top_lines(buffer, 2)
      assert get_content(buffer) == "KLMNO\nPQRST\nUVWXY\n     \n     "
    end

    test "ignores invalid count", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = LineOperations.pop_top_lines(original, 0)
      assert buffer == original
    end
  end

  describe "get_line/2" do
    test "gets line at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      line = LineOperations.get_line(buffer, 2)

      assert line |> Enum.map(&Raxol.Terminal.Cell.get_char/1) |> Enum.join() ==
               "KLMNO"
    end

    test "returns empty list for invalid position", %{buffer: buffer} do
      assert LineOperations.get_line(buffer, 5) == []
      assert LineOperations.get_line(buffer, -1) == []
    end
  end

  describe "set_line/3" do
    test "sets line at valid position", %{buffer: buffer} do
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      new_line = List.duplicate(Raxol.Terminal.Cell.new("X"), 10)
      buffer = LineOperations.set_line(buffer, 2, new_line)
      assert get_content(buffer) == "ABCDE\nFGHIJ\nXXXXXXXXXX\nPQRST\nUVWXY"
    end

    test "ignores invalid position", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      new_line = List.duplicate(Raxol.Terminal.Cell.new("X"), 10)
      buffer = LineOperations.set_line(original, 5, new_line)
      assert buffer == original

      buffer = LineOperations.set_line(original, -1, new_line)
      assert buffer == original
    end
  end

  # Helper functions

  defp put_content(buffer, text) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buffer ->
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {char, x}, buffer ->
        Raxol.Terminal.Buffer.Content.write_char(buffer, x, y, char)
      end)
    end)
  end

  defp get_content(buffer) do
    buffer.cells
    |> Enum.map(fn line ->
      line
      |> Enum.map(&Raxol.Terminal.Cell.get_char/1)
      |> Enum.join()
      |> String.trim_trailing()
    end)
    |> Enum.join("\n")
  end
end
