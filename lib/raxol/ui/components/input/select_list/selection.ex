defmodule Raxol.UI.Components.Input.SelectList.Selection do
  @moduledoc """
  Handles selection functionality for the SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList.Pagination

  @doc """
  Updates selection state based on a selected index.
  Returns updated state and any commands to execute.
  """
  def handle_select(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    handle_selection_by_options_count(
      num_options == 0,
      state,
      effective_options
    )
  end

  @doc """
  Generates commands based on selection callbacks.
  """
  def generate_selection_commands(state, value) do
    commands = []

    # Add on_select callback if provided and is a function
    commands =
      case Map.get(state, :on_select) do
        fun when is_function(fun, 1) -> [{:callback, fun, [value]} | commands]
        _ -> commands
      end

    # Add on_change callback if provided and is a function
    commands =
      case Map.get(state, :on_change) do
        fun when is_function(fun, 1) -> [{:callback, fun, [value]} | commands]
        _ -> commands
      end

    commands
  end

  # Pattern matching helpers to eliminate if statements
  defp handle_selection_by_options_count(true, state, _effective_options) do
    {state, []}
  end

  defp handle_selection_by_options_count(false, state, effective_options) do
    # Get the selected option
    {_label, value} = Enum.at(effective_options, state.focused_index)

    # Update selection state
    updated_indices = handle_multiple_selection(state.multiple, state)

    # Update state
    updated_state = %{state | selected_indices: updated_indices}

    # Generate commands based on callbacks
    commands = generate_selection_commands(updated_state, value)

    {updated_state, commands}
  end

  defp handle_multiple_selection(true, state) do
    # Toggle selection for multiple select
    toggle_selection_membership(
      MapSet.member?(state.selected_indices, state.focused_index),
      state
    )
  end

  defp handle_multiple_selection(false, state) do
    # Single selection - replace with just this index
    MapSet.new([state.focused_index])
  end

  defp toggle_selection_membership(true, state) do
    MapSet.delete(state.selected_indices, state.focused_index)
  end

  defp toggle_selection_membership(false, state) do
    MapSet.put(state.selected_indices, state.focused_index)
  end

  defp handle_index_selection(true, state, effective_options, index) do
    # Get the selected option
    {_label, value} = Enum.at(effective_options, index)

    # Update selection state
    updated_indices = MapSet.new([index])

    # Update state, also set focused_index to index
    updated_state = %{
      state
      | selected_indices: updated_indices,
        focused_index: index
    }

    # Generate commands based on callbacks
    commands = generate_selection_commands(updated_state, value)

    {updated_state, commands}
  end

  defp handle_index_selection(false, state, _effective_options, _index) do
    {state, []}
  end

  @doc """
  Updates selection state for a specific index.
  """
  def update_selection_state(state, index) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    handle_index_selection(
      index >= 0 and index < num_options,
      state,
      effective_options,
      index
    )
  end
end
