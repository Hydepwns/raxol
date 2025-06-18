#!/usr/bin/env elixir

defmodule SpecialCasesFixer do
  def run do
    # Get all .ex and .exs files
    files =
      Path.wildcard("lib/**/*.{ex,exs}") ++ Path.wildcard("test/**/*.{ex,exs}")

    # Process each file
    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Fix heredocs
          content = String.replace(content, ~r/~S"""/, "~S\"\"\"")
          content = String.replace(content, ~r/"""/, "\"\"\"")

          # Fix charlists
          content = String.replace(content, ~r/\?"([^"]+)"/, "?'\\1'")

          # Fix test descriptions and documentation
          content =
            String.replace(content, ~r/test "([^"]+)" do/, "test '\\1' do")

          content = String.replace(content, ~r/@doc "([^"]+)"/, "@doc '\\1'")

          content =
            String.replace(
              content,
              ~r/@moduledoc "([^"]+)"/,
              "@moduledoc '\\1'"
            )

          # Write back to file if changes were made
          File.write!(file, content)
          IO.puts("Fixed special cases in #{file}")

        {:error, reason} ->
          IO.puts("Error reading #{file}: #{reason}")
      end
    end)
  end
end

SpecialCasesFixer.run()
