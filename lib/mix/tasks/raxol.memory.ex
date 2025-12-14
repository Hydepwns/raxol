defmodule Mix.Tasks.Raxol.Memory do
  @moduledoc """
  Unified memory analysis and profiling tools.

  Consolidates all memory-related functionality into a single comprehensive task.

  ## Commands

      mix raxol.memory debug               # Debug memory issues and leaks
      mix raxol.memory profile             # Interactive memory profiling
      mix raxol.memory gates               # CI/CD performance gates
      mix raxol.memory stability           # Long-running stability tests

  ## Common Options

    * `--format` - Output format: text, json, dashboard (default: text)
    * `--output` - Output file or directory
    * `--duration` - Duration in seconds for profiling
    * `--mode` - Profiling mode: snapshot, live, comparative
    * `--scenario` - Specific test scenario to run
    * `--target` - Target module or component to analyze
    * `--interval` - Sampling interval in milliseconds
    * `--threshold` - Memory threshold in MB for alerts
    * `--strict` - Enable strict mode (fail on warnings)
    * `--baseline` - Path to baseline file for comparison
    * `--with-profiling` - Include detailed profiling data
    * `--help` - Show help for specific commands

  ## Examples

      # Quick memory analysis
      mix raxol.memory debug

      # Live profiling with dashboard
      mix raxol.memory profile --mode live --format dashboard

      # Run CI gates for specific scenario
      mix raxol.memory gates --scenario terminal_operations

      # Extended stability testing
      mix raxol.memory stability --duration 3600
  """

  use Mix.Task

  @shortdoc "Unified memory analysis and profiling"

  @switches [
    help: :boolean,
    format: :string,
    output: :string,
    duration: :integer,
    mode: :string,
    scenario: :string,
    target: :string,
    interval: :integer,
    threshold: :integer,
    strict: :boolean,
    baseline: :string,
    with_profiling: :boolean
  ]

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches)

    case args do
      [] ->
        show_help()

      ["help" | _] ->
        show_help()

      [command | rest]
      when command in ["debug", "profile", "gates", "stability"] ->
        handle_command(command, rest, opts)

      [command | _] ->
        Mix.shell().error("Unknown command: #{command}")
        show_help()
    end
  end

  defp handle_command("debug", args, opts) do
    delegate_to_debug_task(args, opts)
  end

  defp handle_command("profile", args, opts) do
    delegate_to_profiler_task(args, opts)
  end

  defp handle_command("gates", args, opts) do
    delegate_to_gates_task(args, opts)
  end

  defp handle_command("stability", args, opts) do
    delegate_to_stability_task(args, opts)
  end

  # Delegate to existing specialized tasks to maintain functionality
  defp delegate_to_debug_task(args, opts) do
    Mix.Task.run("raxol.memory.debug", build_args(args, opts))
  end

  defp delegate_to_profiler_task(args, opts) do
    Mix.Task.run("raxol.memory.profiler", build_args(args, opts))
  end

  defp delegate_to_gates_task(args, opts) do
    Mix.Task.run("raxol.memory.gates", build_args(args, opts))
  end

  defp delegate_to_stability_task(args, opts) do
    Mix.Task.run("raxol.memory.stability", build_args(args, opts))
  end

  defp build_args(args, opts) do
    option_args =
      opts
      |> Enum.flat_map(fn
        {key, true} -> ["--#{key}"]
        {_key, false} -> []
        {key, value} -> ["--#{key}", to_string(value)]
      end)

    args ++ option_args
  end

  defp show_help do
    Mix.shell().info("""
    Unified memory analysis and profiling tools for Raxol.

    ## Commands

        debug               Debug memory issues, leaks, and hotspots
        profile            Interactive real-time memory profiling
        gates              CI/CD memory performance gates
        stability          Long-running stability and leak tests

    ## Usage

        mix raxol.memory <command> [options]
        mix raxol.memory <command> --help    # Command-specific help

    ## Quick Examples

        mix raxol.memory debug               # Analyze current memory usage
        mix raxol.memory profile --mode live # Live memory monitoring
        mix raxol.memory gates --strict      # Strict CI performance gates
        mix raxol.memory stability           # 30-minute stability test

    Use 'mix raxol.memory <command> --help' for detailed command options.
    """)
  end
end
