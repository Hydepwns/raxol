# Counter Example
#
# A simple counter application demonstrating Raxol basics.
#
# Usage:
#   mix run examples/getting_started/counter.exs

defmodule CounterExample do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @impl true
  def init(_context) do
    Raxol.Core.Runtime.Log.debug("CounterExample: init/1")
    %{count: 0}
  end

  @impl true
  def update(message, model) do
    Raxol.Core.Runtime.Log.debug(
      "CounterExample: update/2 received message: #{inspect(message)}"
    )

    case message do
      :increment ->
        {%{model | count: model.count + 1}, []}

      :decrement ->
        {%{model | count: model.count - 1}, []}

      :reset ->
        {%{model | count: 0}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "+"}} ->
        {%{model | count: model.count + 1}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "-"}} ->
        {%{model | count: model.count - 1}, []}

      %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      } ->
        {model, [command(:quit)]}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    Raxol.Core.Runtime.Log.debug("CounterExample: view/1")

    column style: %{padding: 1, gap: 1, align_items: :center} do
      [
        text("Counter Example", style: [:bold]),
        box style: %{
              padding: 1,
              border: :single,
              width: 20,
              justify_content: :center
            } do
          text("Count: #{model.count}", style: [:bold])
        end,
        row style: %{gap: 1} do
          [
            button("Increment (+)", on_click: :increment),
            button("Reset", on_click: :reset),
            button("Decrement (-)", on_click: :decrement)
          ]
        end,
        text("Press '+' or '-' keys, or click buttons."),
        text("Press 'q' or Ctrl+C to quit")
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    []
  end
end

Raxol.Core.Runtime.Log.info("CounterExample: Starting Raxol...")
{:ok, pid} = Raxol.start_link(CounterExample, [])
Raxol.Core.Runtime.Log.info("CounterExample: Raxol started. Running...")

# Keep the script alive until the application process exits
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
