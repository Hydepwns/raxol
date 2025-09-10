defmodule Mix.Tasks.Raxol.Check.Tests do
  @moduledoc """
  Run fast tests for changed modules in pre-commit.

  This task intelligently detects which test files to run based on staged
  changes, and runs them with a timeout to ensure fast feedback.

  ## Features

  - Only runs tests for changed modules
  - Excludes slow/integration/docker tests by default
  - 5-second timeout for pre-commit speed
  - Shows failed test summary with file:line references

  ## Options

  - `--timeout` - Maximum time in milliseconds (default: 5000)
  - `--all` - Run all tests, not just for changed files
  - `--verbose` - Show detailed test output
  """

  use Mix.Task

  @shortdoc "Run fast tests for changed modules"
  @default_timeout 5_000
  @test_excludes ["slow", "integration", "docker"]

  @impl Mix.Task
  def run(config) do
    verbose = Map.get(config, :verbose, false)
    timeout = Map.get(config, :timeout, @default_timeout)
    run_all = Map.get(config, :all, false)

    # Get test files to run
    test_files = get_test_files(run_all)

    handle_test_execution(test_files, timeout, verbose)
  end

  defp get_test_files(true), do: get_all_test_files()
  defp get_test_files(false), do: get_test_files_for_changes()

  defp handle_test_execution([], _, true), do: {:ok, "No test files to run"}
  defp handle_test_execution([], _, false), do: {:ok, nil}

  defp handle_test_execution(test_files, timeout, verbose) do
    run_tests_with_timeout(test_files, timeout, verbose)
  end

  defp get_test_files_for_changes do
    case System.cmd("git", ["diff", "--name-only", "--cached"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.filter(&String.ends_with?(&1, ".ex"))
        |> Enum.map(&find_test_file/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&File.exists?/1)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp get_all_test_files do
    Path.wildcard("test/**/*_test.exs")
  end

  defp find_test_file(source_file) do
    cond do
      String.starts_with?(source_file, "lib/") ->
        source_file
        |> String.replace_prefix("lib/", "test/")
        |> String.replace_suffix(".ex", "_test.exs")

      String.starts_with?(source_file, "test/") &&
          String.ends_with?(source_file, "_test.exs") ->
        source_file

      true ->
        nil
    end
  end

  defp run_tests_with_timeout(test_files, timeout, verbose) do
    # Build the mix test command
    exclude_args =
      Enum.flat_map(@test_excludes, fn tag -> ["--exclude", tag] end)

    test_args =
      [
        "test",
        "--max-failures",
        "10"
      ] ++ exclude_args ++ test_files

    env = [
      {"SKIP_TERMBOX2_TESTS", "true"},
      {"MIX_ENV", "test"},
      {"TMPDIR", "/tmp"}
    ]

    # Run with timeout
    task =
      Task.async(fn ->
        System.cmd("mix", test_args,
          env: env,
          stderr_to_stdout: true
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        maybe_print_output(output, verbose)
        {:ok, "All tests passed"}

      {:ok, {output, exit_code}} ->
        # Parse test failures
        failures = parse_test_failures(output)
        maybe_print_output(output, verbose)

        failure_summary = format_failure_summary(failures)
        {:error, "Tests failed (exit code: #{exit_code})\n#{failure_summary}"}

      nil ->
        {:error, "Test execution timed out after #{timeout}ms"}

      {:exit, reason} ->
        {:error, "Test execution failed: #{inspect(reason)}"}
    end
  end

  defp maybe_print_output(_, false), do: :ok
  defp maybe_print_output(output, true), do: IO.puts(output)

  defp parse_test_failures(output) do
    # Parse ExUnit output for failures
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "test/"))
    |> Enum.filter(&String.contains?(&1, ".exs:"))
    |> Enum.map(fn line ->
      case Regex.run(~r/(test\/[^:]+:\d+)/, line) do
        [_, location] -> location
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    # Limit to first 5 failures for readability
    |> Enum.take(5)
  end

  defp format_failure_summary([]), do: ""

  defp format_failure_summary(failures) do
    "Failed tests:\n" <>
      Enum.map_join(failures, "\n", fn location ->
        "  • #{location}"
      end)
  end
end
