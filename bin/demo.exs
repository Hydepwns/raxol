#!/usr/bin/env elixir
IO.puts("[bin/demo.exs] Script started!")

# This script launches a Raxol Example Application
# You can run it with: mix run bin/demo.exs

# TODO: Make the example module configurable via command line arguments
# Changed back for testing
example_module = Raxol.Examples.IntegratedAccessibilityDemo
IO.puts("[bin/demo.exs] Example module set to: #{inspect(example_module)}")

# Add the lib directory to the code path - Handled by `mix run`
# Code.prepend_path("_build/dev/lib/raxol/ebin")

# Ensure all dependencies are loaded - Handled by `mix run`
# Application.ensure_all_started(:raxol)

# Print welcome message (Optional, Raxol app should take over immediately)
# IO.puts """
# ========================================================
#   Raxol Demo Runner
# ========================================================
#
# Launching: #{inspect example_module}
# """

# Wait for key press - Removed, Raxol takes over terminal
# IO.gets("")

# Start the Raxol runtime with the specified example application
opts = [application_module: example_module]

IO.puts("[bin/demo.exs] Attempting to start Raxol with opts: #{inspect(opts)}")

# {:ok, _pid} = Raxol.start_link(opts) # Temporarily commented out
IO.puts("[bin/demo.exs] Raxol.start_link would be called here.")

# Keep the script running until Raxol exits (or manually stopped)
# Process.sleep(:infinity) # Temporarily commented out
IO.puts("[bin/demo.exs] Script finished.")
