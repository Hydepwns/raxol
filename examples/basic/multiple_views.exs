# An example of how to implement navigation between multiple views.
#
# Run this example with:
#
#   mix run examples/multiple_views.exs

defmodule MultipleViewsDemo do
  @behaviour Raxol.App
  use Raxol.View

  def init(_context), do: %{selected_tab: 1}

  def update(model, msg) do
    case msg do
      {:event, %{type: :key, key: key}} when key in [?1, ?2, ?3] ->
        %{model | selected_tab: key - ?0}

      _ ->
        model
    end
  end

  def render(model) do
    view do
      case model.selected_tab do
        1 -> panel [title: "View 1", height: :fill], do: nil
        2 -> panel [title: "View 2", height: :fill], do: nil
        3 -> panel [title: "View 3", height: :fill], do: nil
      end
    end
  end

  defp title_bar do
    row do
      text(content: "Multiple Views Demo (Press 1, 2 or 3, or q to quit)")
    end
  end

  defp status_bar(selected_tab) do
    row do
      text(content: "Selected: #{selected_tab}")
    end
  end
end

Raxol.run(
  MultipleViewsDemo,
  quit_keys: [?q]
)


