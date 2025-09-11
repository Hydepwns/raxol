# examples/showcase_app.ex
#
# This application module serves as a simple wrapper to run the
# ComponentShowcase component example.
#
# Run with: mix run examples/showcase_app.ex

defmodule ShowcaseApp do
  use Raxol.Core.Runtime.Application

  # Import the component we want to render
  # Make sure the path to the component is correct
  require Raxol.Examples.ComponentShowcase

  # Needed if using <.component_showcase /> syntax, requires ComponentShowcase to `use Surface.Component` or similar
  import Raxol.Examples.ComponentShowcase

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    # No specific state needed for this simple wrapper
    initial_model = %{}
    # Return initial model and empty command list
    {:ok, initial_model, []}
  end

  # handle_event and update can be minimal if the showcase component handles its own events internally
  # Or pass events down if needed

  @impl Raxol.Core.Runtime.Application
  def update(message, model) do
    # For now, ignore any messages at the app level
    {:ok, model, []}
  end

  @impl Raxol.Core.Runtime.Application
  def view(_model) do
    # Return a map structure representing the ComponentShowcase component.
    # We hypothesize that the rendering engine/layout engine knows how to
    # find the component process associated with this type/ID, call its
    # render function with its current state (assigns), and integrate
    # the result into the layout.
    %{type: Raxol.Examples.ComponentShowcase, id: :showcase_root, assigns: %{}}
  end

  # Optional: Define subscriptions if the wrapper needs to react to anything
  # def subscriptions(model), do: []
end

# --- Script Entry Point ---
# Start the Raxol runtime with this ShowcaseApp module
IO.puts("[examples/showcase_app.ex] Starting Raxol with ShowcaseApp...")
# {:ok, _pid} = Raxol.start_link([application_module: ShowcaseApp])
# Use run/2 which might block
Raxol.run(ShowcaseApp, [])

# Keep the script alive (Raxol.run might handle this)
IO.puts("[examples/showcase_app.ex] Raxol finished or script exiting.")
