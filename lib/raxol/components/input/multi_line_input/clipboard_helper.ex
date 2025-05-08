defmodule Raxol.Components.Input.MultiLineInput.ClipboardHelper do
  @moduledoc """
  Helper for clipboard operations (copy/cut/paste) in MultiLineInput.
  """

  alias Raxol.Components.Input.MultiLineInput, as: State
  alias Raxol.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Components.Input.MultiLineInput.NavigationHelper
  alias Raxol.Core.Runtime.Command
  require Logger

  @doc """
  Copies the currently selected text to the clipboard.
  Returns a tuple with the state (unchanged) and a list of commands to execute.
  """
  def copy_selection(%State{} = state) do
    case Raxol.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ) do
      {nil, nil} ->
        {state, []}

      {start_pos, end_pos} ->
        # Get selected text from state using positions
        selection_text = get_selected_text(state, start_pos, end_pos)
        # Use Command factory function for test compatibility
        command = Command.clipboard_write(selection_text)
        {state, [command]}
    end
  end

  @doc """
  Cuts the selected text (copies then deletes).
  Returns a tuple with the updated state and a list of commands to execute.
  """
  def cut_selection(%State{} = state) do
    case Raxol.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ) do
      {nil, nil} ->
        {state, []}

      {start_pos, end_pos} ->
        # Extract the text before removing it
        selection_text = get_selected_text(state, start_pos, end_pos)

        # Remove the selected text
        {state_after_delete, _} = TextHelper.delete_selection(state)

        # Make sure the value field is updated too
        joined_text = Enum.join(state_after_delete.lines, "\n")
        state_after_delete = %State{state_after_delete | value: joined_text}

        # Use Command factory function for test compatibility
        command = Command.clipboard_write(selection_text)
        {state_after_delete, [command]}
    end
  end

  @doc """
  Initiates a paste operation from clipboard.
  Returns a tuple with the state (unchanged) and a command to read from clipboard.
  """
  def paste(%State{} = state) do
    # Use Command factory function for test compatibility
    command = Command.clipboard_read()
    {state, [command]}
  end

  # Helper function to get text between two cursor positions
  defp get_selected_text(%State{} = state, start_pos, end_pos) do
    # Get flat indices using TextHelper
    start_idx = TextHelper.pos_to_index(state.lines, start_pos)
    end_idx = TextHelper.pos_to_index(state.lines, end_pos)

    # Extract substring
    String.slice(state.value, start_idx..(end_idx - 1))
  end
end
