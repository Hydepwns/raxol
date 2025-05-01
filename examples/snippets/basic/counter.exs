# Counter Example
#
# A simple counter application demonstrating Raxol basics.
#
# Usage:
#   elixir examples/snippets/basic/counter.exs

defmodule CounterExample do
  # Use the Application behaviour via `use`
  use Raxol.Core.Runtime.Application

  # Import the View DSL elements
  import Raxol.View.Elements

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  require Logger # Added for consistency, though not used here yet

  @impl true
  def init(_context) do
    # Initial state
    Logger.debug("CounterExample: init/1")
    {:ok, %{count: 0}}
  end

  @impl true
  def update(message, model) do
    Logger.debug("CounterExample: update/2 received message: \#{inspect(message)}")
    case message do
      # Handle internal button click messages
      :increment ->
        {:ok, %{model | count: model.count + 1}, []} # Return :ok, model, commands

      :decrement ->
        {:ok, %{model | count: model.count - 1}, []}

      :reset ->
        {:ok, %{model | count: 0}, []}

      # Handle direct key presses from TerminalDriver
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]} # Command to quit the application

      %Event{type: :key, data: %{key: :char, char: "+"}} -> # Example: '+' key increments
        {:ok, %{model | count: model.count + 1}, []}

      %Event{type: :key, data: %{key: :char, char: "-"}} -> # Example: '-' key decrements
        {:ok, %{model | count: model.count - 1}, []}

      # Handle Ctrl+C from TerminalDriver
      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      # Ignore other events
      _ ->
        {:ok, model, []} # Always return :ok tuple
    end
  end

  @impl true
  def view(model) do
    Logger.debug("CounterExample: view/1")
    # Use the Raxol.View.Elements DSL
    view do
      column style: %{padding: 1, gap: 1, align_items: :center} do
        text(content: "Counter Example", style: [:bold])
        box style: %{padding: 1, border: :single, width: 20, justify_content: :center} do
          text(content: "Count: \#{model.count}", style: [:bold])
        end
        row style: %{gap: 1} do
            # Buttons send their message on click
            button(label: "Increment (+)", message: :increment)
            button(label: "Reset", message: :reset)
            button(label: "Decrement (-)", message: :decrement)
        end
        text(content: "Press '+' or '-' keys, or click buttons.", style: %{margin_top: 1})
        text(content: "Press 'q' or Ctrl+C to quit")
      end
    end
  end

  # Subscriptions are optional, default implementation provided by `use`
  # @impl true
  # def subscriptions(_model) do
  #   []
  # end
end

Logger.info("CounterExample: Starting Raxol...")
# Run the example using the standard start_link for scripts
{:ok, _pid} = Raxol.start_link(CounterExample, [])
Logger.info("CounterExample: Raxol started. Running...")

# Keep the script alive
Process.sleep(:infinity)
