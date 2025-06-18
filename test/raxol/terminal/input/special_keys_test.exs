defmodule Raxol.Terminal.Input.SpecialKeysTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.SpecialKeys

  describe "new_state/0" do
    test ~c"creates a new modifier state with all modifiers disabled" do
      state = SpecialKeys.new_state()
      assert state.ctrl == false
      assert state.alt == false
      assert state.shift == false
      assert state.meta == false
    end
  end

  describe "update_state/3" do
    test ~c"updates ctrl modifier" do
      state = SpecialKeys.new_state()
      state = SpecialKeys.update_state(state, "Control", true)
      assert state.ctrl == true
      assert state.alt == false
      assert state.shift == false
      assert state.meta == false
    end

    test ~c"updates alt modifier" do
      state = SpecialKeys.new_state()
      state = SpecialKeys.update_state(state, "Alt", true)
      assert state.ctrl == false
      assert state.alt == true
      assert state.shift == false
      assert state.meta == false
    end

    test ~c"updates shift modifier" do
      state = SpecialKeys.new_state()
      state = SpecialKeys.update_state(state, "Shift", true)
      assert state.ctrl == false
      assert state.alt == false
      assert state.shift == true
      assert state.meta == false
    end

    test ~c"updates meta modifier" do
      state = SpecialKeys.new_state()
      state = SpecialKeys.update_state(state, "Meta", true)
      assert state.ctrl == false
      assert state.alt == false
      assert state.shift == false
      assert state.meta == true
    end

    test ~c"handles multiple modifiers" do
      state = SpecialKeys.new_state()

      state =
        state
        |> SpecialKeys.update_state("Control", true)
        |> SpecialKeys.update_state("Alt", true)
        |> SpecialKeys.update_state("Shift", true)

      assert state.ctrl == true
      assert state.alt == true
      assert state.shift == true
      assert state.meta == false
    end

    test ~c"ignores unknown modifiers" do
      state = SpecialKeys.new_state()
      state = SpecialKeys.update_state(state, "Unknown", true)
      assert state.ctrl == false
      assert state.alt == false
      assert state.shift == false
      assert state.meta == false
    end
  end

  describe "to_escape_sequence/2" do
    test ~c"handles regular characters without modifiers" do
      state = SpecialKeys.new_state()
      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[97"
    end

    test ~c"handles regular characters with ctrl modifier" do
      state =
        SpecialKeys.new_state() |> SpecialKeys.update_state("Control", true)

      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[1;97"
    end

    test ~c"handles regular characters with alt modifier" do
      state = SpecialKeys.new_state() |> SpecialKeys.update_state("Alt", true)
      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[2;97"
    end

    test ~c"handles regular characters with shift modifier" do
      state = SpecialKeys.new_state() |> SpecialKeys.update_state("Shift", true)
      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[4;97"
    end

    test ~c"handles regular characters with meta modifier" do
      state = SpecialKeys.new_state() |> SpecialKeys.update_state("Meta", true)
      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[8;97"
    end

    test ~c"handles multiple modifiers" do
      state =
        SpecialKeys.new_state()
        |> SpecialKeys.update_state("Control", true)
        |> SpecialKeys.update_state("Alt", true)
        |> SpecialKeys.update_state("Shift", true)

      assert SpecialKeys.to_escape_sequence(state, "a") == "\e[7;97"
    end

    test ~c"handles arrow keys" do
      state = SpecialKeys.new_state()
      assert SpecialKeys.to_escape_sequence(state, "ArrowUp") == "\e[A"
      assert SpecialKeys.to_escape_sequence(state, "ArrowDown") == "\e[B"
      assert SpecialKeys.to_escape_sequence(state, "ArrowRight") == "\e[C"
      assert SpecialKeys.to_escape_sequence(state, "ArrowLeft") == "\e[D"
    end

    test ~c"handles function keys" do
      state = SpecialKeys.new_state()
      assert SpecialKeys.to_escape_sequence(state, "F1") == "\e[P"
      assert SpecialKeys.to_escape_sequence(state, "F2") == "\e[Q"
      assert SpecialKeys.to_escape_sequence(state, "F3") == "\e[R"
      assert SpecialKeys.to_escape_sequence(state, "F4") == "\e[S"
      assert SpecialKeys.to_escape_sequence(state, "F5") == "\e[15~"
      assert SpecialKeys.to_escape_sequence(state, "F6") == "\e[17~"
      assert SpecialKeys.to_escape_sequence(state, "F7") == "\e[18~"
      assert SpecialKeys.to_escape_sequence(state, "F8") == "\e[19~"
      assert SpecialKeys.to_escape_sequence(state, "F9") == "\e[20~"
      assert SpecialKeys.to_escape_sequence(state, "F10") == "\e[21~"
      assert SpecialKeys.to_escape_sequence(state, "F11") == "\e[23~"
      assert SpecialKeys.to_escape_sequence(state, "F12") == "\e[24~"
    end

    test ~c"handles navigation keys" do
      state = SpecialKeys.new_state()
      assert SpecialKeys.to_escape_sequence(state, "Home") == "\e[H"
      assert SpecialKeys.to_escape_sequence(state, "End") == "\e[F"
      assert SpecialKeys.to_escape_sequence(state, "PageUp") == "\e[5~"
      assert SpecialKeys.to_escape_sequence(state, "PageDown") == "\e[6~"
      assert SpecialKeys.to_escape_sequence(state, "Insert") == "\e[2~"
      assert SpecialKeys.to_escape_sequence(state, "Delete") == "\e[3~"
    end

    test ~c"handles unknown keys" do
      state = SpecialKeys.new_state()
      assert SpecialKeys.to_escape_sequence(state, "Unknown") == ""
    end
  end
end
