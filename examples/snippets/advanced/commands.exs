# This is an example of how to use commands to perform expensive work in the
# background and receive the results via `update/2`.
#
# Usage:
#   elixir examples/snippets/advanced/commands.exs

defmodule CommandsExample do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Commands.Command
  alias Raxol.Core.Events.Event
  require Logger

  @impl true
  def init(_context) do
    Logger.debug("CommandsExample: init/1")
    {:ok, %{commands: %{}, next_id: 0, executed_commands: []}}
  end

  @impl true
  def update(message, %{commands: commands, next_id: id} = model) do
    Logger.debug("CommandsExample: update/2 received message: \#{inspect(message)}")
    case message do
      %Event{type: :key, data: %{key: :char, char: "t"}} ->
        Logger.info("CommandsExample: Starting command \#{id}")
        new_model = %{
          model
          | commands: Map.put(commands, id, {:processing, nil}),
            next_id: id + 1
        }
        command = Command.new(&process/0, {:finished, id})
        {:ok, new_model, [command]}

      {:command_result, {:finished, id}, result} ->
        Logger.info("CommandsExample: Command \#{id} finished with result: \#{result}")
        new_commands = Map.put(commands, id, {:finished, result})
        new_executed = [{id, result} | model.executed_commands]
        trimmed_executed = Enum.take(new_executed, 10)
        new_model = %{model | commands: new_commands, executed_commands: trimmed_executed}
        {:ok, new_model, []}

      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}
      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      _ ->
        {:ok, model, []}
    end
  end

  defp process do
    Logger.debug("CommandsExample: process/0 running...")
    Process.sleep(3000)
    result = Enum.random(1..10_000)
    Logger.debug("CommandsExample: process/0 finished with \#{result}")
    result
  end

  @impl true
  def view(%{commands: commands, executed_commands: executed_commands} = model) do
    Logger.debug("CommandsExample: view/1")

    active_commands_data = for {id, {status, result}} <- commands, status == :processing, do: %{id: id, status: status, result: result || "N/A"}
    finished_commands_data = for {id, {_status, result}} <- commands, not is_nil(result), do: %{id: id, result: result}

    view do
      column style: %{gap: 1} do
        box(title: "Press 't' repeatedly to start asynchronous commands (q/Ctrl+C to Quit)", style: [[:border, :single], [:padding, 1]]) do
          table(
            id: :active_commands,
            data: active_commands_data ++ finished_commands_data,
            columns: [
              %{header: "ID", key: :id, width: 10},
              %{header: "Status", key: :status, width: 15},
              %{header: "Result", key: :result, width: 15}
            ],
            style: [[:height, 8], [:width, :fill]]
          )
        end

        box(title: "Recently Executed Commands (Last 10)", style: [[:border, :single], [:padding, 1]]) do
          executed_data = Enum.map(executed_commands, fn {id, result} -> %{id: id, result: result} end)
          table(
            id: :executed_commands,
            data: executed_data,
            columns: [
              %{header: "Command ID", key: :id, width: 15},
              %{header: "Result", key: :result, width: 15}
            ],
            style: [[:height, 12], [:width, :fill]]
          )
        end
      end
    end
  end
end

Logger.info("CommandsExample: Starting Raxol...")
{:ok, _pid} = Raxol.start_link(CommandsExample, [])
Logger.info("CommandsExample: Raxol started. Running...")

Process.sleep(:infinity)
