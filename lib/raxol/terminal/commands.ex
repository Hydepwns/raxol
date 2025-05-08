defmodule Raxol.Terminal.Commands do
  @moduledoc """
  Facade for the Terminal Commands functionality that maintains backward compatibility.

  This module provides the same interface as the original CommandExecutor module
  but delegates to the refactored sub-modules. This allows for a smooth transition
  while code that depends on the original API is updated.

  DEPRECATED: This module is provided for backward compatibility only. New code should
  use the appropriate sub-modules directly:

  - Raxol.Terminal.Commands.Executor - Main entry point for executing commands
  - Raxol.Terminal.Commands.Parser - For parsing command parameters
  - Raxol.Terminal.Commands.Modes - For handling terminal mode setting/resetting
  - Raxol.Terminal.Commands.Screen - For screen manipulation operations
  - Raxol.Terminal.Commands.History - For command history management
  """

  alias Raxol.Terminal.Commands.{History, Parser, Modes, Screen, Executor}
  # alias Raxol.Terminal.Emulator
  # alias Raxol.Terminal.ScreenBuffer
  # alias Raxol.Terminal.Cursor
  # alias Raxol.Terminal.ANSI
  require Logger

  # --- CSI Command Execution ---

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  This method delegates to the Commands.Executor module for the actual execution.

  ## Parameters

  * `emulator` - The current emulator state
  * `params_buffer` - The parameter portion of the CSI sequence
  * `intermediates_buffer` - The intermediate bytes portion of the CSI sequence
  * `final_byte` - The final byte that determines the specific command

  ## Returns

  * Updated emulator state

  ## Migration Path

  Update your code to use the Executor module directly:

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.execute_csi_command(emulator, params, intermediates, final_byte)

  # After
  new_emulator = Raxol.Terminal.Commands.Executor.execute_csi_command(emulator, params, intermediates, final_byte)
  ```
  """
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    Logger.warning(
      "Raxol.Terminal.Commands.execute_csi_command/4 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead."
    )

    Executor.execute_csi_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      final_byte
    )
  end

  # --- Parameter Parsing ---

  @doc """
  Parses a raw parameter string buffer into a list of integers or nil values.

  This method delegates to the Commands.Parser module for the actual parsing.

  ## Parameters

  * `params_string` - The raw parameter string from a CSI sequence

  ## Returns

  * A list of parsed parameters

  ## Migration Path

  Update your code to use the Parser module directly:

  ```elixir
  # Before
  params = Raxol.Terminal.CommandExecutor.parse_params(params_string)

  # After
  params = Raxol.Terminal.Commands.Parser.parse_params(params_string)
  ```
  """
  def parse_params(params_string) do
    Logger.warning(
      "Raxol.Terminal.Commands.parse_params/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.parse_params/1 instead."
    )

    Parser.parse_params(params_string)
  end

  @doc """
  Gets a parameter at a specific index from the params list.

  This method delegates to the Commands.Parser module.

  ## Parameters

  * `params` - The list of parsed parameters
  * `index` - The index to get the parameter from
  * `default` - The default value to return if the parameter is nil or out of bounds

  ## Returns

  * The parameter value or the default value

  ## Migration Path

  Update your code to use the Parser module directly:

  ```elixir
  # Before
  value = Raxol.Terminal.CommandExecutor.get_param(params, 1, 0)

  # After
  value = Raxol.Terminal.Commands.Parser.get_param(params, 1, 0)
  ```
  """
  def get_param(params, index, default \\ 1) do
    Logger.warning(
      "Raxol.Terminal.Commands.get_param/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.get_param/3 instead."
    )

    Parser.get_param(params, index, default)
  end

  # --- Screen Operations ---

  @doc """
  Clears the screen or a part of it based on the mode parameter.

  This method delegates to the Commands.Screen module.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The mode parameter (0, 1, 2, or 3)

  ## Returns

  * Updated emulator state

  ## Migration Path

  Update your code to use the Screen module directly:

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.clear_screen(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.clear_screen(emulator, 2)
  ```
  """
  def clear_screen(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.Commands.clear_screen/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead."
    )

    Screen.clear_screen(emulator, mode)
  end

  @doc """
  Clears a line or part of a line based on the mode parameter.

  This method delegates to the Commands.Screen module.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The mode parameter (0, 1, or 2)

  ## Returns

  * Updated emulator state

  ## Migration Path

  Update your code to use the Screen module directly:

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.clear_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.clear_line(emulator, 2)
  ```
  """
  def clear_line(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.Commands.clear_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_line/2 instead."
    )

    Screen.clear_line(emulator, mode)
  end

  @doc """
  Inserts blank lines at the current cursor position.

  This method delegates to the Commands.Screen module.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to insert

  ## Returns

  * Updated emulator state

  ## Migration Path

  Update your code to use the Screen module directly:

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.insert_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.insert_lines(emulator, 2)
  ```
  """
  def insert_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.Commands.insert_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead."
    )

    Screen.insert_lines(emulator, count)
  end

  @doc """
  Deletes lines at the current cursor position.

  This method delegates to the Commands.Screen module.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to delete

  ## Returns

  * Updated emulator state

  ## Migration Path

  Update your code to use the Screen module directly:

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.delete_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.delete_lines(emulator, 2)
  ```
  """
  def delete_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.Commands.delete_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead."
    )

    Screen.delete_lines(emulator, count)
  end

  # --- Command History ---

  @doc """
  Creates a new command history manager.

  This method delegates to the Commands.History module.

  ## Parameters

  * `max_size` - The maximum number of commands to store

  ## Returns

  * A new history manager struct

  ## Migration Path

  Update your code to use the History module directly:

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.new(1000)

  # After
  history = Raxol.Terminal.Commands.History.new(1000)
  ```
  """
  def new_history(max_size) do
    Logger.warning(
      "Raxol.Terminal.Commands.new_history/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.History.new/1 instead."
    )

    History.new(max_size)
  end

  @doc """
  Adds a command to the history.

  This method delegates to the Commands.History module.

  ## Parameters

  * `history` - The history manager struct
  * `command` - The command to add

  ## Returns

  * Updated history manager struct

  ## Migration Path

  Update your code to use the History module directly:

  ```elixir
  # Before
  history = Raxol.Terminal.CommandHistory.add(history, "ls -la")

  # After
  history = Raxol.Terminal.Commands.History.add(history, "ls -la")
  ```
  """
  def add_to_history(history, command) do
    Logger.warning(
      "Raxol.Terminal.Commands.add_to_history/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.History.add/2 instead."
    )

    History.add(history, command)
  end

  @doc """
  Retrieves the previous command in history.

  This method delegates to the Commands.History module.

  ## Parameters

  * `history`
  """
  def previous_command(history) do
    Logger.warning(
      "Raxol.Terminal.Commands.previous_command/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.History.previous/1 instead."
    )

    History.previous(history)
  end

  # @doc """
  # Retrieves the next command in history.

  # This method delegates to the Commands.History module.

  # ## Parameters

  # * `history` - The history manager struct

  # ## Returns

  # * {command, updated_history} or {nil, history}

  # ## Migration Path

  # Update your code to use the History module directly:

  # ```elixir
  # # Before
  # {command, history} = Raxol.Terminal.CommandHistory.next(history)

  # # After
  # {command, history} = Raxol.Terminal.Commands.History.next(history)
  # ```
  # """
  # def next_command(history) do
  #   Logger.warning(
  #     "Raxol.Terminal.Commands.next_command/1 is deprecated. " <>
  #       "Use Raxol.Terminal.Commands.History.next/1 instead."
  #   )

  #   History.next(history)
  # end

  # --- Example Usage (Conceptual) ---
  def example_usage do
    # Assuming initial state creation or retrieval
    initial_state = %{history_buffer: Raxol.Terminal.Commands.History.new(1000)}

    # Adding a command
    state_after_add =
      Map.update!(initial_state, :history_buffer, fn history ->
        Raxol.Terminal.Commands.History.add(history, "ls -la")
      end)

    # Navigating history (example)
    {_previous_cmd, state_after_prev} =
      Map.get_and_update!(state_after_add, :history_buffer, fn history ->
        Raxol.Terminal.Commands.History.previous(history)
      end)

    # {command, history} = Raxol.Terminal.CommandHistory.next(history) # Deprecated
    {_next_cmd, _final_state} =
      Map.get_and_update!(state_after_prev, :history_buffer, fn history ->
        Raxol.Terminal.Commands.History.next(history)
      end)

    # ... other operations ...
  end
end
