defmodule Mix.Tasks.Raxol.Check.Credo do
  @moduledoc """
  Check code style and consistency with Credo.

  Focuses on staged files for faster checks.
  """

  use Mix.Task

  @shortdoc "Check code style with Credo"

  @impl Mix.Task
  def run(config \\ %{}) do
    verbose = Map.get(config, :verbose, false)

    # Check if Credo is available
    if not Code.ensure_loaded?(Credo) do
      {:warning, "Credo not installed, skipping style check"}
    else
      case get_staged_elixir_files() do
        {:ok, []} ->
          if verbose, do: IO.puts("  No Elixir files to check")
          {:ok, "No files to check"}

        {:ok, files} ->
          if verbose,
            do: IO.puts("  Running Credo on #{length(files)} files...")

          run_credo(files, config)

        {:error, reason} ->
          {:error, "Failed to get staged files: #{reason}"}
      end
    end
  end

  defp get_staged_elixir_files do
    case System.cmd(
           "git",
           [
             "diff",
             "--name-only",
             "--cached",
             "--diff-filter=ACMR",
             "--",
             "*.ex",
             "*.exs"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&File.exists?/1)

        {:ok, files}

      {error, _} ->
        {:error, error}
    end
  end

  defp run_credo(files, config) do
    # Build Credo arguments
    args = build_credo_args(files, config)

    case System.cmd("mix", ["credo"] ++ args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, "All style checks passed"}

      {output, exit_code} when exit_code > 0 ->
        issues = parse_credo_output(output)
        format_credo_result(issues, config)

      {error, _} ->
        {:error, "Credo check failed: #{error}"}
    end
  end

  defp build_credo_args(files, config) do
    base_args =
      if Map.get(config, :strict, false) do
        ["--strict"]
      else
        []
      end

    # Add format for parsing
    format_args = ["--format", "oneline"]

    # Only check staged files
    file_args = files

    base_args ++ format_args ++ ["--"] ++ file_args
  end

  defp parse_credo_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.map(&parse_credo_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_credo_line(line) do
    # Parse Credo oneline format: [W] ↗ lib/file.ex:10:5 Module.function Some.Check: Message
    case Regex.run(
           ~r/\[([WRCFD])\]\s+.+?\s+(.+?):(\d+)(?::(\d+))?\s+(.+)/,
           line
         ) do
      [_, priority, file, line_num, _column, message] ->
        %{
          priority: parse_priority(priority),
          file: file,
          line: String.to_integer(line_num),
          message: clean_message(message)
        }

      _ ->
        nil
    end
  end

  # Formatting/Consistency
  defp parse_priority("F"), do: :consistency
  # Warning
  defp parse_priority("W"), do: :warning
  # Refactoring opportunity
  defp parse_priority("R"), do: :refactor
  # Convention violation
  defp parse_priority("C"), do: :convention
  # Design issue
  defp parse_priority("D"), do: :design
  defp parse_priority(_), do: :unknown

  defp clean_message(message) do
    message
    # Remove check name
    |> String.replace(~r/\s+[A-Z]\w+(?:\.\w+)+:/, "")
    |> String.trim()
  end

  defp format_credo_result([], _config) do
    {:ok, "No style issues found"}
  end

  defp format_credo_result(issues, config) do
    # Group by priority
    grouped = Enum.group_by(issues, & &1.priority)

    # Count by type
    counts =
      Enum.map(
        [:consistency, :warning, :refactor, :convention, :design],
        fn priority ->
          count = length(Map.get(grouped, priority, []))
          {priority, count}
        end
      )
      |> Enum.filter(fn {_, count} -> count > 0 end)

    # Decide if it's an error or warning based on priority
    has_errors =
      Enum.any?(issues, fn issue ->
        issue.priority in [:warning, :design]
      end)

    # Format message
    details =
      if Map.get(config, :verbose, false) do
        format_detailed_issues(issues)
      else
        format_summary(counts)
      end

    message = """
    Credo found #{length(issues)} issue(s):
    #{details}

    Run: mix credo --strict
    """

    if has_errors do
      {:error, message}
    else
      {:warning, message}
    end
  end

  defp format_summary(counts) do
    Enum.map_join(counts, "\n", fn {priority, count} ->
      "  #{count} #{priority} issue(s)"
    end)
  end

  defp format_detailed_issues(issues) do
    issues
    # Limit to first 10 issues
    |> Enum.take(10)
    |> Enum.map_join("\n", fn issue ->
      "  #{issue.file}:#{issue.line} - #{issue.message}"
    end)
  end
end
