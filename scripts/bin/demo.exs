#!/usr/bin/env elixir
IO.puts("[bin/demo.exs] Script started!")

# This script launches a Raxol Example Application
# You can run it with: mix run bin/demo.exs

# --- Demo Configuration ---

@demos %{
  # Map keys to example modules
  form: Raxol.Examples.Form,
  ux_refinement: Raxol.Examples.UXRefinementDemo,
  accessibility: Raxol.Examples.AccessibilityDemo,
  color_system: Raxol.Examples.ColorSystemDemo,
  table: Raxol.Examples.TableDemo,
  # WIP
  integrated_accessibility: Raxol.Examples.IntegratedAccessibilityDemo,
  keyboard_shortcuts: Raxol.Examples.KeyboardShortcutsDemo
}

@descriptions %{
  form: "Simple form example.",
  ux_refinement: "Showcases focus, hints, etc.",
  accessibility: "Demonstrates various accessibility features.",
  color_system: "Demonstrates the color system.",
  table: "Demonstrates the Table component.",
  integrated_accessibility: "Integrated accessibility features (WIP).",
  keyboard_shortcuts: "Demonstrates keyboard shortcut handling."
}

# --- Menu Logic ---

defmodule DemoRunner do
  require IO

  def display_menu_and_get_choice(demos, descriptions) do
    IO.puts("""
    ========================================================
      Raxol Demo Runner - Select an Example
    ========================================================
    """)

    # Create an indexed list for selection
    indexed_demos = Enum.with_index(Map.to_list(demos), 1)

    # Display options
    Enum.each(indexed_demos, fn {{key, _module}, index} ->
      description = Map.get(descriptions, key, "No description available.")
      IO.puts("  #{index}. #{key} - #{description}")
    end)

    IO.puts("=======================================================")

    # Get user choice
    max_index = length(indexed_demos)
    prompt_for_choice(indexed_demos, max_index)
  end

  defp prompt_for_choice(indexed_demos, max_index) do
    case IO.gets("Enter the number of the demo to run (1-#{max_index}): ") do
      {:error, reason} ->
        IO.puts("Error reading input: #{reason}. Exiting.")
        System.halt(1)

      :eof ->
        IO.puts("\nExiting.")
        System.halt(0)

      {:ok, input} ->
        case Integer.parse(String.trim(input)) do
          {index, ""} when index >= 1 and index <= max_index ->
            # Valid choice, find the corresponding demo
            {_key, module} =
              Enum.find(indexed_demos, fn {_demo, i} -> i == index end)
              |> elem(0)

            # Return the selected module
            module

          _ ->
            IO.puts(
              "Invalid selection. Please enter a number between 1 and #{max_index}."
            )

            # Retry
            prompt_for_choice(indexed_demos, max_index)
        end
    end
  end
end

# --- Main Script Logic ---

# Get the selected example module from the user
example_module = DemoRunner.display_menu_and_get_choice(@demos, @descriptions)

# TODO: Make the example module configurable via command line arguments
# Changed back for testing
# example_module = Raxol.Examples.IntegratedAccessibilityDemo
IO.puts("[bin/demo.exs] Example module selected: #{inspect(example_module)}")

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

# {:ok, _pid} = Raxol.start_link(opts) # Change to use Raxol.run/2
Raxol.run(example_module, opts)

# Keep the script running until Raxol exits (or manually stopped)
# Temporarily commented out -> Uncommented
IO.puts("[bin/demo.exs] Script finished.")
