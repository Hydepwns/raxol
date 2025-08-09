defmodule Raxol.UI.Components.Dashboard.Widgets.InfoWidget do
  @moduledoc """
  A dashboard widget that displays simple text information.
  """

  use Raxol.UI.Components.Base.Component
  require Raxol.View.Elements
  # Use UI alias for consistency
  alias Raxol.View.Elements, as: UI

  defstruct title: "Info", content: "No info available", id: :info_widget

  @spec init(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    %__MODULE__{
      id: props[:id] || :info_widget,
      title: props[:title] || "Info",
      content: props[:content] || "No info available"
    }
  end

  @spec update(term(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  # Placeholder
  def update(_msg, state), do: {state, []}

  @spec handle_event(term(), map(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  # Placeholder
  def handle_event(_event, _props, state), do: {state, []}

  @spec render(map(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, _props) do
    UI.box title: state.title, id: state.id, border: :single do
      UI.column do
        [
          UI.label(content: state.content || ""),
          UI.label(content: "This is static info."),
          UI.label(content: "More details...")
        ]
        |> Enum.reject(&(&1 == nil || &1 == %{}))
      end
    end
  end

  @doc """
  Mount hook - called when component is mounted.
  No special setup needed for InfoWidget.
  """
  @impl true
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc """
  Unmount hook - called when component is unmounted.
  No cleanup needed for InfoWidget.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state
end
