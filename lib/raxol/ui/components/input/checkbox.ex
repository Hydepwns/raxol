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
  alias Raxol.Core.Events.Event

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
    id =
      Keyword.get(props, :id, "checkbox-#{:erlang.unique_integer([:positive])}")

    state = %{
      # Core state
      id: id,
      checked: Keyword.get(props, :checked, false),
      disabled: Keyword.get(props, :disabled, false),
      # Props influencing state/rendering
      label: Keyword.get(props, :label, ""),
      style: Keyword.get(props, :style, %{}),
      # Callback prop
      on_toggle: Keyword.get(props, :on_toggle),
      # Internal state
      # Default internal state
      focused: false
      # TODO: Consider other props like tooltip, required, aria_label
      # tooltip: Keyword.get(props, :tooltip),
      # required: Keyword.get(props, :required, false),
      # aria_label: Keyword.get(props, :aria_label)
    }

    # Return the state map, not a struct
    {:ok, state}
  end

  @impl true
  def mount(_state), do: {:ok, []}

  @impl true
  def update(props, state) when is_map(props) do
    # Merge the new props into the state
    new_state = Map.merge(state, props)
    # Return {:ok, new_state, commands} as per component behavior (usually)
    {:ok, new_state, []}
  end

  @impl true
  def update(message, state) do
    IO.inspect(message, label: "Unhandled Checkbox update (ignored)")
    # Return ok to avoid crashing test if unexpected message sent
    {:ok, state, []}
  end

  @impl true
  def handle_event(
        %Event{type: :mouse, data: %{action: :press}} = event,
        _context,
        state
      )
      when not state.disabled do
    toggle_state(event, state)
  end

  def handle_event(
        %Event{type: :key, data: %{key: :space}} = event,
        _context,
        state
      )
      when not state.disabled do
    toggle_state(event, state)
  end

  def handle_event(_event, _context, state) do
    {:noreply, state, []}
  end

  defp toggle_state(_event, state) do
    new_checked_state = !state.checked
    new_state = %{state | checked: new_checked_state}

    commands =
      if is_function(state.on_toggle, 1) do
        # Potentially create a command if the callback needs to trigger one,
        # but for now, just call it directly.
        # The callback itself might return a command to be dispatched.
        # For simplicity in this fix, we assume the callback is side-effect only or returns nil.
        _ = state.on_toggle.(new_checked_state)
        []
      else
        []
      end

    {:noreply, new_state, commands}
  end

  @impl true
  def render(state, context) do
    theme = context.theme
    # Get base style for :checkbox from theme
    theme_style = Theme.component_style(theme, :checkbox)
    # Merge theme style with instance style (instance overrides theme)
    base_style = Map.merge(theme_style, state.style)

    # Determine effective style based on state
    {fg, bg} =
      cond do
        state.disabled ->
          # Fallback chain
          {Map.get(base_style, :disabled_fg, Map.get(base_style, :fg, :gray)),
           Map.get(base_style, :disabled_bg, Map.get(base_style, :bg, :default))}

        state.focused ->
          {Map.get(base_style, :focused_fg, Map.get(base_style, :fg, :default)),
           Map.get(base_style, :focused_bg, Map.get(base_style, :bg, :default))}

        true ->
          {Map.get(base_style, :fg, :default),
           Map.get(base_style, :bg, :default)}
      end

    # TODO: Handle other style attributes like :bold, :underline based on state/theme?
    final_attrs_style = %{fg: fg, bg: bg}

    check_char = if state.checked, do: "[x]", else: "[ ]"
    label_text = state.label

    # Pass children under the :do key in the opts list
    # Apply the calculated style to the hbox
    Element.new(
      :hbox,
      # Apply calculated fg/bg
      %{style: final_attrs_style},
      do: [
        # Maybe apply style individually? For now, apply to hbox.
        Element.new(:text, %{id: "#{state.id}-check", text: check_char}),
        Element.new(:text, %{id: "#{state.id}-label", text: " " <> label_text})
      ]
    )
  end

  @impl true
  def unmount(_state), do: :ok
end
