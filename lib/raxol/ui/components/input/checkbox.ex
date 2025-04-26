defmodule Raxol.UI.Components.Input.Checkbox do
  @moduledoc """
  Checkbox component for toggling boolean values.

  This component provides a selectable checkbox with customizable appearance and behavior.
  """

  # use Raxol.UI.Components.Base
  # alias Raxol.UI.Components.Base.Component
  # alias Raxol.UI.Style
  # alias Raxol.UI.Element
  # alias Raxol.UI.Theme
  # alias Raxol.UI.Theming.Theme
  # alias Raxol.UI.Layout.Constraints

  # alias Raxol.View
  # alias Raxol.UI.Theming.Colors
  # alias Raxol.View.Style
  # alias Raxol.Core.Events
  # alias Raxol.Core.Events.{FocusEvent, KeyEvent}

  alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme

  # alias Raxol.UI.Components.Base # Unused
  # alias Raxol.Core.Events.ClickEvent # Unused

  @behaviour Raxol.UI.Components.Base.Component

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
      id:
        Keyword.get(
          opts,
          :id,
          "checkbox-#{:erlang.unique_integer([:positive])}"
        ),
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

  @impl true
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    state = struct!(__MODULE__, Keyword.merge([id: id], props))
    {:ok, state}
  end

  @impl true
  def mount(_state), do: {:ok, []}

  @impl true
  def update({:update_props, new_props}, state) do
    {:noreply, Map.merge(state, Map.new(new_props))}
  end

  @impl true
  def update(message, state) do
    IO.inspect(message, label: "Unhandled Checkbox update")
    {:noreply, state}
  end

  @impl true
  def handle_event(state, event, _context) do
    case event do
      {:keypress, :space} ->
        {:noreply, %{state | checked: !state.checked}}

      {:click} ->
        {:noreply, %{state | checked: !state.checked}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def render(state, context) do
    theme = context.theme
    component_theme_style = Theme.component_style(theme, :checkbox)
    style = Raxol.Style.merge(component_theme_style, state.style)

    check_char = if state.checked, do: "[x]", else: "[ ]"
    label_text = state.label

    Element.new(
      :hbox,
      %{style: style},
      [
        Element.new(:text, %{id: "#{state.id}-check"}, check_char),
        Element.new(:text, %{id: "#{state.id}-label"}, " " <> label_text)
      ]
    )
  end

  @impl true
  def unmount(_state), do: :ok
end
