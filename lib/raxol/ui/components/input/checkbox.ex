defmodule Raxol.UI.Components.Input.Checkbox do
  @moduledoc """
  Checkbox component for toggling boolean values.

  This component provides a selectable checkbox with customizable appearance and behavior.
  Fully supports style and theme props (with correct merging/precedence),
  implements robust lifecycle hooks, and supports accessibility/extra props.
  """

  import Raxol.Guards

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
          on_toggle: function() | nil,
          disabled: boolean(),
          style: map(),
          theme: map(),
          tooltip: String.t() | nil,
          required: boolean(),
          aria_label: String.t() | nil,
          focused: boolean()
        }

  @doc """
  Creates a new checkbox component with the given options.
  See `init/1` for details.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    # Just delegate to init for consistency
    {:ok, state} = init(opts)
    state
  end

  @doc """
  Initializes the Checkbox component state from the given props.
  """
  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(props) do
    id =
      Keyword.get(props, :id, "checkbox-#{:erlang.unique_integer([:positive])}")

    state = %{
      id: id,
      checked: Keyword.get(props, :checked, false),
      disabled: Keyword.get(props, :disabled, false),
      label: Keyword.get(props, :label, ""),
      style: Keyword.get(props, :style, %{}),
      theme: Keyword.get(props, :theme, %{}),
      on_toggle: Keyword.get(props, :on_toggle),
      tooltip: Keyword.get(props, :tooltip),
      required: Keyword.get(props, :required, false),
      aria_label: Keyword.get(props, :aria_label),
      focused: false
    }

    {:ok, state}
  end

  @doc """
  Mounts the Checkbox component. Performs any setup needed after initialization.
  """
  @impl true
  @spec mount(t()) :: {t(), list()}
  def mount(state) do
    # Could register focus, subscriptions, etc. if needed
    # For now, just return state and []
    {state, []}
  end

  @doc """
  Unmounts the Checkbox component, performing any necessary cleanup.
  """
  @impl true
  @spec unmount(t()) :: t()
  def unmount(state) do
    # Cleanup any resources, subscriptions, etc. if needed
    state
  end

  @doc """
  Updates the Checkbox component state in response to messages or prop changes.
  """
  @impl true
  @spec update(map(), t()) :: {:ok, t(), list()}
  def update(props, state) when map?(props) do
    # Merge new props into state, with style/theme merged as in other components
    merged_style = Map.merge(state.style || %{}, Map.get(props, :style, %{}))
    merged_theme = Map.merge(state.theme || %{}, Map.get(props, :theme, %{}))

    new_state =
      state
      |> Map.merge(props)
      |> Map.put(:style, merged_style)
      |> Map.put(:theme, merged_theme)

    {:ok, new_state, []}
  end

  @impl true
  @spec update(term(), t()) :: {:ok, t(), list()}
  def update(_msg, state) do
    # Ignore unknown messages for now
    {:ok, state, []}
  end

  @impl true
  def handle_event(
        %Event{type: :mouse, data: %{action: :press}},
        _context,
        state
      )
      when not state.disabled do
    toggle_state(state)
  end

  def handle_event(%Event{type: :key, data: %{key: :space}}, _context, state)
      when not state.disabled do
    toggle_state(state)
  end

  def handle_event(_event, _context, state), do: {:noreply, state, []}

  defp toggle_state(state) do
    new_checked_state = !state.checked
    new_state = %{state | checked: new_checked_state}

    commands =
      if function?(state.on_toggle, 1),
        do:
          (
            state.on_toggle.(new_checked_state)
            []
          ),
        else: []

    {:noreply, new_state, commands}
  end

  @doc """
  Renders the Checkbox component using the current state and context.
  """
  @impl true
  @spec render(t(), map()) :: any()
  def render(state, context) do
    # Harmonize theme merging: context.theme < state.theme < state.style
    theme = Map.merge(context.theme || %{}, state.theme || %{})
    theme_style = Theme.component_style(theme, :checkbox)
    base_style = Map.merge(theme_style, state.style || %{})

    {fg, bg} =
      cond do
        state.disabled ->
          {Map.get(base_style, :disabled_fg, Map.get(base_style, :fg, :gray)),
           Map.get(base_style, :disabled_bg, Map.get(base_style, :bg, :default))}

        state.focused ->
          {Map.get(base_style, :focused_fg, Map.get(base_style, :fg, :default)),
           Map.get(base_style, :focused_bg, Map.get(base_style, :bg, :default))}

        true ->
          {Map.get(base_style, :fg, :default),
           Map.get(base_style, :bg, :default)}
      end

    # Support bold/underline/other attrs if present
    attrs =
      Map.take(base_style, [:bold, :underline, :italic])
      |> Map.merge(%{fg: fg, bg: bg})

    check_char = if state.checked, do: "[x]", else: "[ ]"
    label_text = state.label
    # Accessibility: aria_label, required, tooltip as attributes
    extra_attrs =
      %{
        aria_label: state.aria_label,
        required: state.required,
        tooltip: state.tooltip
      }
      |> Enum.reject(fn {_k, v} -> nil?(v) or v == false end)
      |> Enum.into(%{})

    Element.new(
      :hbox,
      Map.merge(%{style: attrs}, extra_attrs),
      do: [
        Element.new(:text, %{id: "#{state.id}-check", text: check_char}),
        Element.new(:text, %{id: "#{state.id}-label", text: " " <> label_text})
      ]
    )
  end
end
