defmodule Raxol.UI.Components.Input.Button do
  @moduledoc """
  Button component for interactive UI elements.

  This component provides a clickable button with customizable appearance and behavior.
  """

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.Core.Events.Event # REMOVE ALIAS

  @behaviour Component

  # Define valid roles
  @valid_roles [:default, :primary, :secondary, :danger, :success, nil]

  @type t :: %{
          id: String.t(),
          label: String.t(),
          on_click: function() | nil,
          disabled: boolean(),
          focused: boolean(),
          theme: map(),
          style: map(),
          width: integer() | nil,
          height: integer() | nil,
          shortcut: String.t() | nil,
          tooltip: String.t() | nil,
          # Added :default
          role: :default | :primary | :secondary | :danger | :success | nil,
          # Add errors field
          errors: map() | nil
        }

  @spec new(map()) :: t()
  @doc """
  Creates a new Button state map, applying defaults.
  Expects opts to be a Map.
  """
  def new(opts) when is_map(opts) do
    # Use Map.get for accessing options from the map
    id = Map.get(opts, :id, "button-#{System.unique_integer([:positive])}")
    label = Map.get(opts, :label, "Button")
    on_click = Map.get(opts, :on_click)
    disabled = Map.get(opts, :disabled, false)
    shortcut = Map.get(opts, :shortcut)
    tooltip = Map.get(opts, :tooltip)
    # Buttons are not focused by default
    focused = false
    # Default to empty map, actual theme applied by renderer
    theme = Map.get(opts, :theme, %{})
    # Default to empty map
    style = Map.get(opts, :style, %{})

    # Validate role
    role_from_opts = Map.get(opts, :role)
    is_role_valid? = role_from_opts in @valid_roles

    actual_role = if is_role_valid?, do: role_from_opts, else: :default

    role_errors =
      if is_role_valid? do
        %{}
      else
        %{
          role:
            "Invalid role: #{inspect(role_from_opts)}. Valid roles are #{inspect(@valid_roles)}"
        }
      end

    # Default width and height can be based on label length or other factors if needed
    # For now, let them be nil to be determined by layout or parent
    width = Map.get(opts, :width)
    height = Map.get(opts, :height)

    %{
      id: id,
      label: label,
      disabled: disabled,
      on_click: on_click,
      width: width,
      height: height,
      theme: theme,
      style: style,
      role: actual_role,
      errors: role_errors,
      focused: focused,
      shortcut: shortcut,
      tooltip: tooltip
    }
  end

  @doc """
  Initializes the Button component state from the given props.
  """
  @spec init(map()) :: {:ok, t()}
  @impl Component
  def init(state) do
    # Use Button.new to ensure defaults are applied from props
    initialized_state = new(state)
    {:ok, initialized_state}
  end

  @doc """
  Mounts the Button component. Performs any setup needed after initialization.
  """
  @spec mount(t()) :: t()
  @impl Component
  def mount(state), do: state

  @doc """
  Unmounts the Button component, performing any necessary cleanup.
  """
  @spec unmount(t()) :: t()
  @impl Component
  def unmount(state), do: state

  @doc """
  Updates the Button component state in response to messages or prop changes.
  """
  @spec update(t(), term()) :: {:noreply, t()}
  @impl Component
  def update(state, _message) do
    {:noreply, state}
  end

  @spec render(t(), map()) :: map()
  @doc """
  Renders the button component based on its current state.

  ## Parameters

  * `button` - The button component to render
  * `context` - The rendering context

  ## Returns

  A rendered view representation of the button.
  """
  @impl Component
  def render(button, context) do
    # Access component styles correctly from context.theme.component_styles
    component_styles = context.theme.component_styles || %{}
    button_theme_from_context = component_styles.button || %{}
    theme = Map.merge(button_theme_from_context, button.theme || %{})
    style = button.style || %{}

    # Determine colors based on state (including focus) and role
    {fg, bg} = resolve_colors(button, theme, style)

    button_width =
      button.width || min(String.length(button.label) + 4, context.max_width)

    button_height = button.height || 3

    # Add focus indicator to label if focused
    display_label =
      if button.focused, do: "> #{button.label} <", else: button.label

    %{
      type: :button,
      id: button.id,
      attrs: %{
        label: display_label,
        width: button_width,
        height: button_height,
        fg: fg,
        bg: bg,
        disabled: button.disabled,
        shortcut: button.shortcut,
        tooltip: button.tooltip,
        role: button.role,
        focused: button.focused
      },
      events: [
        Raxol.Core.Events.Event.new(:click, fn ->
          # Access on_click and disabled directly from the button state map
          if button.on_click && !button.disabled, do: button.on_click.()
        end)
      ]
    }
  end

  @spec handle_event(t(), any(), map()) ::
          {:update, t(), list()} | {:handled, t()} | :passthrough
  @doc """
  Handles input events for the button component.

  ## Parameters

  * `button` - The button component
  * `event` - The input event to handle
  * `context` - The event context

  ## Returns

  `{:update, updated_button}` if the button state changed,
  `{:handled, button}` if the event was handled but state didn't change,
  `:passthrough` if the event wasn't handled by the button.
  """
  @impl Component
  def handle_event(button, %Raxol.Core.Events.Event{type: :click}, _context) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()

      # Bubble an event indicating the button was pressed, using the :bubble command format
      {:update, button,
       [{:bubble, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
  end

  # Add this new clause to handle :mouse events as :click events
  def handle_event(
        button,
        %Raxol.Core.Events.Event{type: :mouse, data: %{button: :left}} =
          _mouse_event,
        context
      ) do
    # Delegate to the existing :click handler
    # We create a new event context for the :click, or pass the original context?
    # For now, assume the original context is fine. The button parameter for click handler is the button state.
    # The event for the click handler is just %Raxol.Core.Events.Event{type: :click}
    # The _context for click handler is not used currently.
    handle_event(button, %Raxol.Core.Events.Event{type: :click}, context)
  end

  def handle_event(
        button,
        %Raxol.Core.Events.Event{type: :focus, data: %{focused: focused}},
        _context
      ) do
    # Update the focused state
    updated_button = %{button | focused: focused}
    # Use {:update, state, commands} tuple
    {:update, updated_button, []}
  end

  def handle_event(
        button,
        %Raxol.Core.Events.Event{type: :keypress, data: %{key: key}},
        _context
      ) do
    if button.disabled or (key != :space and key != :enter) do
      :passthrough
    else
      # Execute the click handler if it exists
      if button.on_click, do: button.on_click.()
      # Consider adding :pressed state update here if needed
      # Return handled instead of :noreply
      {:handled, button}
    end
  end

  # Catch-all for unhandled events - Moved to the end
  def handle_event(_button, %Raxol.Core.Events.Event{} = _event, _context) do
    # By default, non-click events or buttons without actions don't change state.
    # Return :no_change to indicate the event was seen but no state update occurred.
    :no_change
  end

  # Private helpers

  defp resolve_colors(button_state, current_theme, current_style_prop) do
    # Determine actual base colors considering overrides
    # Style prop overrides theme prop for base fg/bg
    base_fg =
      Map.get(current_style_prop, :fg, Map.get(current_theme, :fg, :white))

    base_bg =
      Map.get(current_style_prop, :bg, Map.get(current_theme, :bg, :black))

    cond do
      button_state.disabled ->
        # Style prop's disabled colors take precedence, then theme's, then hardcoded.
        dfg =
          Map.get(
            current_style_prop,
            :disabled_fg,
            Map.get(current_theme, :disabled_fg, :dark_gray)
          )

        dbg =
          Map.get(
            current_style_prop,
            :disabled_bg,
            Map.get(current_theme, :disabled_bg, :gray)
          )

        {dfg, dbg}

      button_state.focused ->
        # Precedence for focused_fg:
        # 1. current_style_prop.focused_fg
        # 2. current_style_prop.fg
        # 3. current_theme.focused_fg
        # 4. Fallback to base_fg (which considers theme.fg and hardcoded defaults)

        # 1. Style's specific focused_fg
        # 2. Style's base fg
        # 3. Theme's specific focused_fg
        # 4. Fallback to already determined base_fg
        focused_fg =
          Map.get(current_style_prop, :focused_fg) ||
            Map.get(current_style_prop, :fg) ||
            Map.get(current_theme, :focused_fg) ||
            base_fg

        # 1. Style's specific focused_bg
        # 2. Style's base bg
        # 3. Theme's specific focused_bg
        # 4. Fallback to already determined base_bg
        focused_bg =
          Map.get(current_style_prop, :focused_bg) ||
            Map.get(current_style_prop, :bg) ||
            Map.get(current_theme, :focused_bg) ||
            base_bg

        {focused_fg, focused_bg}

      # Normal state
      true ->
        {base_fg, base_bg}
    end
  end
end
