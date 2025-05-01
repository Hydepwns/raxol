# An example of how to implement navigation between multiple views.
#
# Usage:
#   elixir examples/snippets/basic/multiple_views.exs

defmodule MultipleViewsDemo do
  # Use the correct Application behaviour and View DSL
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  require Logger

  @impl true
  def init(_context) do
    Logger.debug("MultipleViewsDemo: init/1")
    # Return :ok tuple
    {:ok, %{selected_tab: 1}}
  end

  @impl true
  def update(message, model) do
    Logger.debug("MultipleViewsDemo: update/2 received message: \#{inspect(message)}")
    case message do
      # Use Event struct for key presses
      %Event{type: :key, data: %{key: :char, char: key_char}} when key_char in ["1", "2", "3"] ->
        # Return :ok tuple
        {:ok, %{model | selected_tab: String.to_integer(key_char)}, []}

      # Handle quit keys
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}
      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      _ ->
        # Return :ok tuple
        {:ok, model, []}
    end
  end

  # Renamed from render/1
  @impl true
  def view(model) do
    Logger.debug("MultipleViewsDemo: view/1")
    view do
      # Use Elements DSL (box, column, text)
      column style: %{gap: 1, padding: 1} do
        title_bar()
        box style: [[:border, :single], [:height, :fill], [:width, :fill]] do
          case model.selected_tab do
            1 -> box(title: "View 1", style: %{padding: 1}, content: "Content for View 1")
            2 -> box(title: "View 2", style: %{padding: 1}, content: "Content for View 2")
            3 -> box(title: "View 3", style: %{padding: 1}, content: "Content for View 3")
          end
        end
        status_bar(model.selected_tab)
      end
    end
  end

  defp title_bar do
    box style: %{width: :fill, padding: [0, 1]} do
      text(content: "Multiple Views Demo (Press 1, 2 or 3, or q/Ctrl+C to quit)")
    end
  end

  defp status_bar(selected_tab) do
    box style: %{width: :fill, padding: [0, 1]} do
      text(content: "Selected: \#{selected_tab}")
    end
  end
end

Logger.info("MultipleViewsDemo: Starting Raxol...")
# Use standard startup
{:ok, _pid} = Raxol.start_link(MultipleViewsDemo, [])
Logger.info("MultipleViewsDemo: Raxol started. Running...")

Process.sleep(:infinity)
