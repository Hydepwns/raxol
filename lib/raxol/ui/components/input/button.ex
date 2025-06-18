defmodule Raxol.UI.Components.Input.Button do
  @moduledoc '''
  Button component for interactive UI elements.

  This component provides a clickable button with customizable appearance and behavior.
  '''

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.Core.Events.Event # REMOVE ALIAS

  @behaviour Component

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
          role: :primary | :secondary | :danger | :success | nil
        }

  @spec new(map()) :: t()
  @doc '''
  Creates a new Button state map, applying defaults.
  Expects opts to be a Map.
  '''
  def new(opts) when is_map(opts) do
    # Use Map.get for accessing options from the map
    id = Map.get(opts, :id, "button-#{System.unique_integer([:positive])}")
    label = Map.get(opts, :label, "Button")
    disabled = Map.get(opts, :disabled, false)
    on_click = Map.get(opts, :on_click)
    width = Map.get(opts, :width)
    height = Map.get(opts, :height)
    theme = Map.get(opts, :theme, %{})
    style = Map.get(opts, :style, %{})
    # Added role handling
    role = Map.get(opts, :role, :default)
    # Added focused state
    focused = Map.get(opts, :focused, false)
    shortcut = Map.get(opts, :shortcut)
    tooltip = Map.get(opts, :tooltip)

    %{
      id: id,
      label: label,
      disabled: disabled,
      on_click: on_click,
      width: width,
      height: height,
      theme: theme,
      style: style,
      role: role,
      # Ensure focused state is included
      focused: focused,
      shortcut: shortcut,
      tooltip: tooltip
      # removed pressed state
    }
  end

  @doc '''
  Initializes the Button component state from the given props.
  '''
  @spec init(map()) :: {:ok, t()}
  @impl Component
  def init(state) do
    # Use Button.new to ensure defaults are applied from props
    initialized_state = new(state)
    {:ok, initialized_state}
  end

  @doc '''
  Mounts the Button component. Performs any setup needed after initialization.
  '''
  @spec mount(t()) :: t()
  @impl Component
  def mount(state), do: state

  @doc '''
  Unmounts the Button component, performing any necessary cleanup.
  '''
  @spec unmount(t()) :: t()
  @impl Component
  def unmount(state), do: state

  @doc '''
  Updates the Button component state in response to messages or prop changes.
  '''
  @spec update(t(), term()) :: {:noreply, t()}
  @impl Component
  def update(state, _message) do
    {:noreply, state}
  end

  @spec render(t(), map()) :: map()
  @doc '''
  Renders the button component based on its current state.

  ## Parameters

  * `button` - The button component to render
  * `context` - The rendering context

  ## Returns

  A rendered view representation of the button.
  '''
  @impl Component
  def render(button, context) do
    # Access component styles correctly from context.component_styles
    component_styles = context.component_styles || %{}
    button_theme_from_context = component_styles.button || %{}
    theme = Map.merge(button_theme_from_context, button.theme || %{})
    style = button.style || %{}
    merged_style = Map.merge(theme, style)

    # Determine colors based on state (including focus) and role
    {fg, bg} = resolve_colors(button, merged_style)

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
  @doc '''
  Handles input events for the button component.

  ## Parameters

  * `button` - The button component
  * `event` - The input event to handle
  * `context` - The event context

  ## Returns

  `{:update, updated_button}` if the button state changed,
  `{:handled, button}` if the event was handled but state didn't change,
  `:passthrough` if the event wasn't handled by the button.
  '''
  @impl Component
  def handle_event(button, %Raxol.Core.Events.Event{type: :click}, _context) do
    if button.disabled do
      # Don't execute on_click, but event is handled
      {:handled, button}
    else
      # Execute the click handler if it exists
      if button.on_click, do: button.on_click.()
      # Consider adding :pressed state update here if needed
      # For now, just return handled
      {:handled, button}
    end
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
    # {:noreply, button}
    # Indicate event was not handled by this component
    :passthrough
  end

  # Private helpers

  defp resolve_colors(button, style) do
    # Default fg from theme or :default
    default_fg = Map.get(style, :fg, :default)
    # Default bg from theme or :default
    default_bg = Map.get(style, :bg, :default)

    cond do
      button.disabled ->
        # Use Map.get with fallback to default_fg/default_bg
        {Map.get(style, :disabled_fg, default_fg),
         Map.get(style, :disabled_bg, default_bg)}

      button.focused ->
        {Map.get(style, :focused_fg, default_fg),
         Map.get(style, :focused_bg, default_bg)}

      button.role == :primary ->
        {Map.get(style, :primary_fg, default_fg),
         Map.get(style, :primary_bg, default_bg)}

      button.role == :secondary ->
        {Map.get(style, :secondary_fg, default_fg),
         Map.get(style, :secondary_bg, default_bg)}

      true ->
        {default_fg, default_bg}
    end
  end
end
