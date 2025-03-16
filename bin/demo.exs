#!/usr/bin/env elixir

# This script launches the Raxol Integrated Accessibility Demo
# You can run it with: elixir bin/demo.exs

# Add the lib directory to the code path
Code.prepend_path("_build/dev/lib/raxol/ebin")

# Ensure all dependencies are loaded
Application.ensure_all_started(:raxol)

# Print welcome message
IO.puts """
========================================================
  Raxol Integrated Accessibility Demo
========================================================

This demo showcases how accessibility features work
together with the color system, animation framework,
and internationalization in the Raxol framework.

Press any key to start...
"""

# Wait for key press
IO.gets("")

# Run the demo
Raxol.Examples.IntegratedAccessibilityDemo.run() 