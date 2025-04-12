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

  def init(props) do
    state = %{
      title: Map.get(props, :title, "Sample Form"),
      submitted: false,
      children: [],
      error: nil
    }

    {:ok, state}
  end

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

  def render(state) do
    content = render_content(state)

    %Element{
      tag: :form,
      content: content,
      style: %{
        fg: :white,
        bg: :black
      },
      attributes: %{
        submitted: state.submitted,
        error: state.error
      }
    }
  end

  # Private Helpers

  defp render_content(state) do
    [
      render_title(state),
      render_error(state),
      render_children(state),
      render_status(state)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp render_title(state) do
    "=== #{state.title} ==="
  end

  defp render_error(%{error: nil}), do: nil

  defp render_error(%{error: error}) do
    "[ERROR] #{error}"
  end

  defp render_children(state) do
    state.children
    |> Enum.map(&render_child/1)
    |> Enum.join("\n")
  end

  defp render_child(child) do
    case child.module.render(child.state) do
      %Element{content: content} when not is_nil(content) ->
        "  " <> content

      %Element{} = element ->
        "  " <> (element |> Map.get(:content, ""))

      _ ->
        ""
    end
  end

  defp render_status(%{submitted: true}) do
    "Status: Submitted"
  end

  defp render_status(_) do
    "Status: Not submitted"
  end
end
