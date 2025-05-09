#!/usr/bin/env elixir
# Minimal Table Component Test

IO.puts "SCRIPT_START: table_test.exs beginning execution."

defmodule TableTest do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements
  require Logger

  @impl true
  def init(_context) do
    Logger.info("TableTest: init/1 starting...")
    {:ok,
     %{
       table_data: [
         %{id: 1, name: "Alice", role: "Admin", status: "Active"},
         %{id: 2, name: "Bob", role: "User", status: "Inactive"},
         %{id: 3, name: "Charlie", role: "User", status: "Active"},
         %{id: 4, name: "David", role: "Moderator", status: "Active"}
       ]
     }}
  end

  @impl true
  def update(_message, model) do
    Logger.debug("TableTest: update/2 called")
    # No updates needed for this minimal test
    {:ok, model, []}
  end

  @impl true
  def view(model) do
    Logger.info("TableTest: view/1 starting...")
    view do # Wrap in top-level view
      column style: %{padding: 1, gap: 1} do
        label(content: "Table Test:", style: [:bold])
        table(
          id: :my_table,
          data: model.table_data,
          columns: [
            %{header: "ID", key: :id, width: 5},
            %{header: "Name", key: :name, width: 15},
            %{header: "Role", key: :role, width: 15},
            %{header: "Status", key: :status, width: 10}
          ],
          style: [[:width, 50], [:height, 6], [:border, :single]]
        )
        text(content: "Press Ctrl+C to exit", style: %{margin_top: 1})
      end
    end
  end
end

Logger.info("TableTest: Starting Raxol.start_link...")
# Start the Raxol application
{:ok, _pid} = Raxol.start_link(TableTest, [])
Logger.info("TableTest: Raxol.start_link completed. Entering sleep.")
