defmodule Raxol.Terminal.IntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Emulator

  # Helper to extract text from a ScreenBuffer
  defp buffer_text(buffer) do
    buffer.cells
    |> Enum.map(fn line ->
      Enum.map_join(line, &(&1.char || " "))
    end)
    |> Enum.join("\n")
  end

  describe "input to screen buffer integration" do
    test "processes keyboard input and updates screen buffer" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "Hello")

      assert buffer_text(state.main_screen_buffer) == "Hello"
    end

    test "handles cursor movement with arrow keys" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "Hello")
      {state, _output} = Emulator.process_input(state, "\e[D")
      {state, _output} = Emulator.process_input(state, "\e[D")
      {state, _output} = Emulator.process_input(state, "\e[D")

      assert state.main_screen_buffer.cursor == {2, 0}
    end

    test "handles line wrapping" do
      state = Emulator.new(5, 3)

      {state, _output} = Emulator.process_input(state, "HelloWorld")

      assert buffer_text(state.main_screen_buffer) == "Hello\nWorld"
    end

    test "handles screen scrolling" do
      state = Emulator.new(5, 3)

      {state, _output} = Emulator.process_input(state, "Line1\nLine2\nLine3\nLine4")

      assert length(state.main_screen_buffer.scrollback) == 1
      assert buffer_text(state.main_screen_buffer) == "Line2\nLine3\nLine4"
    end
  end

  describe "input to ANSI integration" do
    test "processes ANSI escape sequences" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "\e[31mHello\e[0m")

      cell = List.first(List.first(state.main_screen_buffer.buffer))
      assert cell.attributes[:foreground] == :red
    end

    test "handles multiple ANSI attributes" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "\e[1;4;31mHello\e[0m")

      cell = List.first(List.first(state.main_screen_buffer.buffer))
      assert cell.attributes[:bold] == true
      assert cell.attributes[:underline] == true
      assert cell.attributes[:foreground] == :red
    end

    test "handles cursor positioning" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "\e[10;5H")

      assert state.main_screen_buffer.cursor == {4, 9}
    end

    test "handles screen clearing" do
      state = Emulator.new(80, 24)

      {state, _output} = Emulator.process_input(state, "Hello")

      {state, _output} = Emulator.process_input(state, "\e[2J")

      assert buffer_text(state.main_screen_buffer) == ""
    end
  end

  describe "mouse input integration" do
    @tag :skip
    test "handles mouse clicks" do
      # ... original code ...
    end

    @tag :skip
    test "handles mouse selection" do
      # ... original code ...
    end
  end

  describe "input history integration" do
    @tag :skip
    test "maintains command history" do
      # ... original code ...
    end
  end

  describe "mode switching integration" do
    @tag :skip
    test "handles mode transitions" do
      # ... original code ...
    end
  end

  describe "bracketed paste integration" do
    @tag :skip
    test "handles bracketed paste mode" do
      # ... original code ...
    end
  end

  describe "modifier key integration" do
    @tag :skip
    test "handles modifier keys" do
      # ... original code ...
    end
  end
end
