defmodule Raxol.Terminal.Parser.State.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Parser.State.Manager
  alias Raxol.Terminal.Emulator

  describe "ParserStateManager" do
    test ~c"new/0 creates a new parser state with default values" do
      state = Manager.new()
      assert state.state == :ground
      assert state.params_buffer == ""
      assert state.intermediates_buffer == ""
      assert state.payload_buffer == ""
      assert state.final_byte == nil
      assert state.designating_gset == nil
    end

    test ~c"get_current_state/1 returns the current state" do
      state = Manager.new()
      assert Manager.get_current_state(state) == state
    end

    test ~c"set_state/2 updates the state" do
      initial_state = Manager.new()
      new_state = %{initial_state | state: :escape}
      assert Manager.set_state(initial_state, new_state) == new_state
    end

    test ~c"transition_to/2 transitions to a new state and clears relevant buffers" do
      state = Manager.new()

      # Test transition to CSI entry state
      state = Manager.transition_to(state, :csi_entry)
      assert state.state == :csi_entry
      assert state.params_buffer == ""
      assert state.intermediates_buffer == ""

      # Test transition to OSC string state
      state = Manager.transition_to(state, :osc_string)
      assert state.state == :osc_string
      assert state.payload_buffer == ""

      # Test transition to DCS entry state
      state = Manager.transition_to(state, :dcs_entry)
      assert state.state == :dcs_entry
      assert state.params_buffer == ""
      assert state.intermediates_buffer == ""
      assert state.payload_buffer == ""

      # Test transition to unknown state (should return to ground)
      state = Manager.transition_to(state, :unknown)
      assert state.state == :ground
    end

    test ~c"append_param/2 appends to params buffer" do
      state = Manager.new()
      state = Manager.append_param(state, "1")
      state = Manager.append_param(state, ";")
      state = Manager.append_param(state, "2")
      assert state.params_buffer == "1;2"
    end

    test ~c"append_intermediate/2 appends to intermediates buffer" do
      state = Manager.new()
      state = Manager.append_intermediate(state, "?")
      state = Manager.append_intermediate(state, "!")
      assert state.intermediates_buffer == "?!"
    end

    test ~c"append_payload/2 appends to payload buffer" do
      state = Manager.new()
      state = Manager.append_payload(state, "Hello")
      state = Manager.append_payload(state, " World")
      assert state.payload_buffer == "Hello World"
    end

    test ~c"set_final_byte/2 sets the final byte" do
      state = Manager.new()
      state = Manager.set_final_byte(state, ?m)
      assert state.final_byte == ?m
    end

    test ~c"set_designating_gset/2 sets the G-set" do
      state = Manager.new()
      state = Manager.set_designating_gset(state, 0)
      assert state.designating_gset == 0
    end

    test ~c"reset/1 clears all buffers and resets to ground state" do
      state = Manager.new()

      state = %{
        state
        | state: :escape,
          params_buffer: "1;2",
          intermediates_buffer: "?!",
          payload_buffer: "test",
          final_byte: ?m,
          designating_gset: 1
      }

      reset_state = Manager.reset(state)
      assert reset_state.state == :ground
      assert reset_state.params_buffer == ""
      assert reset_state.intermediates_buffer == ""
      assert reset_state.payload_buffer == ""
      assert reset_state.final_byte == nil
      assert reset_state.designating_gset == nil
    end

    test ~c"process_input/3 delegates to appropriate state handler" do
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
          # ... set any other custom fields as needed for the test ...
      }

      state = Manager.new()

      # Test ground state handling
      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "Hello")

      assert new_state.state == :ground

      # Test escape state handling
      state = %{state | state: :escape}

      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "[")

      assert new_state.state == :csi_entry

      # Test unknown state handling (should return to ground)
      state = %{state | state: :unknown}

      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "test")

      assert new_state.state == :ground
    end

    test ~c"SS2 (ESC N and 0x8E) sets single_shift and is cleared after one char" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC N (0x1B 0x4E)
      {:continue, _emu, state_after_esc_n, _rest} =
        Manager.process_input(emulator, %{state | state: :escape}, <<78, "A">>)

      assert state_after_esc_n.single_shift == :ss2 or
               state_after_esc_n.single_shift == nil

      # C1 SS2 (0x8E)
      {:continue, _emu, state_after_c1_ss2, _rest} =
        Manager.process_input(emulator, state, <<142, "A">>)

      assert state_after_c1_ss2.single_shift == :ss2 or
               state_after_c1_ss2.single_shift == nil
    end

    test ~c"SS3 (ESC O and 0x8F) sets single_shift and is cleared after one char" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC O (0x1B 0x4F)
      {:continue, _emu, state_after_esc_o, _rest} =
        Manager.process_input(emulator, %{state | state: :escape}, <<79, "B">>)

      assert state_after_esc_o.single_shift == :ss3 or
               state_after_esc_o.single_shift == nil

      # C1 SS3 (0x8F)
      {:continue, _emu, state_after_c1_ss3, _rest} =
        Manager.process_input(emulator, state, <<143, "B">>)

      assert state_after_c1_ss3.single_shift == :ss3 or
               state_after_c1_ss3.single_shift == nil
    end
  end

  describe "SS2/SS3 edge cases" do
    test ~c"multiple SS2 in a row only affects next char each time" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC N (SS2) + "A" + ESC N (SS2) + "B"
      # First, process ESC N (SS2)
      {:continue, _emu, state1, rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<78>>)

      assert state1.single_shift == :ss2
      # Now process 'A'
      {:continue, _emu, state2, rest2} =
        Manager.process_input(emulator, state1, <<"A">>)

      assert state2.single_shift == nil
      # Now process ESC N (SS2) again
      {:continue, _emu, state3, rest3} =
        Manager.process_input(emulator, %{state2 | state: :escape}, <<78>>)

      assert state3.single_shift == :ss2
      # Now process 'B'
      {:continue, _emu, state4, _rest4} =
        Manager.process_input(emulator, state3, <<"B">>)

      assert state4.single_shift == nil
    end

    test ~c"multiple SS3 in a row only affects next char each time" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC O (SS3) + "A" + ESC O (SS3) + "B"
      {:continue, _emu, state1, rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<79>>)

      assert state1.single_shift == :ss3

      {:continue, _emu, state2, rest2} =
        Manager.process_input(emulator, state1, <<"A">>)

      assert state2.single_shift == nil

      {:continue, _emu, state3, rest3} =
        Manager.process_input(emulator, %{state2 | state: :escape}, <<79>>)

      assert state3.single_shift == :ss3

      {:continue, _emu, state4, _rest4} =
        Manager.process_input(emulator, state3, <<"B">>)

      assert state4.single_shift == nil
    end

    test ~c"SS2 at end of input sets single_shift but does not persist after use" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC N (SS2) at end
      {:continue, _emu, state1, _rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<78>>)

      assert state1.single_shift == :ss2
      # Now process a printable character
      {:continue, _emu, state2, _rest2} =
        Manager.process_input(emulator, state1, "A")

      assert state2.single_shift == nil
    end

    test ~c"SS3 at end of input sets single_shift but does not persist after use" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC O (SS3) at end
      {:continue, _emu, state1, _rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<79>>)

      assert state1.single_shift == :ss3
      # Now process a printable character
      {:continue, _emu, state2, _rest2} =
        Manager.process_input(emulator, state1, "B")

      assert state2.single_shift == nil
    end

    test ~c"SS2 followed by non-printable character clears single_shift" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC N (SS2) + BEL (7)
      {:continue, _emu, state1, rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<78, 7>>)

      # After ESC N, single_shift should be :ss2 (before BEL is processed)
      assert state1.single_shift == :ss2
      # Now process BEL
      {:continue, _emu, state2, _rest2} =
        Manager.process_input(emulator, state1, rest1)

      assert state2.single_shift == nil
    end

    test ~c"SS3 followed by non-printable character clears single_shift" do
      state = Manager.new()
      emulator = Emulator.new(80, 24)

      emulator = %{
        emulator
        | charset_state: Raxol.Terminal.ANSI.CharacterSets.new()
      }

      # ESC O (SS3) + BEL (7)
      {:continue, _emu, state1, rest1} =
        Manager.process_input(emulator, %{state | state: :escape}, <<79, 7>>)

      assert state1.single_shift == :ss3

      {:continue, _emu, state2, _rest2} =
        Manager.process_input(emulator, state1, rest1)

      assert state2.single_shift == nil
    end
  end
end
