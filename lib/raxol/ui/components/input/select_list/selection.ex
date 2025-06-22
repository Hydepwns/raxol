defmodule Raxol.UI.Components.Input.SelectList.Selection do
  @moduledoc """
  Handles selection functionality for the SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList.Pagination
  import Raxol.Guards

  @doc """
  Updates selection state based on a selected index.
  Returns updated state and any commands to execute.
  """
  def handle_select(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      {state, []}
    else
      # Get the selected option
      {_label, value} = Enum.at(effective_options, state.focused_index)

      # Update selection state
      updated_indices =
        if state.multiple do
          # Toggle selection for multiple select
          if MapSet.member?(state.selected_indices, state.focused_index) do
            MapSet.delete(state.selected_indices, state.focused_index)
          else
            MapSet.put(state.selected_indices, state.focused_index)
          end
        else
          # Single selection - replace with just this index
          MapSet.new([state.focused_index])
        end

      # Update state
      updated_state = %{state | selected_indices: updated_indices}

      # Generate commands based on callbacks
      commands = generate_selection_commands(updated_state, value)

      {updated_state, commands}
    end
  end

  @doc """
  Generates commands based on selection callbacks.
  """
  def generate_selection_commands(state, value) do
    commands = []

    # Add on_select callback if provided and is a function
    commands =
      case Map.get(state, :on_select) do
        fun when function?(fun, 1) -> [{:callback, fun, [value]} | commands]
        _ -> commands
      end

    # Add on_change callback if provided and is a function
    commands =
      case Map.get(state, :on_change) do
        fun when function?(fun, 1) -> [{:callback, fun, [value]} | commands]
        _ -> commands
      end

    commands
  end

  @doc """
  Updates selection state for a specific index.
  """
  def update_selection_state(state, index) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if index >= 0 and index < num_options do
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
    else
      {state, []}
    end
  end
end
