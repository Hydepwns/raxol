defmodule Raxol.Examples.TableDemo do
  @moduledoc """
  Demonstrates the Table component using the Application behaviour.
  """

  # Add Application behaviour and required aliases/requires
  use Raxol.Core.Runtime.Application
  require Logger
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI

  # Define application state
  defstruct table_data: [],
            table_columns: [],
            message: "Table Demo"

  # Sample Data
  @sample_columns [
    %{header: "ID", key: :id, width: 5},
    %{header: "Name", key: :name, width: 20},
    %{header: "Role", key: :role, width: 15},
    %{header: "Status", key: :status, width: 10}
  ]

  @sample_data [
    %{id: 1, name: "Alice Wonderland", role: "Developer", status: "Active"},
    %{id: 2, name: "Bob The Builder", role: "Designer", status: "Active"},
    %{id: 3, name: "Charlie Chaplin", role: "Manager", status: "Inactive"},
    %{id: 4, name: "Diana Prince", role: "Tester", status: "Active"},
    %{id: 5, name: "Ethan Hunt", role: "Developer", status: "On Leave"}
  ]

  # --- Application Lifecycle ---

  @doc """
  Starts the Table Demo application.
  """
  def run do
    Logger.info("Starting Table Demo Application...")
    Raxol.Core.Runtime.Lifecycle.start_application(__MODULE__, %{})
  end

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    Logger.info("Initializing Table Demo...")
    # Initialize with sample data
    initial_state = %__MODULE__{
      table_columns: @sample_columns,
      table_data: @sample_data,
      message: "Simple Table Example"
    }
    {:ok, initial_state}
  end

  # --- Application Behaviour Callbacks ---

  @impl Raxol.Core.Runtime.Application
  def view(state) do
    # Render the view with the table
    UI.box padding: 1 do
      UI.column spacing: 1 do
        [
          UI.label(content: state.message),
          UI.table(
            id: :demo_table,
            columns: state.table_columns,
            data: state.table_data,
            # Optional: Add other attributes like :height, :width, :style
            height: 10 # Example height
          )
        ]
      end
    end
  end

  # Add default implementations for other callbacks
  @impl Raxol.Core.Runtime.Application
  def update(msg, state) do
    Logger.debug("Unhandled update: #{inspect msg}")
    {:noreply, state}
  end

  def handle_event(event, state) do
    Logger.debug("TableDemo received unhandled event (handle_event/2): #{inspect event}")
    {:noreply, state}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    Logger.debug("TableDemo received unhandled event (handle_event/1): #{inspect event}")
    [] # Return empty list of commands
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(msg, state) do
    Logger.debug("Unhandled handle_message: #{inspect msg}")
    {:noreply, state}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(state) do
    {:noreply, state}
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state), do: []

  @impl Raxol.Core.Runtime.Application
  def terminate(reason, _state) do
    Logger.info("Terminating Table Demo: #{inspect reason}")
    :ok
  end

end
