defmodule Raxol.Core.FocusManager do
  @moduledoc """
  Focus management system for Raxol terminal UI applications.

  This module provides utilities for managing focus between interactive components:
  - Tab-based keyboard navigation
  - Focus history tracking
  - Focus ring rendering
  - Screen reader announcements

  ## Usage

  ```elixir
  # Register focusable components in your view
  FocusManager.register_focusable("search_input", 1)
  FocusManager.register_focusable("submit_button", 2)

  # Initialize the focus manager with the first focusable element
  FocusManager.set_initial_focus("search_input")
  ```
  """

  alias Raxol.Core.Events.Manager, as: EventManager

  @doc """
  Register a focusable component with the focus manager.

  ## Parameters

  * `component_id` - Unique identifier for the component
  * `tab_index` - Tab order index (lower numbers are focused first)
  * `opts` - Additional options

  ## Options

  * `:group` - Focus group name for grouped navigation (default: `:default`)
  * `:disabled` - Whether the component is initially disabled (default: `false`)
  * `:announce` - Announcement text for screen readers when focused (default: `nil`)

  ## Examples

      iex> FocusManager.register_focusable("search_input", 1)
      :ok

      iex> FocusManager.register_focusable("submit_button", 2, group: :form_actions)
      :ok
  """
  def register_focusable(component_id, tab_index, opts \\ []) do
    group = Keyword.get(opts, :group, :default)
    disabled = Keyword.get(opts, :disabled, false)
    announce = Keyword.get(opts, :announce, nil)

    focusables = get_focusables()

    focusable = %{
      id: component_id,
      tab_index: tab_index,
      group: group,
      disabled: disabled,
      announce: announce
    }

    updated_focusables =
      Map.update(
        focusables,
        group,
        [focusable],
        fn existing -> [focusable | existing] |> sort_by_tab_index() end
      )

    Process.put(:focus_manager_focusables, updated_focusables)
    :ok
  end

  @doc """
  Unregister a focusable component.

  ## Examples

      iex> FocusManager.unregister_focusable("search_input")
      :ok
  """
  def unregister_focusable(component_id) do
    focusables = get_focusables()

    updated_focusables =
      focusables
      |> Enum.map(fn {group, components} ->
        updated_components =
          Enum.reject(components, fn c -> c.id == component_id end)

        {group, updated_components}
      end)
      |> Enum.into(%{})

    Process.put(:focus_manager_focusables, updated_focusables)
    :ok
  end

  @doc """
  Set the initial focus to a specific component.

  ## Examples

      iex> FocusManager.set_initial_focus("search_input")
      :ok
  """
  def set_initial_focus(component_id) do
    focus_state = get_focus_state()

    if not is_map_key(focus_state, :active_element) ||
         focus_state.active_element != component_id do
      set_focus(component_id)
    else
      :ok
    end
  end

  @doc """
  Set focus to a specific component.

  ## Examples

      iex> FocusManager.set_focus("submit_button")
      :ok
  """
  def set_focus(component_id) do
    focus_state = get_focus_state()
    old_focus = focus_state[:active_element]

    # Only update if focus is changing
    if old_focus != component_id do
      # Find the component
      focusables = get_focusables()
      component = find_component(focusables, component_id)

      if component do
        # Update focus history
        history = focus_state[:focus_history] || []
        updated_history = [old_focus | history] |> Enum.take(10)

        # Update focus state
        updated_focus_state = %{
          active_element: component_id,
          focus_history: updated_history,
          last_group: component.group
        }

        Process.put(:focus_manager_state, updated_focus_state)

        # Send focus change event
        EventManager.dispatch({:focus_change, old_focus, component_id})

        # Announce focus change if configured
        if component.announce do
          announce_focus_change(component.announce)
        end
      end
    end

    :ok
  end

  @doc """
  Move focus to the next focusable element.

  ## Options

  * `:group` - Only navigate within this group (default: `nil` - use current group)
  * `:wrap` - Wrap around to first element when at the end (default: `true`)

  ## Examples

      iex> FocusManager.focus_next()
      :ok

      iex> FocusManager.focus_next(group: :form_actions)
      :ok
  """
  def focus_next(opts \\ []) do
    focus_state = get_focus_state()
    current_focus = focus_state[:active_element]

    if current_focus do
      group_opt = Keyword.get(opts, :group, nil)
      wrap = Keyword.get(opts, :wrap, true)

      # Determine the group to navigate within
      group =
        cond do
          group_opt != nil -> group_opt
          focus_state[:last_group] != nil -> focus_state[:last_group]
          true -> :default
        end

      focusables = get_focusables()
      group_components = Map.get(focusables, group, [])

      # Find the current component in the group
      current_component =
        Enum.find(group_components, fn c -> c.id == current_focus end)

      current_index =
        if current_component do
          Enum.find_index(group_components, fn c -> c.id == current_focus end)
        else
          -1
        end

      # Find the next enabled component
      next_component =
        find_next_enabled_component(group_components, current_index, wrap)

      if next_component do
        set_focus(next_component.id)
      end
    end

    :ok
  end

  @doc """
  Move focus to the previous focusable element.

  ## Options

  * `:group` - Only navigate within this group (default: `nil` - use current group)
  * `:wrap` - Wrap around to last element when at the beginning (default: `true`)

  ## Examples

      iex> FocusManager.focus_previous()
      :ok
  """
  def focus_previous(opts \\ []) do
    focus_state = get_focus_state()
    current_focus = focus_state[:active_element]

    if current_focus do
      group_opt = Keyword.get(opts, :group, nil)
      wrap = Keyword.get(opts, :wrap, true)

      # Determine the group to navigate within
      group =
        cond do
          group_opt != nil -> group_opt
          focus_state[:last_group] != nil -> focus_state[:last_group]
          true -> :default
        end

      focusables = get_focusables()
      group_components = Map.get(focusables, group, [])

      # Find the current component in the group
      current_component =
        Enum.find(group_components, fn c -> c.id == current_focus end)

      current_index =
        if current_component do
          Enum.find_index(group_components, fn c -> c.id == current_focus end)
        else
          -1
        end

      # Find the previous enabled component
      prev_component =
        find_prev_enabled_component(group_components, current_index, wrap)

      if prev_component do
        set_focus(prev_component.id)
      end
    end

    :ok
  end

  @doc """
  Get the ID of the currently focused element.

  ## Examples

      iex> FocusManager.set_initial_focus("my_button")
      iex> FocusManager.get_focused_element()
      "my_button"
  """
  def get_focused_element do
    get_focus_state()[:active_element]
  end

  @doc """
  Alias for get_focused_element/0.
  """
  @spec get_current_focus() :: String.t() | nil
  def get_current_focus() do
    get_focused_element()
  end

  @doc """
  Get the next focusable element after the given one.
  (Placeholder implementation - mirrors focus_next logic)
  """
  @spec get_next_focusable(String.t() | nil) :: String.t() | nil
  def get_next_focusable(current_focus_id) do
    focus_state = get_focus_state()

    # Determine the group to navigate within (use default if needed)
    group = focus_state[:last_group] || :default

    focusables = get_focusables()
    group_components = Map.get(focusables, group, [])

    # Find the index of the current component
    current_index =
      if current_focus_id do
        Enum.find_index(group_components, fn c -> c.id == current_focus_id end) ||
          -1
      else
        # Start from beginning if current_focus_id is nil
        -1
      end

    # Find the next enabled component (wrapping)
    next_component =
      find_next_enabled_component(group_components, current_index, true)

    if next_component do
      next_component.id
    else
      nil
    end
  end

  @doc """
  Get the previous focusable element before the given one.
  Mirrors the logic of `get_next_focusable/1` but searches backwards.
  """
  @spec get_previous_focusable(String.t() | nil) :: String.t() | nil
  def get_previous_focusable(current_focus_id) do
    focus_state = get_focus_state()

    # Determine the group to navigate within (use default if needed)
    group = focus_state[:last_group] || :default

    focusables = get_focusables()
    group_components = Map.get(focusables, group, [])

    # Find the index of the current component
    current_index =
      if current_focus_id do
        Enum.find_index(group_components, fn c -> c.id == current_focus_id end) ||
          -1
      else
        # Start from end if current_focus_id is nil (or not found)
        # Use length to indicate starting search from the wrap-around point
        length(group_components)
      end

    # Find the previous enabled component (wrapping)
    prev_component =
      find_prev_enabled_component(group_components, current_index, true)

    if prev_component do
      prev_component.id
    else
      nil
    end
  end

  @doc """
  Check if a component has focus.

  ## Examples

      iex> FocusManager.has_focus?("search_input")
      true
  """
  def has_focus?(component_id) do
    get_focused_element() == component_id
  end

  @doc """
  Return to the previously focused element.

  ## Examples

      iex> FocusManager.return_to_previous()
      :ok
  """
  def return_to_previous do
    focus_state = get_focus_state()
    history = focus_state[:focus_history] || []

    case history do
      [prev | rest] when is_binary(prev) ->
        # Update focus state
        updated_focus_state = %{
          active_element: prev,
          focus_history: rest,
          last_group: focus_state[:last_group]
        }

        Process.put(:focus_manager_state, updated_focus_state)

        # Send focus change event
        EventManager.dispatch(
          {:focus_change, focus_state[:active_element], prev}
        )

        # Announce focus change if configured
        component = find_component_by_id(prev)

        if component && component.announce do
          announce_focus_change(component.announce)
        end

      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Enable a previously disabled focusable component.

  ## Examples

      iex> FocusManager.enable_component("submit_button")
      :ok
  """
  def enable_component(component_id) do
    update_component_state(component_id, :disabled, false)
  end

  @doc """
  Disable a focusable component, preventing it from receiving focus.

  ## Examples

      iex> FocusManager.disable_component("submit_button")
      :ok
  """
  def disable_component(component_id) do
    update_component_state(component_id, :disabled, true)

    # If this component is currently focused, move focus elsewhere
    if has_focus?(component_id) do
      focus_next()
    end

    :ok
  end

  @doc """
  Register a handler function to be called when focus changes.

  The handler function should accept two arguments: `old_focus` and `new_focus`.
  (Placeholder implementation)
  """
  @spec register_focus_change_handler(fun()) :: :ok
  def register_focus_change_handler(handler_fun)
      when is_function(handler_fun, 2) do
    handlers = Process.get(:focus_manager_change_handlers, [])
    updated_handlers = [handler_fun | handlers]
    Process.put(:focus_manager_change_handlers, updated_handlers)
    :ok
  end

  @doc """
  Unregister a focus change handler function.
  (Placeholder implementation)
  """
  @spec unregister_focus_change_handler(fun()) :: :ok
  def unregister_focus_change_handler(handler_fun)
      when is_function(handler_fun, 2) do
    handlers = Process.get(:focus_manager_change_handlers, [])
    updated_handlers = List.delete(handlers, handler_fun)
    Process.put(:focus_manager_change_handlers, updated_handlers)
    :ok
  end

  # Private functions

  defp get_focusables do
    Process.get(:focus_manager_focusables) || %{}
  end

  defp get_focus_state do
    Process.get(:focus_manager_state) || %{}
  end

  defp sort_by_tab_index(components) do
    Enum.sort_by(components, & &1.tab_index)
  end

  defp find_component(focusables, component_id) do
    focusables
    |> Map.values()
    |> List.flatten()
    |> Enum.find(fn c -> c.id == component_id end)
  end

  defp find_component_by_id(component_id) do
    focusables = get_focusables()
    find_component(focusables, component_id)
  end

  defp find_next_enabled_component(components, current_index, wrap) do
    component_count = length(components)

    if component_count == 0 do
      nil
    else
      # Start searching from the next index
      start_index = rem(current_index + 1, component_count)

      # Search for the next enabled component
      find_enabled_component_from_index(
        components,
        start_index,
        1,
        component_count,
        wrap
      )
    end
  end

  defp find_prev_enabled_component(components, current_index, wrap) do
    component_count = length(components)

    if component_count == 0 do
      nil
    else
      # Start searching from the previous index
      start_index =
        if current_index <= 0 do
          if wrap, do: component_count - 1, else: -1
        else
          current_index - 1
        end

      # Search for the previous enabled component
      find_enabled_component_from_index(
        components,
        start_index,
        -1,
        component_count,
        wrap
      )
    end
  end

  defp find_enabled_component_from_index(
         components,
         start_index,
         step,
         count,
         wrap
       ) do
    # Early return for invalid indices
    if start_index < 0 || start_index >= count do
      nil
    else
      # Check up to count elements
      Enum.reduce_while(0..(count - 1), nil, fn i, _acc ->
        index = rem(start_index + i * step + count, count)
        component = Enum.at(components, index)

        cond do
          # Found an enabled component
          component && !component.disabled ->
            {:halt, component}

          # Reached the boundary and no wrapping
          (i == count - 1 && !wrap) || i == count - 1 ->
            {:halt, nil}

          # Continue searching
          true ->
            {:cont, nil}
        end
      end)
    end
  end

  defp update_component_state(component_id, field, value) do
    focusables = get_focusables()

    updated_focusables =
      focusables
      |> Enum.map(fn {group, components} ->
        updated_components =
          Enum.map(components, fn component ->
            if component.id == component_id do
              Map.put(component, field, value)
            else
              component
            end
          end)

        {group, updated_components}
      end)
      |> Enum.into(%{})

    Process.put(:focus_manager_focusables, updated_focusables)
    :ok
  end

  defp announce_focus_change(message) do
    # Send to accessibility announcement system
    # This is a placeholder for the actual implementation
    EventManager.dispatch({:accessibility_announce, message})
    :ok
  end
end
