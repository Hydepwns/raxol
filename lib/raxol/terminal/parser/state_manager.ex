defmodule Raxol.Terminal.Parser.StateManager do
  @moduledoc """
  Manages parser state transitions.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Parser.State

  @doc """
  Creates a new parser state.
  """
  @spec new() :: State.t()
  def new do
    %State{state: :ground}
  end

  @doc """
  Gets the current parser state.
  """
  @spec get_state(EmulatorStruct.t()) :: State.t()
  def get_state(emulator) do
    emulator.parser_state
  end

  @doc """
  Updates the parser state.
  """
  @spec update_state(EmulatorStruct.t(), State.t()) :: EmulatorStruct.t()
  def update_state(emulator, state) do
    %{emulator | parser_state: state}
  end

  @doc """
  Gets the current state name.
  """
  @spec get_state_name(EmulatorStruct.t()) :: atom()
  def get_state_name(emulator) do
    emulator.parser_state.name
  end

  @doc """
  Sets the state name.
  """
  @spec set_state_name(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def set_state_name(emulator, name) do
    state = %{emulator.parser_state | name: name}
    %{emulator | parser_state: state}
  end

  @doc """
  Resets to ground state.
  """
  @spec reset_to_ground(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_to_ground(emulator) do
    state = %{emulator.parser_state | name: :ground}
    %{emulator | parser_state: state}
  end

  @doc """
  Checks if in ground state.
  """
  @spec in_ground_state?(EmulatorStruct.t()) :: boolean()
  def in_ground_state?(emulator) do
    emulator.parser_state.name == :ground
  end

  @doc """
  Checks if in escape state.
  """
  @spec in_escape_state?(EmulatorStruct.t()) :: boolean()
  def in_escape_state?(emulator) do
    emulator.parser_state.name == :escape
  end

  @doc """
  Checks if in control sequence state.
  """
  @spec in_control_sequence_state?(EmulatorStruct.t()) :: boolean()
  def in_control_sequence_state?(emulator) do
    emulator.parser_state.name == :csi
  end
end
