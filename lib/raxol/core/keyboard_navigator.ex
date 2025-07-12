defmodule Raxol.Core.KeyboardNavigator do
  import Raxol.Guards

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
    ensure_keyword = fn
      kw when list?(kw) and (kw == [] or tuple?(hd(kw))) -> kw
      m when map?(m) -> Map.to_list(m)
      _ -> []
    end

    current_config = get_config()

    updated_config =
      Keyword.merge(ensure_keyword.(current_config), ensure_keyword.(opts))

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
    case event do
      {:key, key, modifiers} -> handle_key_event(key, modifiers)
      _ -> :unhandled
    end
  end

  defp handle_key_event(key, modifiers) do
    config = get_config()

    cond do
      navigation_key?(key, modifiers, config) -> handle_navigation(key, config)
      activation_key?(key, modifiers, config) -> handle_activation()
      dismiss_key?(key, modifiers, config) -> handle_dismiss()
      vim_key?(key, modifiers, config) -> handle_vim_navigation(key)
      function_key?(key, modifiers) -> handle_function_key(key)
      tab_key?(key, modifiers, config) -> handle_tab_navigation(key, config)
      true -> :unhandled
    end
  end

  defp navigation_key?(key, modifiers, config) do
    next_key = Keyword.get(config, :next_key)
    prev_key = Keyword.get(config, :previous_key)

    (key == next_key and modifiers == []) or
      (key == prev_key and modifiers == [:shift]) or
      (key in [:left, :right, :up, :down] and modifiers == [] and
         config[:group_navigation])
  end

  defp activation_key?(key, modifiers, config) do
    activate_keys = Keyword.get(config, :activate_keys)
    key in activate_keys and modifiers == []
  end

  defp dismiss_key?(key, modifiers, config) do
    dismiss_key = Keyword.get(config, :dismiss_key)

    (key == dismiss_key and modifiers == []) or
      (key == :escape and modifiers == [])
  end

  defp vim_key?(key, modifiers, config) do
    key in [:h, :j, :k, :l] and modifiers == [] and config[:vim_keys]
  end

  defp function_key?(key, modifiers) do
    key in [:f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8, :f9, :f10, :f11, :f12] and
      modifiers == []
  end

  defp tab_key?(key, _modifiers, config) do
    key == :tab and config[:tab_navigation]
  end

  defp handle_navigation(key, config) do
    case key do
      k when k in [:left, :right, :up, :down] ->
        handle_arrow_navigation(k)

      :tab ->
        navigate_in_group(
          if config[:previous_key] == :tab, do: :left, else: :right
        )

      _ ->
        navigate_in_group(:right)
    end

    :handled
  end

  defp handle_tab_navigation(key, _config) do
    direction = if key == :tab, do: :right, else: :left
    navigate_in_group(direction)
    :handled
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
  def register_shortcut(key, modifiers, handler) when function?(handler, 0) do
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
      try_explicit_navigation(key) -> :ok
      config[:spatial_navigation] && try_spatial_navigation(key) -> :ok
      config[:group_navigation] -> handle_group_navigation(key)
      true -> handle_simple_navigation(key)
    end
  end

  defp handle_group_navigation(key) do
    case key do
      :down -> navigate_in_group(:down)
      :up -> navigate_in_group(:up)
      :right -> navigate_in_group(:right)
      :left -> navigate_in_group(:left)
    end
  end

  defp handle_simple_navigation(key) do
    case key do
      :down -> FocusManager.focus_next()
      :up -> FocusManager.focus_previous()
      :right -> FocusManager.focus_next()
      :left -> FocusManager.focus_previous()
    end
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

      handler when function?(handler, 0) ->
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
