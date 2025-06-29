defmodule Raxol.Terminal.ANSI.StateMachineTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.StateMachine

  describe "new/0" do
    test ~c"creates a new parser state with default values" do
      state = StateMachine.new()
      assert state.state == :ground
      assert state.params_buffer == ""
      assert state.intermediates_buffer == ""
      assert state.payload_buffer == ""
      assert state.final_byte == nil
      assert state.designating_gset == nil
    end
  end

  describe "process/2" do
    test ~c"handles simple text" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "Hello")
      assert new_state.state == :ground
      assert length(sequences) == 5
      assert Enum.all?(sequences, &(&1.type == :text))
      assert Enum.map(sequences, & &1.text) == ["H", "e", "l", "l", "o"]
    end

    test ~c"handles CSI sequences" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e[1;2;3m")
      assert new_state.state == :ground
      assert length(sequences) == 1
      [sequence] = sequences
      assert sequence.type == :csi
      assert sequence.command == "m"
      assert sequence.params == ["1", "2", "3"]
      assert sequence.intermediate == ""
      assert sequence.final == "m"
    end

    test ~c"handles OSC sequences" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e]0;title\a")
      assert new_state.state == :ground
      assert length(sequences) == 1
      [sequence] = sequences
      assert sequence.type == :osc
      assert sequence.command == "0"
      assert sequence.params == ["title"]
      assert sequence.text == "title"
    end

    test ~c"handles character set designation" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e(0")
      assert new_state.state == :ground
      assert length(sequences) == 1
      [sequence] = sequences
      assert sequence.type == :esc
      assert sequence.command == "(0"
    end

    test ~c"handles invalid sequences" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e[invalid")
      IO.inspect(sequences, label: "Sequences for invalid input")
      assert new_state.state in [:ground, :ignore]
      assert length(sequences) == 0
    end

    test ~c"handles CAN/SUB in CSI sequences" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e[1\x18")
      assert new_state.state == :ground
      assert length(sequences) == 0
    end

    test ~c"handles OSC with ST terminator" do
      state = StateMachine.new()
      {new_state, sequences} = StateMachine.process(state, "\e]0;title\e\\")
      assert new_state.state == :ground
      assert length(sequences) == 1
      [sequence] = sequences
      assert sequence.type == :osc
      assert sequence.command == "0"
      assert sequence.params == ["title"]
      assert sequence.text == "title"
    end

    test ~c"handles multiple sequences" do
      state = StateMachine.new()

      {new_state, sequences} =
        StateMachine.process(state, "Hello\e[1mWorld\e[0m")

      assert new_state.state == :ground
      assert length(sequences) == 12

      assert Enum.map(sequences, & &1.type) == [
               :text,
               :text,
               :text,
               :text,
               :text,
               :csi,
               :text,
               :text,
               :text,
               :text,
               :text,
               :csi
             ]
    end
  end
end
