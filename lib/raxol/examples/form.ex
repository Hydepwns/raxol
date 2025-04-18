defmodule Raxol.Examples.Form do
  @moduledoc """
  A sample form component that demonstrates parent-child interactions.

  This component includes:
  - Child component management
  - Event bubbling
  - State synchronization
  - Error boundaries
  """

  use Raxol.Component

  alias Raxol.Core.Renderer.Element
  alias Raxol.View

  @impl true
  def init(props) do
    state = %{
      title: Map.get(props, :title, "Sample Form"),
      submitted: false,
      children: [],
      error: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_event(:button_clicked, state) do
    {
      %{state | submitted: true},
      [:form_submitted]
    }
  end

  def handle_event({:error, child_id, error}, state) do
    {
      %{state | error: "Error in #{child_id}: #{error}"},
      [:error_captured]
    }
  end

  def handle_event(_event, state) do
    {state, []}
  end

  @impl true
  @spec render(map()) :: Raxol.Core.Renderer.Element.t() | nil
  @dialyzer {:nowarn_function, render: 1}
  def render(state) do
    dsl_result =
      View.column style: %{border: :single, padding: 1} do
        # Form Title (optional)
        if state.title do
          View.text(state.title, style: %{bold: true, align: :center})
        end

        # Render form fields
        Enum.each(state.fields, fn field -> render_field(field, state) end)

        # Render error message (if any)
        if state.error do
          View.text(state.error, style: %{color: :red})
        end

        # Render submit button
        View.button(
          [style: %{margin_top: 1}, on_click: :submit],
          state.submit_label
        )
      end

    Raxol.View.to_element(dsl_result)
  end

  defp render_field(field, _state) do
    case field.module.render(field.state) do
      %Element{content: content} when not is_nil(content) ->
        View.text(content, style: %{bold: true})

      %Element{} = element ->
        View.text(element |> Map.get(:content, ""), style: %{bold: true})

      _ ->
        ""
    end
  end
end
