# Ensure Raxol and dependencies are compiled and available
Mix.Task.run("compile", [])

# Start the Raxol application and its supervision tree
Application.ensure_all_started(:raxol)

require Logger

alias Raxol.Core.Runtime.Lifecycle

# Start the Raxol application using the new Lifecycle module
Logger.info("Starting Raxol application: Raxol.MyApp")
Lifecycle.start_application(Raxol.MyApp)

# Keep the main process alive to allow the GenServer to run
# The Runtime GenServer will handle shutdown via quit keys or errors
Process.sleep(:infinity)
