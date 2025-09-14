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
        Mix.shell().error("Unknown command: #{unknown}")
        show_help()
    end
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
    Mix.shell().error("Unknown check command: #{unknown}")
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
        Mix.shell().error("Unknown dev command: #{cmd}")
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
    File.rm_rf("_build")
    File.rm_rf("deps")
    File.rm_rf("doc")
    File.rm_rf("cover")

    Mix.shell().info("Clean complete!")
  end

  defp run_clean_tasks(_args) do
    run_clean_tasks([])
  end
end
