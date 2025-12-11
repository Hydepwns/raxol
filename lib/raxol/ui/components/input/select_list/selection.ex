defmodule Raxol.UI.Components.Input.SelectList.Selection do
  @moduledoc """
  Selection management for SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList
  alias Raxol.UI.Components.Input.SelectList.Utils

  @doc """
  Updates the selection state with a new index.
  """
  @spec update_selection_state(SelectList.t(), non_neg_integer()) ::
          {SelectList.t(), list()}
  def update_selection_state(state, index) do
    effective_options = get_effective_options(state)
    max_index = length(effective_options) - 1

    # Clamp index to valid range
    new_index = min(max(index, 0), max_index)

    new_state =
      if Map.get(state, :multiple, false) do
        # Multiple selection: toggle the index in selected_indices
        current_indices = state.selected_indices || MapSet.new()

        updated_indices =
          if MapSet.member?(current_indices, new_index) do
            MapSet.delete(current_indices, new_index)
          else
            MapSet.put(current_indices, new_index)
          end

        %{state | selected_indices: updated_indices, focused_index: new_index}
        |> ensure_visible()
      else
        # Single selection: update selected_index
        updated_state = %{
          state
          | selected_index: new_index,
            focused_index: new_index
        }

        ensure_visible(updated_state)
      end

    # Generate callback commands if applicable
    commands = generate_selection_commands(state, new_state, index)

    {new_state, commands}
  end

  @doc """
  Gets the currently selected option.
  """
  @spec get_selected_option(SelectList.t()) :: any() | nil
  def get_selected_option(state) do
    effective_options = get_effective_options(state)
    Enum.at(effective_options, state.selected_index)
  end

  @doc """
  Gets the value of the currently selected option.
  """
  @spec get_selected_value(SelectList.t()) :: any() | nil
  def get_selected_value(state) do
    case get_selected_option(state) do
      nil -> nil
      {_label, value} -> value
      %{value: value} -> value
      option -> option
    end
  end

  @doc """
  Selects an option by its value.
  """
  @spec select_by_value(SelectList.t(), any()) :: {SelectList.t(), list()}
  def select_by_value(state, target_value) do
    effective_options = get_effective_options(state)

    index =
      Enum.find_index(effective_options, fn option ->
        get_option_value(option) == target_value
      end)

    case index do
      nil -> {state, []}
      idx -> update_selection_state(state, idx)
    end
  end

  @doc """
  Checks if an index is the selected one.
  """
  @spec selected?(SelectList.t(), non_neg_integer()) :: boolean()
  def selected?(state, index) do
    if Map.get(state, :multiple, false) do
      current_indices = state.selected_indices || MapSet.new()
      MapSet.member?(current_indices, index)
    else
      state.selected_index == index
    end
  end

  @doc """
  Moves selection up by one.
  """
  @spec move_up(SelectList.t()) :: {SelectList.t(), list()}
  def move_up(state) do
    update_selection_state(state, state.selected_index - 1)
  end

  @doc """
  Moves selection down by one.
  """
  @spec move_down(SelectList.t()) :: {SelectList.t(), list()}
  def move_down(state) do
    update_selection_state(state, state.selected_index + 1)
  end

  @doc """
  Moves selection to the first item.
  """
  @spec select_first(SelectList.t()) :: {SelectList.t(), list()}
  def select_first(state) do
    update_selection_state(state, 0)
  end

  @doc """
  Moves selection to the last item.
  """
  @spec select_last(SelectList.t()) :: {SelectList.t(), list()}
  def select_last(state) do
    effective_options = get_effective_options(state)
    last_index = length(effective_options) - 1
    update_selection_state(state, last_index)
  end

  # Private functions

  defp get_effective_options(state) do
    case state.filtered_options do
      nil -> state.options
      filtered -> filtered
    end
  end

  defp ensure_visible(state) do
    Utils.ensure_visible(state)
  end

  defp get_option_value(option)
       when is_tuple(option) and tuple_size(option) == 2 do
    elem(option, 1)
  end

  defp get_option_value(%{value: value}), do: value
  defp get_option_value(option), do: option

  defp generate_selection_commands(state, new_state, _index) do
    commands = []

    # Add on_select callback if present
    commands =
      case Map.get(state, :on_select) do
        nil ->
          commands

        callback when is_function(callback) ->
          selected_value = get_selected_value(new_state)
          [{:callback, callback, [selected_value]} | commands]
      end

    # Add on_change callback if present
    commands =
      case Map.get(state, :on_change) do
        nil ->
          commands

        callback when is_function(callback) ->
          [{:callback, callback, [new_state]} | commands]
      end

    commands
  end
end
