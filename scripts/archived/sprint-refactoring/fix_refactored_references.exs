#!/usr/bin/env elixir

# Script to fix all remaining references to Refactored modules

defmodule FixReferences do
  def run do
    IO.puts("Fixing references to Refactored modules...\n")

    files_to_fix = find_files_with_references()
    IO.puts("Found #{length(files_to_fix)} files with references to fix\n")

    results = Enum.map(files_to_fix, &fix_file/1)

    successful = Enum.count(results, & &1.success)
    failed = Enum.count(results, &(not &1.success))

    IO.puts("\n=== Summary ===")
    IO.puts("Successfully fixed: #{successful}")
    IO.puts("Failed: #{failed}")

    if failed > 0 do
      IO.puts("\nFailed files:")

      results
      |> Enum.filter(&(not &1.success))
      |> Enum.each(fn result ->
        IO.puts("  - #{result.file}: #{result.error}")
      end)
    end
  end

  defp find_files_with_references do
    # Get all Elixir files
    Path.wildcard("lib/**/*.{ex,exs}") ++
      Path.wildcard("test/**/*.{ex,exs}") ++
      Path.wildcard("config/**/*.{ex,exs}") ++
      Path.wildcard("scripts/**/*.exs")
  end

  defp fix_file(file_path) do
    # Skip the cleanup script itself and this script
    if String.ends_with?(file_path, "cleanup_refactored_files.exs") or
         String.ends_with?(file_path, "fix_refactored_references.exs") or
         String.ends_with?(file_path, "migrate_to_refactored.exs") or
         String.ends_with?(file_path, "replace_with_refactored.exs") do
      %{success: true, file: file_path, skipped: true}
    else
      try do
        content = File.read!(file_path)

        if String.contains?(content, "Refactored") or
             String.contains?(content, "_refactored") do
          fixed_content = fix_content(content)

          if content != fixed_content do
            File.write!(file_path, fixed_content)
            IO.puts("✓ Fixed: #{file_path}")
            %{success: true, file: file_path}
          else
            %{success: true, file: file_path, unchanged: true}
          end
        else
          %{success: true, file: file_path, unchanged: true}
        end
      rescue
        e ->
          %{success: false, file: file_path, error: inspect(e)}
      end
    end
  end

  defp fix_content(content) do
    content
    # Fix double-refactored references (from running refactoring twice)
    |> String.replace("RefactoredRefactored", "")
    |> String.replace("refactored_refactored", "")

    # Fix module aliases and references
    |> String.replace(~r/alias\s+([A-Za-z0-9_.]+)Refactored/, "alias \\1")
    |> String.replace(~r/alias\s+([A-Za-z0-9_.]+)\.Refactored/, "alias \\1")

    # Fix module names in code
    |> String.replace(~r/([A-Z][A-Za-z0-9_.]*)Refactored\./, "\\1.")
    |> String.replace(~r/([A-Z][A-Za-z0-9_.]*)Refactored(?![A-Za-z])/, "\\1")

    # Fix function calls
    |> String.replace(~r/([a-z_][a-z0-9_]*)_refactored\(/, "\\1(")
    |> String.replace(~r/([a-z_][a-z0-9_]*)_refactored\./, "\\1.")

    # Fix atoms
    |> String.replace(~r/:([a-z_][a-z0-9_]*)_refactored/, ":\\1")

    # Fix specific common patterns
    |> String.replace("HooksFunctional", "Hooks")
    |> String.replace("hooks_functional", "hooks")
    |> String.replace("StreamsRefactored", "Streams")
    |> String.replace("streams_refactored", "streams")
    |> String.replace("StoreRefactored", "Store")
    |> String.replace("store_refactored", "store")

    # Fix supervisor references
    |> String.replace(
      "Raxol.Core.RefactoredSupervisor",
      "Raxol.Core.Supervisor"
    )

    # Clean up any test file references
    |> String.replace("_refactored_test", "_test")
    |> String.replace("RefactoredTest", "Test")

    # Fix imports
    |> String.replace(~r/import\s+([A-Za-z0-9_.]+)Refactored/, "import \\1")
    |> String.replace(~r/import\s+([A-Za-z0-9_.]+)\.Refactored/, "import \\1")

    # Fix use statements
    |> String.replace(~r/use\s+([A-Za-z0-9_.]+)Refactored/, "use \\1")
    |> String.replace(~r/use\s+([A-Za-z0-9_.]+)\.Refactored/, "use \\1")

    # Fix require statements
    |> String.replace(~r/require\s+([A-Za-z0-9_.]+)Refactored/, "require \\1")
    |> String.replace(~r/require\s+([A-Za-z0-9_.]+)\.Refactored/, "require \\1")

    # Fix GenServer name registrations
    |> String.replace(~r/name:\s*([A-Za-z0-9_.]+)Refactored/, "name: \\1")

    # Clean up _refactored in strings
    |> String.replace("\"_refactored\"", "\"\"")
    |> String.replace("'_refactored'", "''")

    # Fix file paths in comments or strings
    |> String.replace("_refactored.ex", ".ex")
    |> String.replace("Refactored.ex", ".ex")
  end
end

FixReferences.run()
