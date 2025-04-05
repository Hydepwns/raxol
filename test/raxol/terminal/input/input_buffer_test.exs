defmodule Raxol.Terminal.Input.InputBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.InputBuffer

  describe "new/0" do
    test "creates a new input buffer with default values" do
      buffer = InputBuffer.new()
      assert InputBuffer.get_contents(buffer) == ""
      assert InputBuffer.get_max_size(buffer) == 1024
      assert InputBuffer.get_overflow_mode(buffer) == :truncate
    end
  end

  describe "new/2" do
    test "creates a new input buffer with custom values" do
      buffer = InputBuffer.new(100, :error)
      assert InputBuffer.get_contents(buffer) == ""
      assert InputBuffer.get_max_size(buffer) == 100
      assert InputBuffer.get_overflow_mode(buffer) == :error
    end
  end

  describe "append/2" do
    test "appends data to the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test "accumulates appended data" do
      buffer = InputBuffer.new()
      buffer = buffer
        |> InputBuffer.append("Hello")
        |> InputBuffer.append(" ")
        |> InputBuffer.append("World")
      
      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test "truncates when buffer is full in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test "raises error when buffer is full in error mode" do
      buffer = InputBuffer.new(5, :error)
      buffer = InputBuffer.append(buffer, "Hello")
      
      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.append(buffer, " World")
      end
    end

    test "wraps around when buffer is full in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end
  end

  describe "prepend/2" do
    test "prepends data to the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.prepend(buffer, "Hello")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test "accumulates prepended data" do
      buffer = InputBuffer.new()
      buffer = buffer
        |> InputBuffer.prepend("World")
        |> InputBuffer.prepend(" ")
        |> InputBuffer.prepend("Hello")
      
      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test "truncates when buffer is full in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.prepend(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end

    test "raises error when buffer is full in error mode" do
      buffer = InputBuffer.new(5, :error)
      buffer = InputBuffer.prepend(buffer, "Hello")
      
      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.prepend(buffer, " World")
      end
    end

    test "wraps around when buffer is full in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.prepend(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end
  end

  describe "set_contents/2" do
    test "sets buffer contents" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test "truncates when content exceeds max size in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test "raises error when content exceeds max size in error mode" do
      buffer = InputBuffer.new(5, :error)
      
      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.set_contents(buffer, "Hello World")
      end
    end

    test "wraps around when content exceeds max size in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end
  end

  describe "clear/1" do
    test "clears the buffer contents" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello World"
      
      buffer = InputBuffer.clear(buffer)
      assert InputBuffer.get_contents(buffer) == ""
    end
  end

  describe "empty?/1" do
    test "returns true for empty buffer" do
      buffer = InputBuffer.new()
      assert InputBuffer.empty?(buffer)
    end

    test "returns false for non-empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      refute InputBuffer.empty?(buffer)
    end
  end

  describe "size/1" do
    test "returns the current size of the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      assert InputBuffer.size(buffer) == 5
    end
  end

  describe "set_max_size/2" do
    test "sets the maximum buffer size" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_max_size(buffer, 100)
      assert InputBuffer.get_max_size(buffer) == 100
    end

    test "truncates content when reducing max size in truncate mode" do
      buffer = InputBuffer.new(10, :truncate)
      buffer = InputBuffer.append(buffer, "Hello World")
      buffer = InputBuffer.set_max_size(buffer, 5)
      assert InputBuffer.get_contents(buffer) == "Hello"
    end
  end

  describe "set_overflow_mode/2" do
    test "sets the overflow mode" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_overflow_mode(buffer, :error)
      assert InputBuffer.get_overflow_mode(buffer) == :error
    end
  end

  describe "backspace/1" do
    test "removes the last character" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.backspace(buffer)
      assert InputBuffer.get_contents(buffer) == "Hell"
    end

    test "does nothing on empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.backspace(buffer)
      assert InputBuffer.empty?(buffer)
    end
  end

  describe "delete_first/1" do
    test "removes the first character" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.delete_first(buffer)
      assert InputBuffer.get_contents(buffer) == "ello"
    end

    test "does nothing on empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.delete_first(buffer)
      assert InputBuffer.empty?(buffer)
    end
  end

  describe "insert_at/3" do
    test "inserts a character at the specified position" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hllo")
      buffer = InputBuffer.insert_at(buffer, 1, "e")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test "appends when position is at the end" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.insert_at(buffer, 5, "!")
      assert InputBuffer.get_contents(buffer) == "Hello!"
    end

    test "raises error when position is out of bounds" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      
      assert_raise ArgumentError, "Position out of bounds", fn ->
        InputBuffer.insert_at(buffer, 10, "!")
      end
    end
  end

  describe "replace_at/3" do
    test "replaces a character at the specified position" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.replace_at(buffer, 1, "E")
      assert InputBuffer.get_contents(buffer) == "HEllo"
    end

    test "raises error when position is out of bounds" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      
      assert_raise ArgumentError, "Position out of bounds", fn ->
        InputBuffer.replace_at(buffer, 10, "!")
      end
    end
  end
end 