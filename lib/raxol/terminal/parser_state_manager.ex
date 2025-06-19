defmodule Raxol.Terminal.ParserStateManager do
  @moduledoc """
  Manages terminal parser state operations including state transitions, parameter handling,
  and escape sequence processing. This module is responsible for maintaining the parser's
  internal state and processing terminal control sequences.
  """

  alias Raxol.Terminal.{Emulator, ParserState}
  require Raxol.Core.Runtime.Log

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
    {new_state, output} = ParserState.process_char(state, char)
    {update_parser_state(emulator, new_state), output}
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
