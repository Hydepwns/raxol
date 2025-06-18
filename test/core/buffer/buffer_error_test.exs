defmodule Raxol.Core.Buffer.BufferErrorTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @moduledoc '''
  Tests for buffer error handling and edge cases.
  These tests verify that the buffer operations handle errors
  and edge cases gracefully.
  '''

  describe "Invalid Input Handling" do
    test 'handles invalid buffer dimensions' do
      # Test negative dimensions
      assert_raise ArgumentError, fn ->
        Buffer.new({-1, 24})
      end

      assert_raise ArgumentError, fn ->
        Buffer.new({80, -1})
      end

      # Test zero dimensions
      assert_raise ArgumentError, fn ->
        Buffer.new({0, 24})
      end

      assert_raise ArgumentError, fn ->
        Buffer.new({80, 0})
      end

      # Test non-integer dimensions
      assert_raise ArgumentError, fn ->
        Buffer.new({80.5, 24})
      end

      assert_raise ArgumentError, fn ->
        Buffer.new({80, 24.5})
      end
    end

    test 'handles invalid cell data' do
      buffer = Buffer.new({80, 24})

      # Test invalid cell data types
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, "invalid")
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, 123)
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, nil)
      end

      # Test invalid cell content
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, %Cell{char: 123})
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, %Cell{char: nil})
      end
    end

    test 'handles invalid coordinates' do
      buffer = Buffer.new({80, 24})

      # Test non-integer coordinates
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0.5, 0, Cell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0.5, Cell.new())
      end

      # Test nil coordinates
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, nil, 0, Cell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, nil, Cell.new())
      end
    end
  end

  describe "Buffer State Error Handling" do
    test 'handles corrupted buffer state' do
      buffer = Buffer.new({80, 24})

      # Test corrupted cells
      corrupted_buffer = %{buffer | cells: nil}

      assert_raise RuntimeError, fn ->
        Buffer.get_cell(corrupted_buffer, 0, 0)
      end

      # Test corrupted dimensions
      corrupted_buffer = %{buffer | width: nil}

      assert_raise RuntimeError, fn ->
        Buffer.get_cell(corrupted_buffer, 0, 0)
      end

      corrupted_buffer = %{buffer | height: nil}

      assert_raise RuntimeError, fn ->
        Buffer.get_cell(corrupted_buffer, 0, 0)
      end
    end

    test 'handles invalid buffer operations' do
      buffer = Buffer.new({80, 24})

      # Test invalid write operations
      assert_raise ArgumentError, fn ->
        Buffer.write(buffer, nil)
      end

      assert_raise ArgumentError, fn ->
        Buffer.write(buffer, 123)
      end

      # Test invalid read operations
      assert_raise ArgumentError, fn ->
        Buffer.read(buffer, invalid: true)
      end

      # Test invalid scroll operations
      assert_raise ArgumentError, fn ->
        Buffer.scroll(buffer, nil)
      end

      assert_raise ArgumentError, fn ->
        Buffer.scroll(buffer, "invalid")
      end
    end
  end

  describe "Resource Error Handling" do
    test 'handles memory allocation errors' do
      # Test with extremely large buffer
      assert_raise RuntimeError, fn ->
        Buffer.new({1_000_000, 1_000_000})
      end
    end

    test 'handles buffer overflow' do
      buffer = Buffer.new({80, 24})

      # Test writing beyond buffer capacity
      assert_raise ArgumentError, fn ->
        # Try to write a string that's too long
        long_string = String.duplicate("X", 1000)
        Buffer.write(buffer, long_string)
      end
    end
  end

  describe "Recovery from Errors" do
    test 'recovers from temporary errors' do
      buffer = Buffer.new({80, 24})

      # Test recovery from invalid operation
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, -1, 0, Cell.new())
      end

      # Verify buffer is still usable
      assert Buffer.get_cell(buffer, 0, 0) == Cell.new()

      # Test recovery from invalid write
      assert_raise ArgumentError, fn ->
        Buffer.write(buffer, nil)
      end

      # Verify buffer is still usable
      assert Buffer.get_cell(buffer, 0, 0) == Cell.new()
    end

    test 'maintains buffer integrity after errors' do
      buffer = Buffer.new({80, 24})

      # Fill buffer with known content
      buffer =
        Enum.reduce(0..23, buffer, fn y, acc ->
          Enum.reduce(0..79, acc, fn x, acc ->
            cell = Cell.new("X", TextFormatting.new(fg: :red))
            Buffer.set_cell(acc, x, y, cell)
          end)
        end)

      # Attempt invalid operation
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, -1, 0, Cell.new())
      end

      # Verify buffer content is unchanged
      assert Buffer.get_cell(buffer, 0, 0).char == "X"
      assert Buffer.get_cell(buffer, 0, 0).fg == :red
    end
  end
end
