#!/usr/bin/env elixir

defmodule ModuledocChecker do
  def run do
    lib_files = Path.wildcard("lib/**/*.ex")
    test_files = Path.wildcard("test/**/*.exs")

    all_files = lib_files ++ test_files

    missing = all_files
    |> Enum.filter(&has_missing_moduledoc?/1)
    |> Enum.sort()

    IO.puts("Files with modules missing @moduledoc:")
    IO.puts("=====================================")

    Enum.each(missing, fn file ->
      IO.puts("- #{file}")
    end)

    IO.puts("\nTotal: #{length(missing)} files")
  end

  defp has_missing_moduledoc?(file_path) do
    content = File.read!(file_path)

    # Check if file has defmodule
    if String.contains?(content, "defmodule") do
      # Parse into lines
      lines = String.split(content, "\n")

      # Find defmodule lines
      module_indices = lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _} ->
        String.match?(line, ~r/^\s*defmodule\s+[A-Z]/)
      end)
      |> Enum.map(fn {_, index} -> index end)

      # Check if any module doesn't have a @moduledoc
      Enum.any?(module_indices, fn idx ->
        # Check next few lines for @moduledoc
        following_lines = lines
        |> Enum.slice((idx + 1)..(min(idx + 5, length(lines) - 1)))
        |> Enum.join("\n")

        not String.contains?(following_lines, "@moduledoc")
      end)
    else
      false
    end
  end
end

ModuledocChecker.run()