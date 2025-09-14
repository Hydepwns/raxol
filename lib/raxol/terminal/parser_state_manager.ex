defmodule Raxol.Terminal.ParserStateManager do
  @moduledoc """
  Consolidated terminal parser state manager combining simple emulator operations with
  comprehensive parser state management.

  This module consolidates functionality from:
  - Simple parser state operations on Emulator structs
  - Comprehensive parser state management from Parser.State.Manager

  ## Usage
  For simple emulator operations:
      emulator = ParserStateManager.reset_parser_state(emulator)
      
  For comprehensive parser operations:
      manager = ParserStateManager.create_parser_manager()
      manager = ParserStateManager.process_char(manager, ?A)
      
  ## Migration from Parser.State.Manager
  Use `create_parser_manager/0` instead of `Parser.State.Manager.new/0`
  """

  alias Raxol.Terminal.{Emulator, ParserState}
  alias Raxol.Terminal.Parser.State.Manager, as: DetailedManager
  require Raxol.Core.Runtime.Log

  # Delegate comprehensive parser management to the detailed manager
  defdelegate create_parser_manager(), to: DetailedManager, as: :new

  defdelegate process_parser_char(manager, char),
    to: DetailedManager,
    as: :process_char

  @doc """
  Gets the current parser state.
  Returns the parser state.
  """
  @spec get_parser_state(Emulator.t()) :: ParserState.t()
  def get_parser_state(emulator) do
    emulator.parser_state
  end

  @doc """
  Updates the parser state.
  Returns the updated emulator.
  """
  @spec update_parser_state(Emulator.t(), ParserState.t()) :: Emulator.t()
  def update_parser_state(emulator, new_state) do
    %{emulator | parser_state: new_state}
  end

  @doc """
  Resets the parser state to its initial state.
  Returns the updated emulator.
  """
  @spec reset_parser_state(Emulator.t()) :: Emulator.t()
  def reset_parser_state(emulator) do
    %{emulator | parser_state: ParserState.new()}
  end

  @doc """
  Processes a character in the current parser state.
  Returns the updated emulator and any output.
  """
  @spec process_char(Emulator.t(), char()) :: {Emulator.t(), any()}
  def process_char(emulator, char) do
    state = get_parser_state(emulator)
    output = ParserState.process_char(state, char)
    {emulator, output}
  end

  @doc """
  Gets the current parser mode.
  Returns the current mode.
  """
  @spec get_mode(Emulator.t()) :: atom()
  def get_mode(emulator) do
    emulator.parser_state.mode
  end

  @doc """
  Sets the parser mode.
  Returns the updated emulator.
  """
  @spec set_mode(Emulator.t(), atom()) :: Emulator.t()
  def set_mode(emulator, mode) do
    state = get_parser_state(emulator)
    new_state = %{state | mode: mode}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Gets the current parser parameters.
  Returns the list of parameters.
  """
  @spec get_params(Emulator.t()) :: [String.t()]
  def get_params(emulator) do
    emulator.parser_state.params
  end

  @doc """
  Sets the parser parameters.
  Returns the updated emulator.
  """
  @spec set_params(Emulator.t(), [String.t()]) :: Emulator.t()
  def set_params(emulator, params) do
    state = get_parser_state(emulator)
    new_state = %{state | params: params}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Adds a parameter to the current parser state.
  Returns the updated emulator.
  """
  @spec add_param(Emulator.t(), String.t()) :: Emulator.t()
  def add_param(emulator, param) do
    state = get_parser_state(emulator)
    new_params = state.params ++ [param]
    new_state = %{state | params: new_params}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Clears all parser parameters.
  Returns the updated emulator.
  """
  @spec clear_params(Emulator.t()) :: Emulator.t()
  def clear_params(emulator) do
    state = get_parser_state(emulator)
    new_state = %{state | params: []}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Gets the current intermediate characters.
  Returns the list of intermediate characters.
  """
  @spec get_intermediates(Emulator.t()) :: [char()]
  def get_intermediates(emulator) do
    emulator.parser_state.intermediates
  end

  @doc """
  Sets the intermediate characters.
  Returns the updated emulator.
  """
  @spec set_intermediates(Emulator.t(), [char()]) :: Emulator.t()
  def set_intermediates(emulator, intermediates) do
    state = get_parser_state(emulator)
    new_state = %{state | intermediates: intermediates}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Adds an intermediate character.
  Returns the updated emulator.
  """
  @spec add_intermediate(Emulator.t(), char()) :: Emulator.t()
  def add_intermediate(emulator, char) do
    state = get_parser_state(emulator)
    new_intermediates = state.intermediates ++ [char]
    new_state = %{state | intermediates: new_intermediates}
    update_parser_state(emulator, new_state)
  end

  @doc """
  Clears all intermediate characters.
  Returns the updated emulator.
  """
  @spec clear_intermediates(Emulator.t()) :: Emulator.t()
  def clear_intermediates(emulator) do
    state = get_parser_state(emulator)
    new_state = %{state | intermediates: []}
    update_parser_state(emulator, new_state)
  end
end
