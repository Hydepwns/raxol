#!/usr/bin/env elixir

# Simple script to run the ComponentShowcase example directly.

example_module = Raxol.Examples.ComponentShowcase
opts = []

IO.puts("Starting #{inspect(example_module)}...")

Raxol.run(example_module, opts)

# Keep the script alive until Raxol exits or is stopped
Process.sleep(:infinity)

IO.puts("Showcase finished.")
