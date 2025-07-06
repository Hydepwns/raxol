defmodule Raxol.UI.Components.Input.Button do
  @moduledoc """
  Button component for interactive UI elements.

  This component provides a clickable button with customizable appearance and behavior.
  """

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.Core.Events.Event # REMOVE ALIAS
  import Raxol.Guards

  @behaviour Component

  @type t :: %{
          id: String.t(),
          label: String.t(),
          on_click: function() | nil,
          disabled: boolean(),
          focused: boolean(),
          pressed: boolean(),
          theme: map(),
          style: map(),
          width: integer() | nil,
          height: integer() | nil,
          shortcut: String.t() | nil,
          tooltip: String.t() | nil,
          role: :primary | :secondary | :danger | :success | nil
        }

  @spec new(map()) :: t()
  @doc """
  Creates a new Button state map, applying defaults.
  Expects opts to be a Map.
  """
  def new(opts) when map?(opts) do
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
      pressed: false,
      shortcut: shortcut,
      tooltip: tooltip
      # removed pressed state
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

    # Validate the state and store any errors
    validation_errors = errors(initialized_state)
    state_with_errors = Map.put(initialized_state, :errors, validation_errors)

    {:ok, state_with_errors}
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
    merged_style = build_merged_style(button, context)
    {fg, bg} = resolve_colors(button, merged_style)

    button_width = calculate_width(button, context)
    button_height = button.height || 3
    display_label = build_display_label(button)

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
  def handle_event(button, %Raxol.Core.Events.Event{type: :click, data: _data}, _context) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()
      updated_button = %{button | pressed: true}
      {:update, updated_button, [{:dispatch_to_parent, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :click}, _context) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()
      updated_button = %{button | pressed: true}
      {:update, updated_button, [{:dispatch_to_parent, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :focus, data: data}, _context) when is_map(data) do
    updated_button = %{button | focused: Map.get(data, :focused, true)}
    {:update, updated_button, []}
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :focus}, _context) do
    updated_button = %{button | focused: true}
    {:update, updated_button, []}
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :keypress, data: %{key: key}}, _context) do
    if button.disabled or (key != :space and key != :enter) do
      :passthrough
    else
      if button.on_click, do: button.on_click.()
      {:handled, button}
    end
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :mouse, data: %{button: :left, state: :pressed}}, _context) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()
      updated_button = %{button | pressed: true}
      {:update, updated_button, [{:dispatch_to_parent, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
  end

  def handle_event(_button, %Raxol.Core.Events.Event{} = _event, _context) do
    :passthrough
  end

  # Support both (button, event, context) and (event, button, context) argument orders
  def handle_event(%Raxol.Core.Events.Event{} = event, button, context) when is_map(button) do
    handle_event(button, event, context)
  end

  # Add validation for invalid roles
  def errors(button) do
    errors = %{}
    errors =
      if button.role in [:default, :primary, :secondary], do: errors, else: Map.put(errors, :role, "Invalid role")
    errors
  end

  # Private helpers

  defp build_merged_style(button, context) do
    component_styles = context.component_styles || %{}
    button_theme_from_context = component_styles.button || %{}
    theme = Map.merge(button_theme_from_context, button.theme || %{})
    style = button.style || %{}
    # Style should override theme, so merge style into theme
    Map.merge(theme, style)
  end

  defp calculate_width(button, context) do
    button.width || min(String.length(button.label) + 4, context.max_width)
  end

  defp build_display_label(button) do
    if button.focused, do: "> #{button.label} <", else: button.label
  end

  defp resolve_colors(button, style) do
    default_fg = Map.get(style, :fg, :default)
    default_bg = Map.get(style, :bg, :default)

    cond do
      button.disabled -> get_disabled_colors(style, default_fg, default_bg)
      button.focused -> get_focused_colors(style, default_fg, default_bg)
      button.role == :primary -> get_primary_colors(style, default_fg, default_bg)
      button.role == :secondary -> get_secondary_colors(style, default_fg, default_bg)
      true -> {default_fg, default_bg}
    end
  end

  defp get_disabled_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override disabled_fg
    fg = if Map.has_key?(style, :fg), do: Map.get(style, :fg), else: Map.get(style, :disabled_fg, default_fg)
    bg = if Map.has_key?(style, :bg), do: Map.get(style, :bg), else: Map.get(style, :disabled_bg, default_bg)
    {fg, bg}
  end

  defp get_focused_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override focused_fg
    fg = if Map.has_key?(style, :fg), do: Map.get(style, :fg), else: Map.get(style, :focused_fg, default_fg)
    bg = if Map.has_key?(style, :bg), do: Map.get(style, :bg), else: Map.get(style, :focused_bg, default_bg)
    {fg, bg}
  end

  defp get_primary_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override primary_fg
    fg = if Map.has_key?(style, :fg), do: Map.get(style, :fg), else: Map.get(style, :primary_fg, default_fg)
    bg = if Map.has_key?(style, :bg), do: Map.get(style, :bg), else: Map.get(style, :primary_bg, default_bg)
    {fg, bg}
  end

  defp get_secondary_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override secondary_fg
    fg = if Map.has_key?(style, :fg), do: Map.get(style, :fg), else: Map.get(style, :secondary_fg, default_fg)
    bg = if Map.has_key?(style, :bg), do: Map.get(style, :bg), else: Map.get(style, :secondary_bg, default_bg)
    {fg, bg}
  end
end
