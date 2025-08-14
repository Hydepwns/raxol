#!/usr/bin/env elixir

# Script to clean up refactored files and consolidate to single versions

defmodule RefactoredCleanup do
  @refactored_suffix "_refactored"
  @refactored_suffix_cap "Refactored"
  
  def run do
    IO.puts("Starting cleanup of refactored files...\n")
    
    # Find all refactored files
    refactored_files = find_refactored_files()
    IO.puts("Found #{length(refactored_files)} refactored files to process\n")
    
    # Process each refactored file
    results = Enum.map(refactored_files, &process_file/1)
    
    # Summary
    successful = Enum.count(results, & &1.success)
    failed = Enum.count(results, &(not &1.success))
    
    IO.puts("\n=== Summary ===")
    IO.puts("Successfully processed: #{successful}")
    IO.puts("Failed: #{failed}")
    
    if failed > 0 do
      IO.puts("\nFailed files:")
      results
      |> Enum.filter(&(not &1.success))
      |> Enum.each(fn result ->
        IO.puts("  - #{result.file}: #{result.error}")
      end)
    end
    
    IO.puts("\nCleanup complete!")
  end
  
  defp find_refactored_files do
    Path.wildcard("lib/**/*_refactored.ex") ++
    Path.wildcard("lib/**/*Refactored.ex") ++
    Path.wildcard("test/**/*_refactored.ex") ++
    Path.wildcard("test/**/*_refactored_test.exs")
  end
  
  defp process_file(refactored_path) do
    original_path = get_original_path(refactored_path)
    
    IO.puts("Processing: #{refactored_path}")
    IO.puts("  Original: #{original_path}")
    
    try do
      # Read the refactored file
      refactored_content = File.read!(refactored_path)
      
      # Update module name to remove Refactored suffix
      updated_content = update_module_name(refactored_content, refactored_path)
      
      # Check if original exists and back it up
      if File.exists?(original_path) do
        backup_path = original_path <> ".backup.#{timestamp()}"
        File.copy!(original_path, backup_path)
        IO.puts("  Backed up original to: #{backup_path}")
      end
      
      # Write the updated content to the original path
      File.write!(original_path, updated_content)
      IO.puts("  ✓ Replaced original with refactored version")
      
      # Delete the refactored file
      File.rm!(refactored_path)
      IO.puts("  ✓ Removed refactored file")
      
      %{success: true, file: refactored_path}
    rescue
      e ->
        %{success: false, file: refactored_path, error: inspect(e)}
    end
  end
  
  defp get_original_path(refactored_path) do
    refactored_path
    |> String.replace("_refactored.ex", ".ex")
    |> String.replace("Refactored.ex", ".ex")
    |> String.replace("_refactored_test.exs", "_test.exs")
  end
  
  defp update_module_name(content, file_path) do
    # Extract the expected module name from the file path
    module_name = path_to_module_name(get_original_path(file_path))
    
    # Replace various refactored module patterns
    content
    |> String.replace(~r/defmodule (.+)Refactored do/, "defmodule \\1 do")
    |> String.replace(~r/defmodule (.+)\.Refactored do/, "defmodule \\1 do")
    |> String.replace(~r/defmodule (.+)RefactoredTest do/, "defmodule \\1Test do")
    |> ensure_correct_module_name(module_name)
  end
  
  defp ensure_correct_module_name(content, expected_module) do
    # This ensures the module name matches what's expected from the file path
    if String.contains?(content, "defmodule ") do
      # Extract current module name
      case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/, content) do
        [_, current_module] ->
          if String.contains?(current_module, "Refactored") or 
             String.contains?(current_module, "V2") or
             String.contains?(current_module, "Functional") do
            # Replace with the expected module name
            String.replace(content, ~r/defmodule\s+[A-Za-z0-9_.]+\s+do/, "defmodule #{expected_module} do")
          else
            content
          end
        _ ->
          content
      end
    else
      content
    end
  end
  
  defp path_to_module_name(file_path) do
    file_path
    |> String.replace("lib/", "")
    |> String.replace("test/", "")
    |> String.replace(".ex", "")
    |> String.replace(".exs", "")
    |> String.replace("_test", "Test")
    |> String.split("/")
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join(".")
  end
  
  defp timestamp do
    {{y, m, d}, {h, min, s}} = :calendar.local_time()
    "#{y}#{pad(m)}#{pad(d)}_#{pad(h)}#{pad(min)}#{pad(s)}"
  end
  
  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end

RefactoredCleanup.run()