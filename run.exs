# Ensure Raxol and dependencies are compiled and available
Mix.Task.run("compile", [])

# Start the Raxol application
Raxol.Runtime.run(Raxol.MyApp)

# Keep the main process alive to allow the GenServer to run
# The Runtime GenServer will handle shutdown via quit keys or errors
Process.sleep(:infinity)
