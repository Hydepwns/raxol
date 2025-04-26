defmodule Raxol.Components.Input.MultiLineInput.ClipboardHelper do
  @moduledoc """
  Helper functions for clipboard operations (copy, cut, paste) in MultiLineInput.
  """

  alias Raxol.Components.Input.MultiLineInput # May need state struct definition
  alias Raxol.Components.Input.MultiLineInput.NavigationHelper
  alias Raxol.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Core.Runtime.Command
  require Logger

  # Returns {state, commands}
  def copy_selection(state) do
    if state.selection_start && state.selection_end do
      {start_pos, end_pos} = NavigationHelper.normalize_selection(state)
      # This helper needs to be defined or moved
      selected_text = get_text_range(state.value, start_pos, end_pos)
      command = Command.new(:clipboard_write, selected_text)
      {state, [command]}
    else
      {state, []} # Nothing selected, no command
    end
  end

  # Returns {state_after_cut, commands}
  def cut_selection(state) do
    if state.selection_start && state.selection_end do
      # Get selected text first
      {start_pos, end_pos} = NavigationHelper.normalize_selection(state)
      selected_text = get_text_range(state.value, start_pos, end_pos)

      # Delete the selection (returns {new_state, _deleted_text})
      {state_after_delete, _} = TextHelper.delete_selection(state)

      # Create the command
      command = Command.new(:clipboard_write, selected_text)

      {state_after_delete, [command]}
    else
      {state, []} # Nothing selected, no command
    end
  end

  # Returns {state, commands}
  def paste(state) do
    # Request clipboard content
    command = Command.new(:clipboard_read, nil)
    {state, [command]}
    # The actual insertion will happen in MultiLineInput.update/2
    # when {:clipboard_content, text} is received.
  end

  # Helper to get text within a range ({row, col} tuples)
  # (Similar to logic within TextHelper.replace_text_range)
  defp get_text_range(text, start_pos_tuple, end_pos_tuple) do
    lines = String.split(text, "\n")
    start_index = TextHelper.pos_to_index(lines, start_pos_tuple)
    end_index = TextHelper.pos_to_index(lines, end_pos_tuple)

    # Ensure indices are valid and ordered
    text_len = String.length(text)
    start_index = TextHelper.clamp(start_index, 0, text_len)
    end_index = TextHelper.clamp(end_index, 0, text_len)
    {start_index, end_index} = {min(start_index, end_index), max(start_index, end_index)}

    String.slice(text, start_index, max(0, end_index - start_index))
  end
end
