defmodule Raxol.Terminal.CommandHistory do
  @moduledoc """
  Manages command history for the terminal emulator.

  This module provides functionality for:
  - Storing and retrieving command history
  - Navigating through command history
  - Persisting command history
  - Managing history size limits

  DEPRECATED: This module is being refactored into the Raxol.Terminal.Commands.History module.
  New code should use the Raxol.Terminal.Commands.History module directly.
  """

  # Display a compile-time deprecation warning
  @deprecated "This module is deprecated. Use Raxol.Terminal.Commands.History instead."

  alias Raxol.Terminal.Commands.History
  require Logger

  @type t :: %__MODULE__{
          commands: [String.t()],
          current_index: integer(),
          max_size: non_neg_integer(),
          current_input: String.t()
        }

  defstruct [
    :commands,
    :current_index,
    :max_size,
    :current_input
  ]

  @doc """
  Creates a new command history manager.

  DEPRECATED: Use Raxol.Terminal.Commands.History.new/1 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history.max_size
      1000

  ## Migration Path

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.new(1000)

  # After
  history = Raxol.Terminal.Commands.History.new(1000)
  ```
  """
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.new/1 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.new/1 instead."
    )

    History.new(max_size)
  end

  @doc """
  Adds a command to the history.

  DEPRECATED: Use Raxol.Terminal.Commands.History.add/2 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history.commands
      ["ls -la"]

  ## Migration Path

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.add(history, "ls -la")

  # After
  history = Raxol.Terminal.Commands.History.add(history, "ls -la")
  ```
  """
  def add(%__MODULE__{} = history, command) when is_binary(command) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.add/2 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.add/2 instead."
    )

    # Convert to new structure, add command, then convert back for compatibility
    new_history = convert_to_new(history)
    |> History.add(command)
    convert_to_old(new_history)
  end

  @doc """
  Retrieves the previous command in history.

  DEPRECATED: Use Raxol.Terminal.Commands.History.previous/1 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> CommandHistory.previous(history)
      {"cd /tmp", %CommandHistory{...}}

  ## Migration Path

  ```elixir
  # Before
  {command, history} = Raxol.Terminal.CommandHistory.previous(history)

  # After
  {command, history} = Raxol.Terminal.Commands.History.previous(history)
  ```
  """
  def previous(%__MODULE__{} = history) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.previous/1 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.previous/1 instead."
    )

    # Convert to new structure, get previous, then convert back
    new_history = convert_to_new(history)
    {command, updated_history} = History.previous(new_history)
    {command, convert_to_old(updated_history)}
  end

  @doc """
  Retrieves the next command in history.

  DEPRECATED: Use Raxol.Terminal.Commands.History.next/1 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> {_, history} = CommandHistory.previous(history)
      iex> CommandHistory.next(history)
      {"ls -la", %CommandHistory{...}}

  ## Migration Path

  ```elixir
  # Before
  {command, history} = Raxol.Terminal.CommandHistory.next(history)

  # After
  {command, history} = Raxol.Terminal.Commands.History.next(history)
  ```
  """
  def next(%__MODULE__{} = history) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.next/1 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.next/1 instead."
    )

    # Convert to new structure, get next, then convert back
    new_history = convert_to_new(history)
    {command, updated_history} = History.next(new_history)
    {command, convert_to_old(updated_history)}
  end

  @doc """
  Saves the current input state.

  DEPRECATED: Use Raxol.Terminal.Commands.History.save_input/2 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.save_input(history, "ls -l")
      iex> history.current_input
      "ls -l"

  ## Migration Path

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.save_input(history, "ls -l")

  # After
  history = Raxol.Terminal.Commands.History.save_input(history, "ls -l")
  ```
  """
  def save_input(%__MODULE__{} = history, input) when is_binary(input) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.save_input/2 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.save_input/2 instead."
    )

    # Convert to new structure, save input, then convert back
    new_history = convert_to_new(history)
    |> History.save_input(input)
    convert_to_old(new_history)
  end

  @doc """
  Clears the command history.

  DEPRECATED: Use Raxol.Terminal.Commands.History.clear/1 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.clear(history)
      iex> history.commands
      []

  ## Migration Path

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.clear(history)

  # After
  history = Raxol.Terminal.Commands.History.clear(history)
  ```
  """
  def clear(%__MODULE__{} = history) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.clear/1 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.clear/1 instead."
    )

    # Convert to new structure, clear, then convert back
    new_history = convert_to_new(history)
    |> History.clear()
    convert_to_old(new_history)
  end

  @doc """
  Returns the current command history as a list.

  DEPRECATED: Use Raxol.Terminal.Commands.History.list/1 instead.

  ## Examples

      iex> history = CommandHistory.new(1000)
      iex> history = CommandHistory.add(history, "ls -la")
      iex> history = CommandHistory.add(history, "cd /tmp")
      iex> CommandHistory.list(history)
      ["cd /tmp", "ls -la"]

  ## Migration Path

  ```elixir
  # Before
  commands = Raxol.Terminal.CommandHistory.list(history)

  # After
  commands = Raxol.Terminal.Commands.History.list(history)
  ```
  """
  def list(%__MODULE__{} = history) do
    Logger.warn(
      "Raxol.Terminal.CommandHistory.list/1 is deprecated. " <>
      "Use Raxol.Terminal.Commands.History.list/1 instead."
    )

    # Convert to new structure and get list
    new_history = convert_to_new(history)
    History.list(new_history)
  end

  # Helper functions for compatibility

  defp convert_to_new(%__MODULE__{} = old) do
    %History{
      commands: old.commands,
      current_index: old.current_index,
      max_size: old.max_size,
      current_input: old.current_input
    }
  end

  defp convert_to_old(%History{} = new) do
    %__MODULE__{
      commands: new.commands,
      current_index: new.current_index,
      max_size: new.max_size,
      current_input: new.current_input
    }
  end
end
