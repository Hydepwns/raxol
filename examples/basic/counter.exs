# Counter Example
#
# A simple counter application demonstrating Raxol basics.
#
# Run with:
#   elixir examples/basic/counter.exs

defmodule CounterExample do
  # Use the explicit Application behaviour
  @behaviour Raxol.Core.Runtime.Application

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  require Event

  @impl Raxol.Core.Runtime.Application
  def init(_app_module, _context) do
    # Initial state
    {:ok, %{count: 0}}
  end

  @impl Raxol.Core.Runtime.Application
  def update(model, event) do
    case event do
      # Handle internal button click messages (assuming they are sent directly)
      # NOTE: This might need adjustment based on how button clicks are actually dispatched.
      # If buttons send {:click, message}, we match that.
      # If they send the message directly via context, we match the atom.
      :increment ->
        {%{model | count: model.count + 1}, []} # Return model and commands

      :decrement ->
        {%{model | count: model.count - 1}, []}

      :reset ->
        {%{model | count: 0}, []}

      # Handle direct key presses from TerminalDriver
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [Command.new(:quit)]} # Command to quit the application

      %Event{type: :key, data: %{key: :char, char: "+"}} -> # Example: '+' key increments
        {%{model | count: model.count + 1}, []}

      %Event{type: :key, data: %{key: :char, char: "-"}} -> # Example: '-' key decrements
        {%{model | count: model.count - 1}, []}

      # Handle Ctrl+C from TerminalDriver
      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {model, [Command.new(:quit)]}

      # Ignore other events
      _ ->
        {model, []}
    end
  end

  # Renamed from render/1 to view/1
  @impl Raxol.Core.Runtime.Application
  def view(model) do
    # Use Raxol.UI.Element shorthands or full specs
    # Assuming a hypothetical View DSL or direct element construction
    # This part heavily depends on the actual UI/Component library structure
    # Let's use a simplified structure for now:
    alias Raxol.UI.Element

    Element.new(:panel, title: "Counter Example", children: [
      Element.new(:row, children: [
        Element.new(:column, size: 12, children: [
          Element.new(:label, content: "Count: #{model.count}")
        ])
      ]),
      Element.new(:row, children: [
        Element.new(:column, size: 4, children: [
          # TODO: Update button component usage based on actual implementation
          # Need to know how :on_click translates to commands/messages
          Element.new(:button, label: "Increment (+)", on_click: :increment)
        ]),
        Element.new(:column, size: 4, children: [
          Element.new(:button, label: "Reset", on_click: :reset)
        ]),
        Element.new(:column, size: 4, children: [
          Element.new(:button, label: "Decrement (-)", on_click: :decrement)
        ])
      ]),
      Element.new(:row, children: [
        Element.new(:column, size: 12, children: [
          Element.new(:label, content: "Press 'q' or Ctrl+C to quit")
        ])
      ])
    ])
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_model) do
    # No subscriptions needed for this simple example
    []
  end
end

# Run the example using the new Runtime entry point
Raxol.Runtime.start_application(CounterExample)
