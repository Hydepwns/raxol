defmodule Raxol.Terminal.Parser.StateManager do
  @moduledoc """
  Manages parser state operations for the terminal emulator.
  This module handles the state of the parser, including ground state,
  escape sequences, and control sequences.
  """

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
  @spec get_state(Raxol.Terminal.Emulator.t()) :: State.t()
  def get_state(emulator) do
    emulator.parser_state
  end

  @doc """
  Updates the parser state.
  """
  @spec update_state(Raxol.Terminal.Emulator.t(), State.t()) :: Raxol.Terminal.Emulator.t()
  def update_state(emulator, state) do
    %{emulator | parser_state: state}
  end

  @doc """
  Gets the current state name.
  """
  @spec get_state_name(Raxol.Terminal.Emulator.t()) :: atom()
  def get_state_name(emulator) do
    emulator.parser_state.state
  end

  @doc """
  Sets the state name.
  """
  @spec set_state_name(Raxol.Terminal.Emulator.t(), atom()) :: Raxol.Terminal.Emulator.t()
  def set_state_name(emulator, state_name) do
    new_state = %{emulator.parser_state | state: state_name}
    %{emulator | parser_state: new_state}
  end

  @doc """
  Resets the parser state to ground.
  """
  @spec reset_to_ground(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def reset_to_ground(emulator) do
    new_state = %{emulator.parser_state | state: :ground}
    %{emulator | parser_state: new_state}
  end

  @doc """
  Checks if the parser is in ground state.
  """
  @spec in_ground_state?(Raxol.Terminal.Emulator.t()) :: boolean()
  def in_ground_state?(emulator) do
    emulator.parser_state.state == :ground
  end

  @doc """
  Checks if the parser is in escape state.
  """
  @spec in_escape_state?(Raxol.Terminal.Emulator.t()) :: boolean()
  def in_escape_state?(emulator) do
    emulator.parser_state.state == :escape
  end

  @doc """
  Checks if the parser is in control sequence state.
  """
  @spec in_control_sequence_state?(Raxol.Terminal.Emulator.t()) :: boolean()
  def in_control_sequence_state?(emulator) do
    emulator.parser_state.state == :control_sequence
  end
end
