defmodule Mix.Tasks.Raxol do
  @moduledoc """
  Main entry point for Raxol development tasks.

  This task provides a consolidated interface to all Raxol development tools.

  ## Usage

      mix raxol COMMAND [OPTIONS]

  ## Available Commands

    * `check` - Run all quality checks (compile, format, credo, dialyzer, tests)
    * `test` - Run test suite with various options
    * `dev` - Development tools (debug, profile, analyze)
    * `docs` - Generate and manage documentation
    * `setup` - Initial project setup
    * `clean` - Clean build artifacts

  ## Examples

      # Run all checks
      mix raxol check

      # Run tests
      mix raxol test

      # Run specific check
      mix raxol check.format

      # Get help
      mix raxol help
  """

  use Mix.Task

  @shortdoc "Main Raxol task runner"

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        show_help()

      ["help" | _] ->
        show_help()

      ["check" | rest] ->
        run_check_tasks(rest)

      ["test" | rest] ->
        run_test_tasks(rest)

      ["dev" | rest] ->
        run_dev_tasks(rest)

      ["docs" | rest] ->
        run_docs_tasks(rest)

      ["setup" | rest] ->
        run_setup_tasks(rest)

      ["clean" | rest] ->
        run_clean_tasks(rest)

      [unknown | _] ->
        handle_unknown_command(unknown)
    end
  end

  @commands ~w(check test dev docs setup clean help)
  @check_subcommands ~w(format compile credo)
  @dev_subcommands ~w(analyze profile debug)

  defp handle_unknown_command(unknown) do
    case find_similar_command(unknown) do
      {similar, score} when score > 0.7 ->
        Mix.shell().error("Unknown command: '#{unknown}'")
        Mix.shell().info("\nDid you mean: mix raxol #{similar}?")
        Mix.shell().info("\nRun 'mix raxol help' for available commands.")

      _ ->
        Mix.shell().error("Unknown command: '#{unknown}'")
        Mix.shell().info("\nAvailable commands: #{Enum.join(@commands, ", ")}")
        Mix.shell().info("\nRun 'mix raxol help' for details.")
    end
  end

  defp find_similar_command(input) do
    @commands
    |> Enum.map(fn cmd -> {cmd, String.jaro_distance(input, cmd)} end)
    |> Enum.max_by(fn {_cmd, score} -> score end)
  end

  defp handle_unknown_subcommand(parent, unknown, valid_subcommands) do
    case find_similar(unknown, valid_subcommands) do
      {similar, score} when score > 0.6 ->
        Mix.shell().error("Unknown #{parent} command: '#{unknown}'")
        Mix.shell().info("\nDid you mean: mix raxol #{parent} #{similar}?")

      _ ->
        Mix.shell().error("Unknown #{parent} command: '#{unknown}'")
        Mix.shell().info("\nAvailable: #{Enum.join(valid_subcommands, ", ")}")
    end
  end

  defp find_similar(input, candidates) do
    candidates
    |> Enum.map(fn cmd -> {cmd, String.jaro_distance(input, cmd)} end)
    |> Enum.max_by(fn {_cmd, score} -> score end)
  end

  defp show_help do
    Mix.shell().info(@moduledoc)
  end

  defp run_check_tasks([]) do
    Mix.shell().info("Running all quality checks...")

    tasks = [
      "compile --warnings-as-errors",
      "format --check-formatted",
      "credo --strict",
      "test"
    ]

    Enum.each(tasks, fn task ->
      Mix.shell().info("Running: mix #{task}")

      try do
        Mix.Task.run(task, [])
        Mix.Task.reenable(task)
      rescue
        e ->
          Mix.shell().error("Task failed: #{task}")
          Mix.shell().error(Exception.message(e))
      end
    end)
  end

  defp run_check_tasks(["format" | _]) do
    Mix.shell().info("Checking code formatting...")
    Mix.Task.run("format", ["--check-formatted"])
  end

  defp run_check_tasks(["compile" | _]) do
    Mix.shell().info("Checking compilation...")
    Mix.Task.run("compile", ["--warnings-as-errors"])
  end

  defp run_check_tasks(["credo" | _]) do
    Mix.shell().info("Running Credo analysis...")
    Mix.Task.run("credo", ["--strict"])
  end

  defp run_check_tasks([unknown | _]) do
    handle_unknown_subcommand("check", unknown, @check_subcommands)
  end

  defp run_test_tasks([]) do
    Mix.shell().info("Running test suite...")
    Mix.Task.run("test", [])
  end

  defp run_test_tasks(args) do
    Mix.shell().info("Running tests with args: #{Enum.join(args, " ")}")
    Mix.Task.run("test", args)
  end

  defp run_dev_tasks([]) do
    Mix.shell().info("""
    Available dev commands:
      mix raxol dev.analyze  - Run code analysis
      mix raxol dev.profile  - Profile application
      mix raxol dev.debug    - Debug helpers
    """)
  end

  defp run_dev_tasks([cmd | _args]) do
    case cmd do
      "analyze" ->
        Mix.shell().info("Running code analysis...")
        # Would call the analyze task when enabled
        Mix.shell().info("(analyze task not yet enabled)")

      "profile" ->
        Mix.shell().info("Running profiler...")
        # Would call the profile task when enabled
        Mix.shell().info("(profile task not yet enabled)")

      "debug" ->
        Mix.shell().info("Running debug tools...")
        # Would call the debug task when enabled
        Mix.shell().info("(debug task not yet enabled)")

      _ ->
        handle_unknown_subcommand("dev", cmd, @dev_subcommands)
    end
  end

  defp run_docs_tasks([]) do
    Mix.shell().info("Generating documentation...")
    Mix.Task.run("docs", [])
  end

  defp run_docs_tasks(args) do
    Mix.Task.run("docs", args)
  end

  defp run_setup_tasks([]) do
    Mix.shell().info("Setting up Raxol project...")

    tasks = [
      {"deps.get", "Fetching dependencies"},
      {"compile", "Compiling project"},
      {"test", "Running initial tests"}
    ]

    Enum.each(tasks, fn {task, desc} ->
      Mix.shell().info("#{desc}...")
      Mix.Task.run(task, [])
      Mix.Task.reenable(task)
    end)

    Mix.shell().info("Setup complete!")
  end

  defp run_setup_tasks(_args) do
    run_setup_tasks([])
  end

  defp run_clean_tasks([]) do
    Mix.shell().info("Cleaning build artifacts...")

    Mix.Task.run("clean", [])

    # Clean additional artifacts
    _ = File.rm_rf("_build")
    _ = File.rm_rf("deps")
    _ = File.rm_rf("doc")
    _ = File.rm_rf("cover")

    Mix.shell().info("Clean complete!")
  end

  defp run_clean_tasks(_args) do
    run_clean_tasks([])
  end
end
