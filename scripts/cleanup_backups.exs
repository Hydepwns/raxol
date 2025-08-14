#!/usr/bin/env elixir

# Script to clean up backup files

defmodule CleanupBackups do
  def run do
    IO.puts("Cleaning up backup files...\n")
    
    # Find all backup files
    backup_files = find_backup_files()
    
    if length(backup_files) == 0 do
      IO.puts("No backup files found.")
      :ok
    else
      IO.puts("Found #{length(backup_files)} backup files:")
      
      # Group by type
      {old_backups, timestamped_backups} = 
        Enum.split_with(backup_files, &String.ends_with?(&1, ".backup"))
      
      if length(old_backups) > 0 do
        IO.puts("\nOld .backup files (#{length(old_backups)}):")
        Enum.each(old_backups, &IO.puts("  #{&1}"))
      end
      
      if length(timestamped_backups) > 0 do
        IO.puts("\nTimestamped backup files (#{length(timestamped_backups)}):")
        Enum.each(timestamped_backups, &IO.puts("  #{&1}"))
      end
      
      IO.puts("\nDo you want to delete all backup files? (yes/no)")
      response = IO.gets("") |> String.trim() |> String.downcase()
      
      if response == "yes" or response == "y" do
        delete_files(backup_files)
      else
        IO.puts("Backup cleanup cancelled.")
      end
    end
  end
  
  defp find_backup_files do
    # Find all backup files
    Path.wildcard("lib/**/*.backup") ++
    Path.wildcard("lib/**/*.backup.*") ++
    Path.wildcard("test/**/*.backup") ++
    Path.wildcard("test/**/*.backup.*") ++
    Path.wildcard("docs/**/*.backup") ++
    Path.wildcard("docs/**/*.backup.*")
  end
  
  defp delete_files(files) do
    IO.puts("\nDeleting backup files...")
    
    results = Enum.map(files, fn file ->
      try do
        File.rm!(file)
        IO.puts("✓ Deleted: #{file}")
        {:ok, file}
      rescue
        e ->
          IO.puts("✗ Failed to delete #{file}: #{inspect(e)}")
          {:error, file, e}
      end
    end)
    
    successful = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    failed = length(results) - successful
    
    IO.puts("\n=== Summary ===")
    IO.puts("Successfully deleted: #{successful}")
    IO.puts("Failed: #{failed}")
  end
end

# Auto-confirm mode for CI/automation
if System.get_env("AUTO_CONFIRM") == "true" do
  IO.puts("AUTO_CONFIRM mode - deleting all backups without prompting")
  backup_files = Path.wildcard("lib/**/*.backup*") ++ 
                 Path.wildcard("test/**/*.backup*") ++
                 Path.wildcard("docs/**/*.backup*")
  
  Enum.each(backup_files, fn file ->
    File.rm!(file)
    IO.puts("✓ Deleted: #{file}")
  end)
  
  IO.puts("\n✓ All #{length(backup_files)} backup files deleted")
else
  CleanupBackups.run()
end