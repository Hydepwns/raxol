#!/usr/bin/env elixir

defmodule ReplaceWithRefactored do
  @moduledoc """
  Script to replace original modules with their refactored GenServer implementations.
  """

  @replacements [
    {"lib/raxol/core/focus_manager.ex",
     "lib/raxol/core/focus_manager_refactored.ex"},
    {"lib/raxol/core/accessibility.ex",
     "lib/raxol/core/accessibility_refactored.ex"},
    {"lib/raxol/core/keyboard_navigator.ex",
     "lib/raxol/core/keyboard_navigator_refactored.ex"},
    {"lib/raxol/core/keyboard_shortcuts.ex",
     "lib/raxol/core/keyboard_shortcuts_refactored.ex"},
    {"lib/raxol/core/events/manager.ex",
     "lib/raxol/core/events/manager_refactored.ex"},
    {"lib/raxol/core/performance/optimizer.ex",
     "lib/raxol/core/performance/optimizer_refactored.ex"},
    {"lib/raxol/core/ux_refinement.ex",
     "lib/raxol/core/ux_refinement_refactored.ex"},
    {"lib/raxol/core/i18n.ex", "lib/raxol/core/i18n_refactored.ex"},
    {"lib/raxol/ui/state/store.ex", "lib/raxol/ui/state/store_refactored.ex"},
    {"lib/raxol/ui/state/hooks.ex", "lib/raxol/ui/state/hooks_refactored.ex"},
    {"lib/raxol/animation/state_manager.ex",
     "lib/raxol/animation/state_manager_refactored.ex"},
    {"lib/raxol/animation/gestures.ex",
     "lib/raxol/animation/gestures_refactored.ex"},
    {"lib/raxol/terminal/window/manager.ex",
     "lib/raxol/terminal/window/manager_refactored.ex"},
    {"lib/raxol/svelte/slots.ex", "lib/raxol/svelte/slots_refactored.ex"},
    {"lib/raxol/security/user_context.ex",
     "lib/raxol/security/user_context_refactored.ex"}
  ]

  def run(mode \\ :dry_run) do
    IO.puts("\n🔄 Replacing Original Modules with Refactored Versions")
    IO.puts("=" |> String.duplicate(60))

    case mode do
      :dry_run ->
        IO.puts("\n🔍 DRY RUN - No files will be modified")
        Enum.each(@replacements, &analyze_replacement/1)

      :apply ->
        IO.puts("\n⚠️  APPLYING REPLACEMENTS - Files will be replaced!")
        IO.puts("Press Enter to continue or Ctrl+C to abort...")
        IO.gets("")

        Enum.each(@replacements, &apply_replacement/1)

        IO.puts("\n✅ Replacement complete!")
        IO.puts("\nNext steps:")
        IO.puts("1. Update module names in refactored files")
        IO.puts("2. Run tests: mix test")
        IO.puts("3. Check Process dictionary: rg 'Process\\.(get|put)' lib/")
    end
  end

  defp analyze_replacement({target, source}) do
    cond do
      not File.exists?(source) ->
        IO.puts("❌ Missing source: #{source}")

      not File.exists?(target) ->
        IO.puts("❌ Missing target: #{target}")

      true ->
        source_size = File.stat!(source).size
        target_size = File.stat!(target).size

        IO.puts(
          "✅ #{target} ← #{source} (#{source_size} bytes → #{target_size} bytes)"
        )
    end
  end

  defp apply_replacement({target, source}) do
    cond do
      not File.exists?(source) ->
        IO.puts("❌ Skipping #{target}: source #{source} not found")

      not File.exists?(target) ->
        IO.puts("❌ Skipping #{target}: target not found")

      true ->
        # Read the refactored content
        refactored_content = File.read!(source)

        # Fix the module name to match the target
        original_module = target_to_module_name(target)
        refactored_module = source_to_module_name(source)

        fixed_content =
          String.replace(refactored_content, refactored_module, original_module)

        # Write to target
        File.write!(target, fixed_content)

        IO.puts("✅ Replaced: #{target}")
        IO.puts("   Module: #{refactored_module} → #{original_module}")
    end
  end

  defp target_to_module_name(path) do
    path
    |> String.replace("lib/", "")
    |> String.replace("/", ".")
    |> String.replace(".ex", "")
    |> String.split(".")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(".")
    |> String.replace("Raxol", "Raxol")
  end

  defp source_to_module_name(path) do
    path
    |> String.replace("lib/", "")
    |> String.replace("/", ".")
    |> String.replace("_refactored.ex", "")
    |> String.split(".")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(".")
    |> String.replace("Raxol", "Raxol")
    |> Kernel.<>("Refactored")
  end
end

# Parse command line arguments
mode =
  case System.argv() do
    ["apply"] -> :apply
    ["--apply"] -> :apply
    _ -> :dry_run
  end

ReplaceWithRefactored.run(mode)
