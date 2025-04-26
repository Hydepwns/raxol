defmodule Raxol.Components.Dashboard.Widgets.InfoWidget do
  @moduledoc """
  A dashboard widget that displays simple text information.
  """

  use Raxol.UI.Components.Base.Component
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI # Use UI alias for consistency

  defstruct title: "Info", content: "No info available", id: :info_widget

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    %__MODULE__{
      id: props[:id] || :info_widget,
      title: props[:title] || "Info",
      content: props[:content] || "No info available"
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(_msg, state), do: {state, []} # Placeholder

  @impl Raxol.UI.Components.Base.Component
  def handle_event(_event, _props, state), do: {state, []} # Placeholder

  @impl Raxol.UI.Components.Base.Component
  def render(state, _props) do
    UI.box title: state.title, id: state.id, border: :single do
      UI.column do
        [
          UI.label(content: state.content || ""),
          UI.label(content: "This is static info."),
          UI.label(content: "More details...")
        ] |> Enum.reject(&(&1 == nil || &1 == %{}))
      end
    end
  end

end
