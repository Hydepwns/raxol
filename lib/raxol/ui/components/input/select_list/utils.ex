defmodule Raxol.UI.Components.Input.SelectList.Utils do
  @moduledoc """
  Shared utility functions for SelectList component modules.
  Eliminates code duplication between Navigation and Selection modules.
  """

  alias Raxol.UI.Components.Input.SelectList

  @doc """
  Ensures that the selected item is visible within the scroll viewport.
  Adjusts scroll_offset to bring the selected item into view.

  ## Parameters
    - state: The SelectList state

  ## Returns
    Updated state with adjusted scroll_offset if necessary
  """
  @spec ensure_visible(SelectList.t()) :: SelectList.t()
  def ensure_visible(state) do
    visible_items = state.visible_items || 10

    cond do
      state.selected_index < state.scroll_offset ->
        # Selected item is above visible area
        %{state | scroll_offset: state.selected_index}

      state.selected_index >= state.scroll_offset + visible_items ->
        # Selected item is below visible area
        %{state | scroll_offset: state.selected_index - visible_items + 1}

      true ->
        # Selected item is already visible
        state
    end
  end
end