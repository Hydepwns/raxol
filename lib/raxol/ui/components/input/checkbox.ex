defmodule Raxol.UI.Components.Input.Checkbox do
  @moduledoc """
  Checkbox component for toggling boolean values.

  This component provides a selectable checkbox with customizable appearance and behavior.
  """

  alias Raxol.UI.Components.Base.Component
  alias Raxol.Event

  @behaviour Component

  @type t :: %{
    id: String.t(),
    label: String.t(),
    checked: boolean(),
    on_change: function() | nil,
    disabled: boolean(),
    theme: map(),
    tooltip: String.t() | nil,
    required: boolean(),
    aria_label: String.t() | nil
  }

  @doc """
  Creates a new checkbox component with the given options.

  ## Options

  * `:id` - Unique identifier for the checkbox
  * `:label` - Text to display next to the checkbox
  * `:checked` - Whether the checkbox is checked
  * `:on_change` - Function to call when the checkbox state changes
  * `:disabled` - Whether the checkbox is disabled
  * `:theme` - Theme overrides for the checkbox
  * `:tooltip` - Optional tooltip text
  * `:required` - Whether the checkbox is required
  * `:aria_label` - Accessibility label

  ## Returns

  A new checkbox component struct.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      id: Keyword.get(opts, :id, "checkbox-#{:erlang.unique_integer([:positive])}"),
      label: Keyword.get(opts, :label, ""),
      checked: Keyword.get(opts, :checked, false),
      on_change: Keyword.get(opts, :on_change),
      disabled: Keyword.get(opts, :disabled, false),
      theme: Keyword.get(opts, :theme, %{}),
      tooltip: Keyword.get(opts, :tooltip),
      required: Keyword.get(opts, :required, false),
      aria_label: Keyword.get(opts, :aria_label)
    }
  end

  @doc """
  Renders the checkbox component based on its current state.

  ## Parameters

  * `checkbox` - The checkbox component to render
  * `context` - The rendering context

  ## Returns

  A rendered view representation of the checkbox.
  """
  @impl Component
  def render(checkbox, context) do
    theme = Map.merge(context.theme.checkbox || %{}, checkbox.theme || %{})

    # Determine colors based on state
    {fg, bg} = resolve_colors(checkbox, theme)

    %{
      type: :checkbox,
      id: checkbox.id,
      attrs: %{
        label: checkbox.label,
        checked: checkbox.checked,
        fg: fg,
        bg: bg,
        disabled: checkbox.disabled,
        tooltip: checkbox.tooltip,
        required: checkbox.required,
        aria_label: checkbox.aria_label || checkbox.label
      },
      events: [
        Event.new(:click, fn ->
          if !checkbox.disabled && checkbox.on_change do
            checkbox.on_change.(!checkbox.checked)
          end
        end),
        Event.new(:keypress, fn key ->
          if key == " " && !checkbox.disabled && checkbox.on_change do
            checkbox.on_change.(!checkbox.checked)
          end
        end)
      ]
    }
  end

  @doc """
  Handles input events for the checkbox component.

  ## Parameters

  * `checkbox` - The checkbox component
  * `event` - The input event to handle
  * `context` - The event context

  ## Returns

  `{:update, updated_checkbox}` if the checkbox state changed,
  `{:handled, checkbox}` if the event was handled but state didn't change,
  `:passthrough` if the event wasn't handled by the checkbox.
  """
  @impl Component
  def handle_event(checkbox, %{type: :click}, _context) do
    if checkbox.disabled do
      {:handled, checkbox}
    else
      updated_checkbox = %{checkbox | checked: !checkbox.checked}
      if checkbox.on_change do
        checkbox.on_change.(updated_checkbox.checked)
      end
      {:update, updated_checkbox}
    end
  end

  def handle_event(checkbox, %{type: :keypress, key: " "}, _context) do
    if checkbox.disabled do
      {:handled, checkbox}
    else
      updated_checkbox = %{checkbox | checked: !checkbox.checked}
      if checkbox.on_change do
        checkbox.on_change.(updated_checkbox.checked)
      end
      {:update, updated_checkbox}
    end
  end

  def handle_event(_checkbox, _event, _context), do: :passthrough

  # Private helpers

  defp resolve_colors(checkbox, theme) do
    cond do
      checkbox.disabled ->
        {theme.disabled_fg || :gray, theme.disabled_bg || :black}

      checkbox.checked ->
        {theme.checked_fg || :green, theme.checked_bg || :black}

      true ->
        {theme.fg || :white, theme.bg || :black}
    end
  end
end
