# This is an example of how to use commands to perform expensive work in the
# background and receive the results via `update/2`.
#
# Run this example with:
#
#   mix run examples/commands.exs

defmodule Commands do
  @behaviour Raxol.App
  use Raxol.View

  alias Raxol.Runtime.Command

  def init(_context), do: %{commands: %{}, next_id: 0, executed_commands: []}

  def update(%{commands: commands, next_id: id} = model, msg) do
    case msg do
      {:event, %{ch: ?t}} ->
        new_model = %{
          model
          | commands: Map.put(commands, id, {:processing, nil}),
            next_id: id + 1
        }

        {new_model, Command.new(&process/0, {id, :finished})}

      {{id, :finished}, result} ->
        %{model | commands: Map.put(commands, id, {:finished, result})}

      _ ->
        model
    end
  end

  defp process do
    # We'll pretend like this is a very expensive call.
    Process.sleep(3_000)
    Enum.random(1..10_000)
  end

  def render(%{commands: commands}) do
    view do
      panel(title: "Press 't' repeatedly to start asynchronous commands") do
        # Comment out first table as well
        # table do
        #   table_row do
        #     table_cell(content: "Command ID")
        #     table_cell(content: "Status")
        #     table_cell(content: "Result")
        #   end
        #
        #   for {id, status, result} <- Enum.map(Map.values(model.commands), & &1) do
        #     table_row do
        #       table_cell(content: to_string(id))
        #       table_cell(content: to_string(status))
        #       table_cell(content: to_string(result))
        #     end
        #   end
        # end
        text(content: "[Active commands table placeholder]")
      end

      panel title: "Executed Commands" do
        # Table components need implementation - comment out for now
        # table headers: ["Command", "Result"] do
        #   Enum.map(executed_commands, fn {command, result} ->
        #     table_row do
        #       table_cell(content: command)
        #       table_cell(content: result)
        #     end
        #   end)
        # end
        text(content: "[Executed commands table placeholder]")
      end
    end
  end
end

Raxol.run(Commands)
