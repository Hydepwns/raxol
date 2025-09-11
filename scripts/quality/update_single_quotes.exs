#!/usr/bin/env elixir

defmodule SingleQuoteUpdater do
  def run do
    # Get all .ex and .exs files
    files = Path.wildcard("lib/**/*.{ex,exs}") ++ Path.wildcard("test/**/*.{ex,exs}")

    # Process each file
    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Split into lines
          lines = String.split(content, "\n")

          # Process each line
          updated_lines = Enum.map(lines, fn line ->
            # Skip comments and documentation
            if String.trim(line) |> String.starts_with?(["#", "@doc", "@moduledoc"]) do
              line
            else
              # Replace single quotes with double quotes, but be careful with charlists
              updated_line = String.replace(line, ~r/(?<!\?)(?<!\w)'([^']*)'/, "\"\\1\"")
              if updated_line != line do
                IO.puts("\nUpdating in #{file}:")
                IO.puts("  Old: #{line}")
                IO.puts("  New: #{updated_line}")
              end
              updated_line
            end
          end)

          # Write back to file if changes were made
          if updated_lines != lines do
            File.write!(file, Enum.join(updated_lines, "\n"))
            IO.puts("\nUpdated #{file}")
          end

        {:error, reason} ->
          IO.puts("Error reading #{file}: #{reason}")
      end
    end)
  end
end

SingleQuoteUpdater.run()
