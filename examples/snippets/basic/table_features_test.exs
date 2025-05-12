# This example demonstrates the Raxol.UI.Components.Data.Table component.
defmodule Raxol.Docs.Guides.Examples.Basic.TableFeaturesTest do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  defmodule State do
    defstruct table_data: [],
              selected_row: nil
  end

  @impl true
  def init(_opts) do
    initial_data = [
      %{id: 1, name: "Alice", email: "alice@example.com", role: "Admin"},
      %{id: 2, name: "Bob", email: "bob@example.com", role: "User"},
      %{id: 3, name: "Charlie", email: "charlie@example.com", role: "User"},
      %{id: 4, name: "Diana", email: "diana@example.com", role: "Moderator"}
    ]
    %State{table_data: initial_data}
  end

  @impl true
  def update(message, model) do
    case message do
      # Handle the :on_row_click event from the table
      # Assumes the table sends {:row_clicked, row_data}
      {:row_clicked, row_data} ->
        IO.inspect(row_data, label: "Row clicked")
        %State{model | selected_row: row_data}

      _ ->
        IO.inspect(message, label: "Unhandled message")
        model
    end
  end

  @impl true
  def view(model = %State{}) do
    table_columns = [
      %{id: :id, label: "ID", width: 50}, # Optional width
      %{id: :name, label: "Name"},
      %{id: :email, label: "Email"},
      %{id: :role, label: "Role"}
    ]

    view do
      column(gap: 20, padding: 15) do
        text(content: "Table with Clickable Rows", style: "font-size: 1.3em; font-weight: bold;")

        table(
          columns: table_columns,
          data: model.table_data,
          row_key: :id, # Use the :id field as the unique key for rows
          on_row_click: {:row_clicked}, # Send {:row_clicked, row_data}
          style: "width: 500px; border-collapse: collapse;" # Example styling
          # Add other potential props like selectable: true, if supported
        )

        # Display selected row info
        panel(title: "Selected User Info", style: "margin-top: 20px; width: 500px;") do
          if model.selected_row do
            column(gap: 5) do
              text(content: "ID: #{model.selected_row.id}")
              text(content: "Name: #{model.selected_row.name}")
              text(content: "Email: #{model.selected_row.email}")
              text(content: "Role: #{model.selected_row.role}")
            end
          else
            text(content: "Click a row in the table to see details here.")
          end
        end
      end
    end
  end

  # Function to run the example directly
  def main do
    Raxol.start_link(__MODULE__, [])
    # For CI/test/demo: sleep for 2 seconds, then exit. Adjust as needed.
    Process.sleep(2000)
  end
end

# To run this example: mix run -e "Raxol.Docs.Guides.Examples.Basic.TableFeaturesTest.main()"
# (Assuming Raxol is a dependency or mix project is set up)
