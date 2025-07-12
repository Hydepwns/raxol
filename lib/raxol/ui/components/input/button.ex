defmodule Raxol.UI.Components.Input.Button do
  @moduledoc """
  Button component for interactive UI elements.

  This component provides a clickable button with customizable appearance and behavior.
  """

  defstruct [
    :label,
    :id,
    :on_click,
    :disabled,
    :focused,
    :pressed,
    :role,
    :shortcut,
    :tooltip,
    :theme,
    :style,
    :height,
    :width,
    :errors
  ]

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
  def new(attrs) do
    state = %__MODULE__{
      label: Map.get(attrs, :label, "Button"),
      id: Map.get(attrs, :id, nil) || Raxol.Core.ID.generate(),
      on_click: Map.get(attrs, :on_click, nil),
      disabled: Map.get(attrs, :disabled, false),
      focused: Map.get(attrs, :focused, false),
      pressed: Map.get(attrs, :pressed, false),
      role: Map.get(attrs, :role, :default),
      shortcut: Map.get(attrs, :shortcut, nil),
      tooltip: Map.get(attrs, :tooltip, nil),
      theme: Map.get(attrs, :theme, %{}),
      style: Map.get(attrs, :style, %{}),
      height: Map.get(attrs, :height, nil),
      width: Map.get(attrs, :width, nil)
    }

    %{state | errors: errors(state)}
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
    # Use the truncated label if present
    display_label =
      Map.get(button, :_truncated_label) || build_display_label(button)

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
  def handle_event(button, %Raxol.Core.Events.Event{type: :click}, _context) do
    handle_click_event(button)
  end

  def handle_event(
        button,
        %Raxol.Core.Events.Event{type: :click, data: _data},
        _context
      ) do
    handle_click_event(button)
  end

  def handle_event(
        button,
        %Raxol.Core.Events.Event{type: :focus, data: data},
        _context
      )
      when is_map(data) do
    updated_button = %{button | focused: Map.get(data, :focused, true)}
    updated_button = %{updated_button | errors: errors(updated_button)}
    {:update, updated_button, []}
  end

  def handle_event(button, %Raxol.Core.Events.Event{type: :focus}, _context) do
    updated_button = %{button | focused: true}
    updated_button = %{updated_button | errors: errors(updated_button)}
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
      if button.on_click, do: button.on_click.()
      {:handled, button}
    end
  end

  def handle_event(
        button,
        %Raxol.Core.Events.Event{
          type: :mouse,
          data: %{button: :left, state: :pressed}
        },
        _context
      ) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()
      updated_button = %{button | pressed: true}

      {:update, updated_button,
       [{:dispatch_to_parent, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
  end

  def handle_event(_button, %Raxol.Core.Events.Event{} = _event, _context) do
    :passthrough
  end

  # Support both (button, event, context) and (event, button, context) argument orders
  def handle_event(%Raxol.Core.Events.Event{} = event, button, context)
      when is_map(button) do
    handle_event(button, event, context)
  end

  # Add validation for invalid roles
  def errors(button) do
    errors = %{}

    errors =
      if button.role in [:default, :primary, :secondary],
        do: errors,
        else: Map.put(errors, :role, "Invalid role")

    errors
  end

  # Private helper for handling click events
  defp handle_click_event(button) do
    if button.disabled do
      {:handled, button}
    else
      if button.on_click, do: button.on_click.()
      updated_button = %{button | pressed: true}
      updated_button = %{updated_button | errors: errors(updated_button)}

      {:update, updated_button,
       [{:dispatch_to_parent, %Raxol.Core.Events.Event{type: :button_pressed}}]}
    end
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
    # Use base label for width calculation, not decorated label
    base_label = button.label

    # Padding accounts for borders, spacing, and maximum focus decorations ("> " and " <" = 4 chars)
    # 8 for borders/spacing + 4 for focus decorations
    padding = 12
    max_width = context.max_width || 80
    # Calculate available space for the base label
    available_label_width = max(max_width - padding, 1)

    truncated_label =
      if String.length(base_label) > available_label_width do
        String.slice(base_label, 0, available_label_width)
      else
        base_label
      end

    # Store the truncated base label for rendering
    button = Map.put(button, :_truncated_label, truncated_label)

    button.width ||
      (String.length(truncated_label) + padding)
      |> min(max_width)
  end

  # Update build_display_label to use the truncated label if present
  defp build_display_label(%{
         _truncated_label: truncated_label,
         focused: focused
       })
       when is_binary(truncated_label) do
    # Apply focus decorations to the truncated base label
    if focused, do: "> #{truncated_label} <", else: truncated_label
  end

  defp build_display_label(button) do
    if button.focused, do: "> #{button.label} <", else: button.label
  end

  defp resolve_colors(button, style) do
    default_fg = Map.get(style, :fg, :default)
    default_bg = Map.get(style, :bg, :default)

    cond do
      button.disabled ->
        get_disabled_colors(style, default_fg, default_bg)

      button.focused ->
        get_focused_colors(style, default_fg, default_bg)

      button.role == :primary ->
        get_primary_colors(style, default_fg, default_bg)

      button.role == :secondary ->
        get_secondary_colors(style, default_fg, default_bg)

      true ->
        {default_fg, default_bg}
    end
  end

  defp get_disabled_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override disabled_fg
    fg =
      if Map.has_key?(style, :fg),
        do: Map.get(style, :fg),
        else: Map.get(style, :disabled_fg, default_fg)

    bg =
      if Map.has_key?(style, :bg),
        do: Map.get(style, :bg),
        else: Map.get(style, :disabled_bg, default_bg)

    {fg, bg}
  end

  defp get_focused_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override focused_fg
    fg =
      if Map.has_key?(style, :fg),
        do: Map.get(style, :fg),
        else: Map.get(style, :focused_fg, default_fg)

    bg =
      if Map.has_key?(style, :bg),
        do: Map.get(style, :bg),
        else: Map.get(style, :focused_bg, default_bg)

    {fg, bg}
  end

  defp get_primary_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override primary_fg
    fg =
      if Map.has_key?(style, :fg),
        do: Map.get(style, :fg),
        else: Map.get(style, :primary_fg, default_fg)

    bg =
      if Map.has_key?(style, :bg),
        do: Map.get(style, :bg),
        else: Map.get(style, :primary_bg, default_bg)

    {fg, bg}
  end

  defp get_secondary_colors(style, default_fg, default_bg) do
    # If there's an explicit fg in the style, it should override secondary_fg
    fg =
      if Map.has_key?(style, :fg),
        do: Map.get(style, :fg),
        else: Map.get(style, :secondary_fg, default_fg)

    bg =
      if Map.has_key?(style, :bg),
        do: Map.get(style, :bg),
        else: Map.get(style, :secondary_bg, default_bg)

    {fg, bg}
  end
end
