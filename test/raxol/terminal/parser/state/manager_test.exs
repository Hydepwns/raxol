defmodule Raxol.Terminal.Parser.State.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Parser.State.Manager
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Emulator

  describe "ParserStateManager" do
    test "new/0 creates a new parser state with default values" do
      state = Manager.new()
      assert state.state == :ground
      assert state.params_buffer == ""
      assert state.intermediates_buffer == ""
      assert state.payload_buffer == ""
      assert state.final_byte == nil
      assert state.designating_gset == nil
    end

    test "get_current_state/1 returns the current state" do
      state = Manager.new()
      assert Manager.get_current_state(state) == state
    end

    test "set_state/2 updates the state" do
      initial_state = Manager.new()
      new_state = %{initial_state | state: :escape}
      assert Manager.set_state(initial_state, new_state) == new_state
    end

    test "transition_to/2 transitions to a new state and clears relevant buffers" do
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

    test "append_param/2 appends to params buffer" do
      state = Manager.new()
      state = Manager.append_param(state, "1")
      state = Manager.append_param(state, ";")
      state = Manager.append_param(state, "2")
      assert state.params_buffer == "1;2"
    end

    test "append_intermediate/2 appends to intermediates buffer" do
      state = Manager.new()
      state = Manager.append_intermediate(state, "?")
      state = Manager.append_intermediate(state, "!")
      assert state.intermediates_buffer == "?!"
    end

    test "append_payload/2 appends to payload buffer" do
      state = Manager.new()
      state = Manager.append_payload(state, "Hello")
      state = Manager.append_payload(state, " World")
      assert state.payload_buffer == "Hello World"
    end

    test "set_final_byte/2 sets the final byte" do
      state = Manager.new()
      state = Manager.set_final_byte(state, ?m)
      assert state.final_byte == ?m
    end

    test "set_designating_gset/2 sets the G-set" do
      state = Manager.new()
      state = Manager.set_designating_gset(state, 0)
      assert state.designating_gset == 0
    end

    test "reset/1 clears all buffers and resets to ground state" do
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

    test "process_input/3 delegates to appropriate state handler" do
      emulator = %Emulator{}
      state = Manager.new()

      # Test ground state handling
      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "Hello")

      assert new_state.state == :ground

      # Test escape state handling
      state = %{state | state: :escape}

      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "\e[")

      assert new_state.state == :csi_entry

      # Test unknown state handling (should return to ground)
      state = %{state | state: :unknown}

      {:continue, _emulator, new_state, _rest} =
        Manager.process_input(emulator, state, "test")

      assert new_state.state == :ground
    end
  end
end
