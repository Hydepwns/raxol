# Event Handling
#
# Demonstrates handling keyboard events, button clicks, and text input.
#
# Usage:
#   mix run examples/scripts/event_handling.exs

defmodule EventHandlingExample do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @impl true
  def init(_context) do
    %{count: 0, text_value: "", last_key: "none"}
  end

  @impl true
  def update(message, model) do
    case message do
      :increment ->
        {%{model | count: model.count + 1}, []}

      :decrement ->
        {%{model | count: model.count - 1}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}} when is_binary(ch) ->
        {%{model | last_key: ch}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: key}} ->
        {%{model | last_key: inspect(key)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{padding: 1, gap: 1} do
      [
        text("Event Handling Demo", style: [:bold]),
        box title: "Counter", style: %{border: :single, padding: 1} do
          column style: %{gap: 1} do
            [
              text("Count: #{model.count}"),
              row style: %{gap: 1} do
                [
                  button("Increment (+)", on_click: :increment),
                  button("Decrement (-)", on_click: :decrement)
                ]
              end
            ]
          end
        end,
        box title: "Last Key Pressed", style: %{border: :single, padding: 1} do
          text("Key: #{model.last_key}")
        end,
        text("Press 'q' or Ctrl+C to quit.")
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

Raxol.Core.Runtime.Log.info("EventHandlingExample: Starting...")
{:ok, pid} = Raxol.start_link(EventHandlingExample, [])
ref = Process.monitor(pid)
receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
