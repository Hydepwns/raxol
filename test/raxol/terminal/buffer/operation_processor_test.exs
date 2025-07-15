defmodule Raxol.Terminal.Buffer.OperationProcessorTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  setup do
    buffer = ScreenBuffer.new(5, 3)
    cell = Cell.new("A")
    %{buffer: buffer, cell: cell}
  end

  describe "valid_coordinates?/3" do
    test "returns true for valid coordinates", %{buffer: buffer} do
      assert OperationProcessor.valid_coordinates?(buffer, 0, 0)
      assert OperationProcessor.valid_coordinates?(buffer, 4, 2)
    end

    test "returns false for out-of-bounds coordinates", %{buffer: buffer} do
      refute OperationProcessor.valid_coordinates?(buffer, -1, 0)
      refute OperationProcessor.valid_coordinates?(buffer, 5, 0)
      refute OperationProcessor.valid_coordinates?(buffer, 0, 3)
    end
  end

  describe "process_operation/2" do
    test "set_cell with valid coordinates updates buffer", %{
      buffer: buffer,
      cell: cell
    } do
      buffer =
        OperationProcessor.process_operation({:set_cell, 1, 1, cell}, buffer)

      # Verify the cell was actually written
      assert buffer.cells |> Enum.at(1) |> Enum.at(1) |> Cell.get_char() == "A"
    end

    test "set_cell with invalid coordinates does not update buffer", %{
      buffer: buffer,
      cell: cell
    } do
      original_buffer = buffer

      buffer =
        OperationProcessor.process_operation({:set_cell, 10, 10, cell}, buffer)

      # Buffer should remain unchanged for invalid coordinates
      assert buffer == original_buffer
    end

    test "write_string with valid coordinates", %{buffer: buffer} do
      buffer =
        OperationProcessor.process_operation(
          {:write_string, 0, 0, "Hi"},
          buffer
        )

      # Verify the string was written
      assert buffer.cells |> Enum.at(0) |> Enum.at(0) |> Cell.get_char() == "H"
      assert buffer.cells |> Enum.at(0) |> Enum.at(1) |> Cell.get_char() == "i"
    end

    test "fill_region with valid region", %{buffer: buffer, cell: cell} do
      buffer =
        OperationProcessor.process_operation(
          {:fill_region, 0, 0, 2, 2, cell},
          buffer
        )

      # Verify the region was filled
      assert buffer.cells |> Enum.at(0) |> Enum.at(0) |> Cell.get_char() == "A"
      assert buffer.cells |> Enum.at(0) |> Enum.at(1) |> Cell.get_char() == "A"
      assert buffer.cells |> Enum.at(1) |> Enum.at(0) |> Cell.get_char() == "A"
      assert buffer.cells |> Enum.at(1) |> Enum.at(1) |> Cell.get_char() == "A"
    end

    test "resize operation", %{buffer: buffer} do
      buffer = OperationProcessor.process_operation({:resize, 10, 10}, buffer)
      assert buffer.width == 10
      assert buffer.height == 10
    end

    # Note: Scroll operations are temporarily disabled due to interface mismatch
    # between Scroller module and current ScreenBuffer structure
  end

  describe "process_batch/2" do
    test "processes a batch of operations", %{buffer: buffer, cell: cell} do
      ops = [
        {:set_cell, 0, 0, cell},
        {:write_string, 1, 1, "Hi"},
        {:resize, 6, 4}
      ]

      buffer = OperationProcessor.process_batch(ops, buffer)
      # Verify the operations were processed
      assert buffer.cells |> Enum.at(0) |> Enum.at(0) |> Cell.get_char() == "A"
      assert buffer.cells |> Enum.at(1) |> Enum.at(1) |> Cell.get_char() == "H"
      assert buffer.cells |> Enum.at(1) |> Enum.at(2) |> Cell.get_char() == "i"
      assert buffer.width == 6
      assert buffer.height == 4
    end
  end
end
