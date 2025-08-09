defmodule Raxol.UI.Components.Dashboard.Widgets.TextInputWidget do
  @moduledoc """
  A dashboard widget containing a text input.
  """

  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI

  defstruct input_id: :text_widget_input,
            value: "",
            placeholder: "Enter text...",
            title: "Text Input",
            id: :text_widget

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    %__MODULE__{
      id: props[:id] || :text_widget,
      input_id: props[:input_id] || :text_widget_input,
      title: props[:title] || "Text Input",
      value: props[:value] || "",
      placeholder: props[:placeholder] || "Enter text..."
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update({:input, value}, state) do
    # Update value from text_input component message
    {%{state | value: value}, []}
  end

  def update(msg, state) do
    Raxol.Core.Runtime.Log.debug(
      "TextInputWidget received message: #{inspect(msg)}"
    )

    {state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, _props, state) do
    # Placeholder - handle events if needed
    Raxol.Core.Runtime.Log.debug(
      "TextInputWidget received event: #{inspect(event)}"
    )

    {state, []}
  end

  @doc """
  Renders the text input widget content.

  Requires props:
  - `widget_config`: The configuration map for the widget (%{id: _, type: _, title: _, ...}).
  - `app_text`: The current text value from the main application model.
  """
  @impl Raxol.UI.Components.Base.Component
  def render(state, _props) do
    UI.box title: state.title, id: state.id, border: :single do
      UI.text_input(
        id: state.input_id,
        value: state.value,
        placeholder: state.placeholder,
        # Send simple :input message to self
        on_change: :input
      )
    end
  end

  @doc """
  Mount hook - called when component is mounted.
  No special setup needed for TextInputWidget.
  """
  @impl true
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc """
  Unmount hook - called when component is unmounted.
  No cleanup needed for TextInputWidget.
  """
  @impl true
  @spec unmount(map()) :: map()
  def unmount(state), do: state
end
