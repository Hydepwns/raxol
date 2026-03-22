defmodule Raxol.UI.Components.Display.StatusBar do
  @moduledoc """
  A non-interactive status bar that displays key-value pairs separated by a configurable delimiter.

  Keys are rendered bold, followed by their label values, joined by a separator string.
  """

  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @type item :: %{key: String.t(), label: String.t()}

  @type t :: %{
          id: String.t() | atom(),
          items: [item()],
          separator: String.t(),
          style: map(),
          theme: map()
        }

  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(props) do
    state = %{
      id:
        Keyword.get(
          props,
          :id,
          "status-bar-#{:erlang.unique_integer([:positive])}"
        ),
      items: Keyword.get(props, :items, []),
      separator: Keyword.get(props, :separator, " | "),
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
    merged_style = Map.merge(state.style || %{}, Map.get(props, :style, %{}))
    merged_theme = Map.merge(state.theme || %{}, Map.get(props, :theme, %{}))

    new_state =
      state
      |> Map.merge(props)
      |> Map.put(:style, merged_style)
      |> Map.put(:theme, merged_theme)

    {new_state, []}
  end

  def update(_msg, state), do: {state, []}

  @impl true
  def handle_event(_event, state, _context), do: {state, []}

  @impl true
  @spec render(t(), map()) :: map()
  def render(state, context) do
    theme = Map.merge(context[:theme] || %{}, state.theme || %{})
    theme_style = Theme.component_style(theme, :status_bar)
    base_style = Map.merge(theme_style, state.style || %{})

    children = build_children(state)

    %{
      type: :row,
      style: base_style,
      children: children
    }
  end

  defp build_children(%{items: []}), do: []

  defp build_children(%{items: items, separator: separator, id: id}) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      item_elements = [
        Raxol.View.Components.text(
          id: "#{id}-key-#{index}",
          content: "#{item.key}: ",
          style: %{bold: true}
        ),
        Raxol.View.Components.text(
          id: "#{id}-val-#{index}",
          content: item.label
        )
      ]

      if index < length(items) - 1 do
        item_elements ++
          [
            Raxol.View.Components.text(
              id: "#{id}-sep-#{index}",
              content: separator
            )
          ]
      else
        item_elements
      end
    end)
  end
end
