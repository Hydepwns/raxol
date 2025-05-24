defmodule Raxol.Terminal.Parser.State.Manager do
  @moduledoc """
  Manages parser state transitions and state-specific functionality for the terminal emulator.
  This module provides a clean interface for managing the parser's state machine and delegating
  to appropriate state handlers.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State

  alias Raxol.Terminal.Parser.States.{
    GroundState,
    EscapeState,
    DesignateCharsetState,
    CSIEntryState,
    CSIParamState,
    CSIIntermediateState,
    OSCStringState,
    OSCStringMaybeSTState,
    DCSEntryState,
    DCSPassthroughState,
    DCSPassthroughMaybeSTState
  }

  @doc """
  Creates a new parser state with default values.
  """
  @spec new() :: map()
  def new do
    %State{
      state: :ground,
      params_buffer: "",
      intermediates_buffer: "",
      payload_buffer: "",
      final_byte: nil,
      designating_gset: nil
    }
  end

  @doc """
  Gets the current parser state.
  """
  @spec get_current_state(map()) :: map()
  def get_current_state(state) do
    state
  end

  @doc """
  Sets the parser state to a new value.
  """
  @spec set_state(map(), map()) :: map()
  def set_state(_current_state, new_state) do
    new_state
  end

  @doc """
  Processes input in the current parser state.
  Returns the updated emulator and parser state.
  """
  @spec process_input(Emulator.t(), map(), binary()) ::
          {:continue, Emulator.t(), map(), binary()}
          | {:incomplete, Emulator.t(), map()}
          | {:handled, Emulator.t()}
  def process_input(emulator, state, input) do
    case state.state do
      :ground ->
        GroundState.handle(emulator, state, input)

      :escape ->
        EscapeState.handle(emulator, state, input)

      :designate_charset ->
        DesignateCharsetState.handle(emulator, state, input)

      :csi_entry ->
        CSIEntryState.handle(emulator, state, input)

      :csi_param ->
        CSIParamState.handle(emulator, state, input)

      :csi_intermediate ->
        CSIIntermediateState.handle(emulator, state, input)

      :osc_string ->
        OSCStringState.handle(emulator, state, input)

      :osc_string_maybe_st ->
        OSCStringMaybeSTState.handle(emulator, state, input)

      :dcs_entry ->
        DCSEntryState.handle(emulator, state, input)

      :dcs_passthrough ->
        DCSPassthroughState.handle(emulator, state, input)

      :dcs_passthrough_maybe_st ->
        DCSPassthroughMaybeSTState.handle(emulator, state, input)

      _ ->
        # Unknown state, return to ground
        {:continue, emulator, %{state | state: :ground}, input}
    end
  end

  @doc """
  Transitions to a new parser state, clearing relevant buffers.
  """
  @spec transition_to(map(), atom()) :: map()
  def transition_to(state, new_state) do
    case new_state do
      :ground ->
        %{state | state: :ground}

      :escape ->
        %{state | state: :escape}

      :designate_charset ->
        %{state | state: :designate_charset}

      :csi_entry ->
        %{
          state
          | state: :csi_entry,
            params_buffer: "",
            intermediates_buffer: ""
        }

      :csi_param ->
        %{
          state
          | state: :csi_param,
            params_buffer: "",
            intermediates_buffer: ""
        }

      :csi_intermediate ->
        %{
          state
          | state: :csi_intermediate,
            intermediates_buffer: ""
        }

      :osc_string ->
        %{
          state
          | state: :osc_string,
            payload_buffer: ""
        }

      :osc_string_maybe_st ->
        %{state | state: :osc_string_maybe_st}

      :dcs_entry ->
        %{
          state
          | state: :dcs_entry,
            params_buffer: "",
            intermediates_buffer: "",
            payload_buffer: ""
        }

      :dcs_passthrough ->
        %{
          state
          | state: :dcs_passthrough,
            payload_buffer: ""
        }

      :dcs_passthrough_maybe_st ->
        %{state | state: :dcs_passthrough_maybe_st}

      _ ->
        # Unknown state, return to ground
        %{state | state: :ground}
    end
  end

  @doc """
  Appends a byte to the params buffer.
  """
  @spec append_param(map(), binary()) :: map()
  def append_param(state, byte) do
    %{state | params_buffer: state.params_buffer <> byte}
  end

  @doc """
  Appends a byte to the intermediates buffer.
  """
  @spec append_intermediate(map(), binary()) :: map()
  def append_intermediate(state, byte) do
    %{state | intermediates_buffer: state.intermediates_buffer <> byte}
  end

  @doc """
  Appends a byte to the payload buffer.
  """
  @spec append_payload(map(), binary()) :: map()
  def append_payload(state, byte) do
    %{state | payload_buffer: state.payload_buffer <> byte}
  end

  @doc """
  Sets the final byte for the current sequence.
  """
  @spec set_final_byte(map(), integer()) :: map()
  def set_final_byte(state, byte) do
    %{state | final_byte: byte}
  end

  @doc """
  Sets the G-set being designated.
  """
  @spec set_designating_gset(map(), non_neg_integer()) :: map()
  def set_designating_gset(state, gset) do
    %{state | designating_gset: gset}
  end

  @doc """
  Clears all buffers and resets the state to ground.
  """
  @spec reset(map()) :: map()
  def reset(state) do
    %{
      state
      | state: :ground,
        params_buffer: "",
        intermediates_buffer: "",
        payload_buffer: "",
        final_byte: nil,
        designating_gset: nil
    }
  end
end
