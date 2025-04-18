defmodule Raxol.Core.KeyboardNavigator do
  @moduledoc """
  Keyboard navigation handler for Raxol terminal UI applications.

  This module integrates with the FocusManager to provide keyboard navigation between
  interactive components using standard key bindings:

  - Tab: Move to next focusable element
  - Shift+Tab: Move to previous focusable element
  - Arrow keys: Navigate between elements in a component group
  - Escape: Return to previous focus or dismiss dialogs
  - Enter/Space: Activate currently focused element

  ## Usage

  ```elixir
  # Initialize keyboard navigation in your application
  KeyboardNavigator.init()

  # Customize keybindings
  KeyboardNavigator.configure(next_key: :right, previous_key: :left)
  ```
  """

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.FocusManager

  @doc """
  Initialize the keyboard navigator.

  This registers event handlers for keyboard navigation.

  ## Examples

      iex> KeyboardNavigator.init()
      :ok
  """
  def init do
    EventManager.register_handler(:keyboard, __MODULE__, :handle_keyboard_event)
    Process.put(:keyboard_navigator_config, default_config())
    Process.put(:keyboard_navigator_spatial_map, %{})
    :ok
  end

  @doc """
  Configure keyboard navigation behavior.

  ## Options

  * `:next_key` - Key to move to next element (default: `:tab`)
  * `:previous_key` - Key to move to previous element (default: `:tab` with shift)
  * `:activate_keys` - Keys to activate elements (default: `[:enter, :space]`)
  * `:dismiss_key` - Key to dismiss or go back (default: `:escape`)
  * `:arrow_navigation` - Enable arrow key navigation (default: `true`)
  * `:vim_keys` - Enable vim-style navigation with h,j,k,l (default: `false`)
  * `:group_navigation` - Enable group-based navigation (default: `true`)
  * `:spatial_navigation` - Enable spatial navigation for grid layouts (default: `false`)
  * `:tab_navigation` - Enable tab-based navigation (default: `true`)

  ## Examples

      iex> KeyboardNavigator.configure(vim_keys: true)
      :ok
  """
  def configure(opts \\ []) do
    current_config = get_config()
    updated_config = Keyword.merge(current_config, opts)
    Process.put(:keyboard_navigator_config, updated_config)
    :ok
  end

  @doc """
  Register component positions for spatial navigation.

  This allows arrow keys to navigate components based on their physical layout.

  ## Parameters

  * `component_id` - Unique identifier for the component
  * `x` - X coordinate
  * `y` - Y coordinate
  * `width` - Width of the component
  * `height` - Height of the component

  ## Examples

      iex> KeyboardNavigator.register_component_position("search_input", 10, 5, 30, 3)
      :ok
  """
  def register_component_position(component_id, x, y, width, height) do
    spatial_map = get_spatial_map()

    updated_map =
      Map.put(spatial_map, component_id, %{
        id: component_id,
        x: x,
        y: y,
        width: width,
        height: height,
        center_x: x + div(width, 2),
        center_y: y + div(height, 2)
      })

    Process.put(:keyboard_navigator_spatial_map, updated_map)
    :ok
  end

  @doc """
  Define explicit navigation paths between components.

  This allows customizing navigation beyond spatial or tab order.

  ## Parameters

  * `from_id` - Component ID to navigate from
  * `direction` - Navigation direction (`:up`, `:down`, `:left`, `:right`)
  * `to_id` - Component ID to navigate to

  ## Examples

      iex> KeyboardNavigator.define_navigation_path("search_input", :down, "submit_button")
      :ok
  """
  def define_navigation_path(from_id, direction, to_id) do
    nav_paths = Process.get(:keyboard_navigator_paths) || %{}

    from_paths = Map.get(nav_paths, from_id, %{})
    updated_from_paths = Map.put(from_paths, direction, to_id)

    updated_paths = Map.put(nav_paths, from_id, updated_from_paths)
    Process.put(:keyboard_navigator_paths, updated_paths)
    :ok
  end

  @doc """
  Handle keyboard events for navigation.

  This function is called by the EventManager when keyboard events occur.

  ## Parameters

  * `event` - The keyboard event to handle

  ## Returns

  * `:handled` - If the event was handled by the navigator
  * `:unhandled` - If the event was not handled
  """
  def handle_keyboard_event(event) do
    config = get_config()

    case event do
      {:key, key, modifiers} ->
        next_key = Access.get(config, :next_key)
        prev_key = Access.get(config, :previous_key)
        activate_keys = Access.get(config, :activate_keys)
        dismiss_key = Access.get(config, :dismiss_key)

        cond do
          key == next_key and modifiers == [] ->
            navigate_in_group(:right)
            :handled

          key == prev_key and modifiers == [:shift] ->
            navigate_in_group(:left)
            :handled

          key in activate_keys and modifiers == [] ->
            handle_activation()
            :handled

          key == dismiss_key and modifiers == [] ->
            handle_dismiss()
            :handled

          key == :escape and modifiers == [] ->
            handle_dismiss()
            :handled

          key in [:left, :right, :up, :down] and modifiers == [] ->
            if config[:group_navigation] do
              navigate_in_group(key)
              :handled
            else
              :unhandled
            end

          key in [:h, :j, :k, :l] and modifiers == [] ->
            if config[:vim_keys] do
              handle_vim_navigation(key)
              :handled
            else
              :unhandled
            end

          key in [:f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8, :f9, :f10, :f11, :f12] and
              modifiers == [] ->
            handle_function_key(key)
            :handled

          key == :tab and modifiers == [] ->
            if config[:tab_navigation] do
              navigate_in_group(:right)
              :handled
            else
              :unhandled
            end

          key == :tab and modifiers == [:shift] ->
            if config[:tab_navigation] do
              navigate_in_group(:left)
              :handled
            else
              :unhandled
            end

          true ->
            :unhandled
        end

      # Unhandled keyboard event
      _ ->
        :unhandled
    end
  end

  @doc """
  Register a custom shortcut handler.

  ## Parameters

  * `key` - The key to handle
  * `modifiers` - List of modifier keys (e.g., [:ctrl, :shift])
  * `handler` - Function to call when shortcut is pressed

  ## Examples

      iex> KeyboardNavigator.register_shortcut(:f1, [], &show_help/0)
      :ok
  """
  def register_shortcut(key, modifiers, handler) when is_function(handler, 0) do
    shortcuts = Process.get(:keyboard_navigator_shortcuts) || %{}
    shortcut_key = {key, modifiers}
    updated_shortcuts = Map.put(shortcuts, shortcut_key, handler)
    Process.put(:keyboard_navigator_shortcuts, updated_shortcuts)
    :ok
  end

  # Private functions

  defp get_config do
    Process.get(:keyboard_navigator_config) || default_config()
  end

  defp get_spatial_map do
    Process.get(:keyboard_navigator_spatial_map) || %{}
  end

  defp default_config do
    [
      next_key: :tab,
      previous_key: :tab,
      activate_keys: [:enter, :space],
      dismiss_key: :escape,
      arrow_navigation: true,
      vim_keys: false,
      group_navigation: true,
      spatial_navigation: false,
      wrap_navigation: true,
      tab_navigation: true
    ]
  end

  defp handle_activation do
    # Get the currently focused element
    focused_element = FocusManager.get_focused_element()

    if focused_element do
      # Dispatch an activation event for the focused element
      EventManager.dispatch({:activate, focused_element})
    end

    :ok
  end

  defp handle_dismiss do
    # Check if there's an active dialog to dismiss first
    if dismiss_active_dialog() do
      :ok
    else
      # If no dialog was dismissed, return to previous focus
      FocusManager.return_to_previous()
    end
  end

  defp dismiss_active_dialog do
    # Check if there's an active dialog
    # This is a placeholder for actual dialog management
    case Process.get(:active_dialog) do
      nil ->
        false

      dialog_id ->
        # Dispatch dialog dismiss event
        EventManager.dispatch({:dismiss_dialog, dialog_id})
        Process.delete(:active_dialog)
        true
    end
  end

  defp handle_arrow_navigation(key) do
    config = get_config()

    cond do
      # Explicit navigation paths have highest priority
      try_explicit_navigation(key) ->
        :ok

      # Spatial navigation has second priority if enabled
      config[:spatial_navigation] && try_spatial_navigation(key) ->
        :ok

      # Group navigation has third priority if enabled
      config[:group_navigation] ->
        # Handle arrow keys for group-based navigation
        case key do
          :down -> navigate_in_group(:down)
          :up -> navigate_in_group(:up)
          :right -> navigate_in_group(:right)
          :left -> navigate_in_group(:left)
        end

      # Simple navigation as fallback
      true ->
        # Simple arrow key handling when other navigation modes are disabled
        case key do
          :down -> FocusManager.focus_next()
          :up -> FocusManager.focus_previous()
          :right -> FocusManager.focus_next()
          :left -> FocusManager.focus_previous()
        end
    end

    :ok
  end

  defp try_explicit_navigation(direction) do
    current_focus = FocusManager.get_focused_element()
    if !current_focus, do: false

    nav_paths = Process.get(:keyboard_navigator_paths) || %{}
    from_paths = Map.get(nav_paths, current_focus, %{})

    case Map.get(from_paths, direction) do
      nil ->
        false

      target_id ->
        FocusManager.set_focus(target_id)
        true
    end
  end

  defp try_spatial_navigation(direction) do
    current_focus = FocusManager.get_focused_element()
    if !current_focus, do: false

    spatial_map = get_spatial_map()
    current_pos = Map.get(spatial_map, current_focus)
    if !current_pos, do: false

    # Find the closest component in the specified direction
    target_id = find_closest_in_direction(current_pos, direction, spatial_map)

    if target_id do
      FocusManager.set_focus(target_id)
      true
    else
      false
    end
  end

  defp find_closest_in_direction(current_pos, direction, spatial_map) do
    # Filter components in the correct direction
    candidates =
      spatial_map
      |> Map.values()
      |> Enum.filter(fn pos ->
        pos.id != current_pos.id &&
          in_direction?(current_pos, pos, direction)
      end)

    # Find the closest one
    if length(candidates) > 0 do
      candidates
      |> Enum.sort_by(fn pos ->
        distance_in_direction(current_pos, pos, direction)
      end)
      |> hd()
      |> Map.get(:id)
    else
      nil
    end
  end

  defp in_direction?(from, to, direction) do
    case direction do
      :up -> to.center_y < from.center_y
      :down -> to.center_y > from.center_y
      :left -> to.center_x < from.center_x
      :right -> to.center_x > from.center_x
    end
  end

  # For backward compatibility
  @doc false
  @deprecated "Use in_direction?/3 instead"
  defp is_in_direction?(from, to, direction), do: in_direction?(from, to, direction)

  defp distance_in_direction(from, to, direction) do
    # Calculate a weighted distance that prioritizes alignment
    case direction do
      dir when dir in [:up, :down] ->
        # Vertical direction: x-alignment is more important
        vertical_dist = abs(to.center_y - from.center_y)
        horizontal_penalty = abs(to.center_x - from.center_x) * 2
        vertical_dist + horizontal_penalty

      dir when dir in [:left, :right] ->
        # Horizontal direction: y-alignment is more important
        horizontal_dist = abs(to.center_x - from.center_x)
        vertical_penalty = abs(to.center_y - from.center_y) * 2
        horizontal_dist + vertical_penalty
    end
  end

  defp handle_vim_navigation(key) do
    # Map vim keys to arrow keys
    arrow_key =
      case key do
        :h -> :left
        :j -> :down
        :k -> :up
        :l -> :right
      end

    handle_arrow_navigation(arrow_key)
  end

  defp handle_function_key(key) do
    shortcuts = Process.get(:keyboard_navigator_shortcuts) || %{}
    shortcut_key = {key, []}

    case Map.get(shortcuts, shortcut_key) do
      nil ->
        :unhandled

      handler when is_function(handler, 0) ->
        handler.()
        :handled
    end
  end

  defp navigate_in_group(direction) do
    # Navigation within a focus group
    case direction do
      :down -> FocusManager.focus_next(group: current_group())
      :up -> FocusManager.focus_previous(group: current_group())
      :right -> FocusManager.focus_next(group: current_group())
      :left -> FocusManager.focus_previous(group: current_group())
    end
  end

  defp current_group do
    # Get the current focus group from the FocusManager state
    focus_state = Process.get(:focus_manager_state) || %{}
    focus_state[:last_group] || :default
  end
end
