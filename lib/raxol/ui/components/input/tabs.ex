defmodule Raxol.UI.Components.Input.Tabs do
  @moduledoc """
  A tab bar component with keyboard navigation.

  Renders a horizontal row of tab labels with dividers. The active tab is
  highlighted with reverse video. Supports arrow keys, Home/End, and number
  keys (1-9) for direct tab selection.

  This component only renders the tab bar itself -- content switching is the
  parent's responsibility via the `on_change` callback.
  """

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @type tab :: %{id: atom() | String.t(), label: String.t()}

  @type t :: %{
          id: String.t() | atom(),
          tabs: [tab()],
          active_index: non_neg_integer(),
          focused: boolean(),
          on_change: (non_neg_integer() -> any()) | nil,
          style: map(),
          theme: map()
        }

  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(props) do
    state = %{
      id:
        Keyword.get(props, :id, "tabs-#{:erlang.unique_integer([:positive])}"),
      tabs: Keyword.get(props, :tabs, []),
      active_index: Keyword.get(props, :active_index, 0),
      focused: Keyword.get(props, :focused, false),
      on_change: Keyword.get(props, :on_change),
      style: Keyword.get(props, :style, %{}),
      theme: Keyword.get(props, :theme, %{})
    }

    {:ok, state}
  end

  @impl true
  @spec mount(t()) :: {t(), list()}
  def mount(state), do: {state, []}

  @impl true
  @spec unmount(t()) :: t()
  def unmount(state), do: state

  @impl true
  @spec update(map(), t()) :: {t(), list()}
  def update(props, state) when is_map(props) do
    Raxol.UI.Components.Base.Component.merge_props(props, state)
  end

  def update(_msg, state), do: {state, []}

  # Left arrow -- previous tab with wrapping
  @impl true
  def handle_event(%Event{type: :key, data: %{key: :left}}, state, _context) do
    navigate(state, -1)
  end

  # Right arrow -- next tab with wrapping
  def handle_event(%Event{type: :key, data: %{key: :right}}, state, _context) do
    navigate(state, 1)
  end

  # Home -- first tab
  def handle_event(%Event{type: :key, data: %{key: :home}}, state, _context) do
    set_active(state, 0)
  end

  # End -- last tab
  def handle_event(%Event{type: :key, data: %{key: :end}}, state, _context) do
    count = length(state.tabs)

    if count > 0 do
      set_active(state, count - 1)
    else
      {state, []}
    end
  end

  # Number keys 1-9 for direct tab selection
  def handle_event(
        %Event{type: :key, data: %{key: :char, char: ch}},
        state,
        _context
      )
      when ch in ~w(1 2 3 4 5 6 7 8 9) do
    index = String.to_integer(ch) - 1

    if index < length(state.tabs) do
      set_active(state, index)
    else
      {state, []}
    end
  end

  # Focus
  def handle_event(%Event{type: :focus}, state, _context) do
    {%{state | focused: true}, []}
  end

  # Blur
  def handle_event(%Event{type: :blur}, state, _context) do
    {%{state | focused: false}, []}
  end

  # Pass-through
  def handle_event(_event, state, _context), do: {state, []}

  @impl true
  @spec render(t(), map()) :: map()
  def render(state, context) do
    focused = Raxol.UI.FocusHelper.focused?(state.id, context) or state.focused
    state = %{state | focused: focused}

    theme = Map.merge(context[:theme] || %{}, state.theme || %{})
    theme_style = Theme.component_style(theme, :tabs)
    base_style = Map.merge(theme_style, state.style || %{})

    base_style =
      Raxol.UI.FocusHelper.maybe_focus_style(state.id, context, base_style)

    children = build_children(state)

    %{
      type: :row,
      style: base_style,
      children: children
    }
  end

  defp navigate(state, delta) do
    count = length(state.tabs)

    if count == 0 do
      {state, []}
    else
      new_index = rem(state.active_index + delta + count, count)
      set_active(state, new_index)
    end
  end

  defp set_active(state, index) do
    new_state = %{state | active_index: index}
    fire_on_change(state.on_change, index)
    {new_state, []}
  end

  defp fire_on_change(nil, _index), do: :ok
  defp fire_on_change(cb, index) when is_function(cb, 1), do: cb.(index)

  defp build_children(%{tabs: []}), do: []

  defp build_children(%{tabs: tabs, active_index: active_index, id: id}) do
    tabs
    |> Enum.with_index()
    |> Enum.flat_map(fn {tab, index} ->
      tab_style =
        if index == active_index do
          Raxol.Core.Defaults.selected_style()
        else
          %{}
        end

      tab_el =
        Raxol.View.Components.text(
          id: "#{id}-tab-#{index}",
          content: " #{tab.label} ",
          style: tab_style
        )

      if index < length(tabs) - 1 do
        divider =
          Raxol.View.Components.text(
            id: "#{id}-div-#{index}",
            content: "|"
          )

        [tab_el, divider]
      else
        [tab_el]
      end
    end)
  end
end
