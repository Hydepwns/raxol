defmodule Raxol.UI.Components.Input.Button do
  @moduledoc """
  Button component for interactive UI elements.

  This component provides a clickable button with customizable appearance and behavior.
  """

  alias Raxol.UI.Components.Base.Component
  alias Raxol.Event

  @behaviour Component

  @type t :: %{
    id: String.t(),
    label: String.t(),
    on_click: function() | nil,
    disabled: boolean(),
    theme: map(),
    width: integer() | nil,
    height: integer() | nil,
    shortcut: String.t() | nil,
    tooltip: String.t() | nil,
    role: :primary | :secondary | :danger | :success | nil
  }

  @doc """
  Creates a new button component with the given options.

  ## Options

  * `:id` - Unique identifier for the button
  * `:label` - Text to display on the button
  * `:on_click` - Function to call when the button is clicked
  * `:disabled` - Whether the button is disabled
  * `:theme` - Theme overrides for the button
  * `:width` - Optional fixed width for the button
  * `:height` - Optional fixed height for the button
  * `:shortcut` - Optional keyboard shortcut for the button
  * `:tooltip` - Optional tooltip text
  * `:role` - Optional semantic role affecting appearance (:primary, :secondary, :danger, :success)

  ## Returns

  A new button component struct.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      id: Keyword.get(opts, :id, "button-#{:erlang.unique_integer([:positive])}"),
      label: Keyword.get(opts, :label, "Button"),
      on_click: Keyword.get(opts, :on_click),
      disabled: Keyword.get(opts, :disabled, false),
      theme: Keyword.get(opts, :theme, %{}),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height),
      shortcut: Keyword.get(opts, :shortcut),
      tooltip: Keyword.get(opts, :tooltip),
      role: Keyword.get(opts, :role)
    }
  end

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
    theme = Map.merge(context.theme.button || %{}, button.theme || %{})

    # Determine colors based on state and role
    {fg, bg} = resolve_colors(button, theme)

    button_width = button.width || min(String.length(button.label) + 4, context.max_width)
    button_height = button.height || 3

    %{
      type: :button,
      id: button.id,
      attrs: %{
        label: button.label,
        width: button_width,
        height: button_height,
        fg: fg,
        bg: bg,
        disabled: button.disabled,
        shortcut: button.shortcut,
        tooltip: button.tooltip,
        role: button.role
      },
      events: [
        Event.new(:click, fn -> if button.on_click && !button.disabled, do: button.on_click.() end)
      ]
    }
  end

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
  def handle_event(button, %{type: :click}, _context) do
    if button.disabled || !button.on_click do
      {:handled, button}
    else
      # Execute the click handler
      button.on_click.()
      {:handled, button}
    end
  end

  def handle_event(button, %{type: :keypress, key: key}, context) do
    # Handle keyboard shortcut activation
    if !button.disabled &&
       button.shortcut &&
       String.downcase(button.shortcut) == String.downcase(key) do
      if button.on_click do
        button.on_click.()
      end
      {:handled, button}
    else
      :passthrough
    end
  end

  def handle_event(_button, _event, _context), do: :passthrough

  # Private helpers

  defp resolve_colors(button, theme) do
    cond do
      button.disabled ->
        {theme.disabled_fg || :gray, theme.disabled_bg || :darkgray}

      button.role == :primary ->
        {theme.primary_fg || :white, theme.primary_bg || :blue}

      button.role == :secondary ->
        {theme.secondary_fg || :black, theme.secondary_bg || :lightgray}

      button.role == :danger ->
        {theme.danger_fg || :white, theme.danger_bg || :red}

      button.role == :success ->
        {theme.success_fg || :white, theme.success_bg || :green}

      true ->
        {theme.fg || :white, theme.bg || :blue}
    end
  end
end
