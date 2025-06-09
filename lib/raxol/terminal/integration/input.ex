defmodule Raxol.Terminal.Integration.Input do
  @moduledoc """
  Handles input processing and command history management for the terminal.
  """

  alias Raxol.Terminal.{
    Emulator,
    Commands.History,
    Integration.State
  }

  @doc """
  Processes user input and updates the terminal state.
  """
  def handle_input(%State{} = state, input) when is_binary(input) do
    state =
      if state.config.enable_command_history do
        %{
          state
          | command_history: History.save_input(state.command_history, input)
        }
      else
        state
      end

    # Process the input through the emulator
    {emulator, _output} = Emulator.process_input(state.emulator, input)

    # Update the state with the new emulator state
    State.update(state, emulator: emulator)
  end

  @doc """
  Handles up arrow key press for command history navigation.
  """
  def handle_up_arrow(%State{} = state) do
    if state.config.enable_command_history do
      {command, command_history} = History.previous(state.command_history)

      if command do
        state
        |> State.update(command_history: command_history)
        |> handle_input(command)
      else
        state
      end
    else
      state
    end
  end

  @doc """
  Handles down arrow key press for command history navigation.
  """
  def handle_down_arrow(%State{} = state) do
    if state.config.enable_command_history do
      {command, command_history} = History.next(state.command_history)

      if command do
        state
        |> State.update(command_history: command_history)
        |> handle_input(command)
      else
        state
      end
    else
      state
    end
  end

  @doc """
  Handles tab completion for commands.
  """
  def handle_tab_completion(%State{} = state) do
    case get_completions(state) do
      [] ->
        # No completions available
        state

      [completion] when is_binary(completion) ->
        handle_input(state, completion)

      [_ | _] = completions ->
        # Multiple completions - show them
        show_completions(state, completions)

      _ ->
        state
    end
  end

  @doc """
  Handles special key combinations.
  """
  def handle_special_key(%State{} = state, key) do
    case key do
      :ctrl_c -> handle_ctrl_c(state)
      :ctrl_d -> handle_ctrl_d(state)
      :ctrl_l -> handle_ctrl_l(state)
      :ctrl_r -> handle_ctrl_r(state)
      :tab -> handle_tab_completion(state)
      _ -> state
    end
  end

  # Private functions

  defp get_completions(%State{emulator: emulator}) do
    # Get the current input line from the emulator
    current_line = emulator.state.current_line || ""

    # Get available commands from the command registry
    available_commands = Raxol.Terminal.Commands.Registry.list_commands()

    # Filter commands that start with the current input
    available_commands
    |> Enum.filter(&String.starts_with?(&1, current_line))
    |> Enum.sort()
  end

  defp show_completions(state, completions) do
    # Format completions for display
    formatted = Enum.join(completions, "  ")

    # Add a newline and show completions
    state
    |> handle_input("\n")
    |> handle_input(formatted)
    |> handle_input("\n")
  end

  defp handle_ctrl_c(state) do
    # Send SIGINT to the current process
    # Implementation depends on process management
    state
  end

  defp handle_ctrl_d(state) do
    # Send EOF to the current process
    # Implementation depends on process management
    state
  end

  defp handle_ctrl_l(state) do
    # Clear screen
    emulator = Raxol.Terminal.Commands.Screen.clear_screen(state.emulator, 2)
    State.update(state, emulator: emulator)
  end

  defp handle_ctrl_r(state) do
    # Start reverse search
    # Implementation depends on search functionality
    state
  end
end
