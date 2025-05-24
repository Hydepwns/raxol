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
    # Get the current input line
    current_input = get_current_input(state)

    # Get possible completions
    completions = get_completions(current_input)

    case completions do
      [completion] ->
        # Single completion, apply it
        handle_input(state, completion)

      [] ->
        # No completions, do nothing
        state

      _ ->
        # Multiple completions, show them
        show_completions(state, completions)
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

  defp get_current_input(%State{} = state) do
    state.buffer_manager
    |> get_current_line()
    |> String.trim()
  end

  defp get_current_line(buffer_manager) do
    # Implementation depends on buffer manager interface
    # This is a placeholder
    ""
  end

  defp get_completions(input) do
    # Implementation depends on command completion system
    # This is a placeholder
    []
  end

  defp show_completions(state, completions) do
    # Implementation depends on UI requirements
    # This is a placeholder
    state
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
    {emulator, _} = Raxol.Terminal.Emulator.clear_screen(state.emulator)
    State.update(state, emulator: emulator)
  end

  defp handle_ctrl_r(state) do
    # Start reverse search
    # Implementation depends on search functionality
    state
  end
end
