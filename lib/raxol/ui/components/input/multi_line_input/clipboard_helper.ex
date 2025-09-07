defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper do
  @moduledoc """
  Helper functions for clipboard operations in MultiLineInput.
  """

  alias Raxol.UI.Components.Input.MultiLineInput, as: State
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Core.Runtime.Command

  @doc """
  Copies the currently selected text to the clipboard.
  """
  def copy_selection(%State{} = state) do
    {start_pos, end_pos} =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
        state
      )

    case {start_pos, end_pos, start_pos == end_pos} do
      {nil, _, _} ->
        {state, []}

      {_, nil, _} ->
        {state, []}

      {_, _, true} ->
        {state, []}

      {_, _, false} ->
        lines = String.split(state.value, "\n")
        start_index = TextHelper.pos_to_index(lines, start_pos)
        end_index = TextHelper.pos_to_index(lines, end_pos)

        {norm_start, norm_end} =
          {min(start_index, end_index), max(start_index, end_index)}

        # Use exclusive end position to match the fixed coordinate system
        selected_text =
          String.slice(
            Enum.join(lines, "\n"),
            norm_start,
            norm_end - norm_start
          )

        {state, [%Command{type: :clipboard_write, data: selected_text}]}
    end
  end

  @doc """
  Cuts the selected text (copies then deletes).
  """
  def cut_selection(%State{} = state) do
    # Get the selected text
    {start_pos, end_pos} =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
        state
      )

    case {start_pos, end_pos, start_pos == end_pos} do
      {nil, _, _} ->
        {state, []}

      {_, nil, _} ->
        {state, []}

      {_, _, true} ->
        {state, []}

      {_, _, false} ->
        # Get the selected text as a string
        lines = String.split(state.value, "\n")
        start_index = TextHelper.pos_to_index(lines, start_pos)
        end_index = TextHelper.pos_to_index(lines, end_pos)

        {norm_start, norm_end} =
          {min(start_index, end_index), max(start_index, end_index)}

        # Use exclusive end position to match the fixed coordinate system
        selected_text =
          String.slice(
            Enum.join(lines, "\n"),
            norm_start,
            norm_end - norm_start
          )

        # Delete the selection
        {new_state, _} = TextHelper.delete_selection(state)
        # Return new state and clipboard write command
        {new_state, [%Command{type: :clipboard_write, data: selected_text}]}
    end
  end

  @doc """
  Initiates a paste operation from clipboard.
  """
  def paste(%State{} = state) do
    # Return the state unchanged and a clipboard read command
    {state, [%Command{type: :clipboard_read}]}
  end
end
