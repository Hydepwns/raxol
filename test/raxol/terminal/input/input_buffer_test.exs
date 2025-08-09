defmodule Raxol.Terminal.Input.InputBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.InputBuffer

  describe "new/0" do
    test ~c"creates a new input buffer with default values" do
      buffer = InputBuffer.new()
      assert InputBuffer.get_contents(buffer) == ""
      assert InputBuffer.max_size(buffer) == 1024
      assert InputBuffer.overflow_mode(buffer) == :truncate
    end
  end

  describe "new/2" do
    test ~c"creates a new input buffer with custom values" do
      buffer = InputBuffer.new(100, :error)
      assert InputBuffer.get_contents(buffer) == ""
      assert InputBuffer.max_size(buffer) == 100
      assert InputBuffer.overflow_mode(buffer) == :error
    end
  end

  describe "append/2" do
    test ~c"appends data to the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test ~c"accumulates appended data" do
      buffer = InputBuffer.new()

      buffer =
        buffer
        |> InputBuffer.append("Hello")
        |> InputBuffer.append(" ")
        |> InputBuffer.append("World")

      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test ~c"truncates when buffer is full in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test ~c"raises error when buffer is full in error mode" do
      buffer = InputBuffer.new(5, :error)
      buffer = InputBuffer.append(buffer, "Hello")

      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.append(buffer, " World")
      end
    end

    test ~c"wraps around when buffer is full in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end
  end

  describe "prepend/2" do
    test ~c"prepends data to the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.prepend(buffer, "Hello")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test ~c"accumulates prepended data" do
      buffer = InputBuffer.new()

      buffer =
        buffer
        |> InputBuffer.prepend("World")
        |> InputBuffer.prepend(" ")
        |> InputBuffer.prepend("Hello")

      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test ~c"truncates when buffer is full in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.prepend(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end

    test ~c"raises error when buffer is full in error mode" do
      buffer = InputBuffer.new(5, :error)
      buffer = InputBuffer.prepend(buffer, "Hello")

      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.prepend(buffer, " World")
      end
    end

    test ~c"wraps around when buffer is full in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.prepend(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end
  end

  describe "set_contents/2" do
    test ~c"sets buffer contents" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello World"
    end

    test ~c"truncates when content exceeds max size in truncate mode" do
      buffer = InputBuffer.new(5, :truncate)
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test ~c"raises error when content exceeds max size in error mode" do
      buffer = InputBuffer.new(5, :error)

      assert_raise RuntimeError, "Buffer overflow", fn ->
        InputBuffer.set_contents(buffer, "Hello World")
      end
    end

    test ~c"wraps around when content exceeds max size in wrap mode" do
      buffer = InputBuffer.new(5, :wrap)
      buffer = InputBuffer.set_contents(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "World"
    end
  end

  describe "clear/1" do
    test ~c"clears the buffer contents" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello World")
      assert InputBuffer.get_contents(buffer) == "Hello World"

      buffer = InputBuffer.clear(buffer)
      assert InputBuffer.get_contents(buffer) == ""
    end
  end

  describe "empty?/1" do
    test ~c"returns true for empty buffer" do
      buffer = InputBuffer.new()
      assert InputBuffer.empty?(buffer)
    end

    test ~c"returns false for non-empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      refute InputBuffer.empty?(buffer)
    end
  end

  describe "size/1" do
    test ~c"returns the current size of the buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      assert InputBuffer.size(buffer) == 5
    end
  end

  describe "set_max_size/2" do
    test ~c"sets the maximum buffer size" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_max_size(buffer, 100)
      assert InputBuffer.max_size(buffer) == 100
    end

    test ~c"truncates content when reducing max size in truncate mode" do
      buffer = InputBuffer.new(10, :truncate)
      buffer = InputBuffer.append(buffer, "Hello World")
      buffer = InputBuffer.set_max_size(buffer, 5)
      assert InputBuffer.get_contents(buffer) == "Hello"
    end
  end

  describe "set_overflow_mode/2" do
    test ~c"sets the overflow mode" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.set_overflow_mode(buffer, :error)
      assert InputBuffer.overflow_mode(buffer) == :error
    end
  end

  describe "backspace/1" do
    test ~c"removes the last character" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.backspace(buffer)
      assert InputBuffer.get_contents(buffer) == "Hell"
    end

    test ~c"does nothing on empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.backspace(buffer)
      assert InputBuffer.empty?(buffer)
    end
  end

  describe "delete_first/1" do
    test ~c"removes the first character" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.delete_first(buffer)
      assert InputBuffer.get_contents(buffer) == "ello"
    end

    test ~c"does nothing on empty buffer" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.delete_first(buffer)
      assert InputBuffer.empty?(buffer)
    end
  end

  describe "insert_at/3" do
    test ~c"inserts a character at the specified position" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hllo")
      buffer = InputBuffer.insert_at(buffer, 1, "e")
      assert InputBuffer.get_contents(buffer) == "Hello"
    end

    test ~c"appends when position is at the end" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.insert_at(buffer, 5, "!")
      assert InputBuffer.get_contents(buffer) == "Hello!"
    end

    test ~c"raises error when position is out of bounds" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")

      assert_raise ArgumentError, "Position out of bounds", fn ->
        InputBuffer.insert_at(buffer, 10, "!")
      end
    end
  end

  describe "replace_at/3" do
    test ~c"replaces a character at the specified position" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")
      buffer = InputBuffer.replace_at(buffer, 1, "E")
      assert InputBuffer.get_contents(buffer) == "HEllo"
    end

    test ~c"raises error when position is out of bounds" do
      buffer = InputBuffer.new()
      buffer = InputBuffer.append(buffer, "Hello")

      assert_raise ArgumentError, "Position out of bounds", fn ->
        InputBuffer.replace_at(buffer, 10, "!")
      end
    end
  end
end

# --- Added tests for Raxol.Terminal.Input (input.ex) ---
defmodule Raxol.Terminal.InputTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input

  describe "tab_complete/1" do
    test 'completes with a single match' do
      input = %Input{buffer: ["d", "e", "f"], completion_callback: fn _ -> ["defmodule"] end}
      result = Input.tab_complete(input)
      assert result.buffer == ["d", "e", "f", "m", "o", "d", "u", "l", "e"]
      assert result.completion_options == []
      assert result.completion_index == 0
    end

    test 'cycles through multiple matches' do
      input = %Input{buffer: ["d"], completion_callback: fn _ -> ["def", "defmodule", "do"] end, completion_index: 0}
      result1 = Input.tab_complete(input)
      assert result1.buffer == ["d", "e", "f"]
      result2 = Input.tab_complete(result1)
      assert result2.buffer == ["d", "e", "f", "m", "o", "d", "u", "l", "e"]
      result3 = Input.tab_complete(result2)
      assert result3.buffer == ["d", "o"]
      result4 = Input.tab_complete(result3)
      assert result4.buffer == ["d", "e", "f"]
    end

    test 'no matches leaves buffer unchanged' do
      input = %Input{buffer: ["x", "y", "z"], completion_callback: fn _ -> [] end}
      result = Input.tab_complete(input)
      assert result.buffer == ["x", "y", "z"]
    end
  end

  describe "example_completion_callback/1" do
    test 'returns Elixir keywords that match the buffer' do
      result_d = Input.example_completion_callback("d")
      assert "def" in result_d
      assert "defmodule" in result_d 
      assert "defp" in result_d
      assert "do" in result_d
      
      result_def = Input.example_completion_callback("def")
      assert "def" in result_def
      assert "defmodule" in result_def
      assert "defp" in result_def
      
      assert Input.example_completion_callback("xyz") == []
    end
  end

  describe "mouse event handling" do
    test ~c"handle_click stores last click position and button" do
      input = %Input{}
      result = :erlang.apply(Input, :handle_click, [input, 1, 2, :left])
      assert result.last_click == {1, 2, :left}
    end

    test ~c"handle_drag stores last drag position and button" do
      input = %Input{}
      result = :erlang.apply(Input, :handle_drag, [input, 3, 4, :left])
      assert result.last_drag == {3, 4, :left}
    end

    test ~c"handle_release stores last release position and button" do
      input = %Input{}
      result = :erlang.apply(Input, :handle_release, [input, 5, 6, :left])
      assert result.last_release == {5, 6, :left}
    end
  end
end
