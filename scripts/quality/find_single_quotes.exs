#!/usr/bin/env elixir

defmodule SingleQuoteFinder do
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
          Enum.with_index(lines, 1)
          |> Enum.each(fn {line, line_num} ->
            # Skip comments and documentation
            unless String.trim(line) |> String.starts_with?(["#", "@doc", "@moduledoc"]) do
              # Find single quotes that are not part of a string or comment
              if String.contains?(line, "'") do
                IO.puts("\n#{file}:#{line_num}")
                IO.puts("  #{line}")
              end
            end
          end)

        {:error, reason} ->
          IO.puts("Error reading #{file}: #{reason}")
      end
    end)
  end
end

SingleQuoteFinder.run()
