# Hello World
#
# The simplest Raxol application: display a message and quit on 'q'.
#
# Usage:
#   mix run examples/getting_started/hello_world.exs

defmodule HelloWorld do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @impl true
  def init(_context) do
    %{message: "Hello, World!"}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

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
    column style: %{padding: 2, gap: 1, align_items: :center} do
      [
        box style: %{
              border: :single,
              padding: 1,
              width: 30,
              justify_content: :center
            } do
          text(model.message, style: [:bold])
        end,
        text("Press 'q' to quit.")
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

Raxol.Core.Runtime.Log.info("HelloWorld: Starting...")
{:ok, pid} = Raxol.start_link(HelloWorld, [])
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
