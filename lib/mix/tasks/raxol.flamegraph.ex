defmodule Mix.Tasks.Raxol.Flamegraph do
  @moduledoc """
  Generate flame graphs for performance analysis.

  Flame graphs visualize profiling data as interactive SVG images,
  making it easy to identify performance bottlenecks.

  ## Usage

      mix raxol.flamegraph MODULE [OPTIONS]
      mix raxol.flamegraph --function MODULE.function/arity [OPTIONS]
      mix raxol.flamegraph --info

  ## Examples

      # Profile a module for 5 seconds
      mix raxol.flamegraph Raxol.Terminal.Buffer

      # Profile with custom duration
      mix raxol.flamegraph Raxol.Terminal.Buffer --duration 10000

      # Profile a specific function
      mix raxol.flamegraph --function Raxol.Terminal.Buffer.write/3

      # Check available tools
      mix raxol.flamegraph --info

      # Custom output path
      mix raxol.flamegraph Raxol.UI.Renderer --output ./profiling/renderer.svg

  ## Options

    * `--duration MS` - Profiling duration in milliseconds (default: 5000)
    * `--output PATH` - Output file path (default: MODULE_flamegraph.svg)
    * `--title TITLE` - Title for the flame graph
    * `--width PIXELS` - SVG width (default: 1200)
    * `--format FORMAT` - Output format: svg, folded, fprof (default: svg)
    * `--info` - Show available profiling tools
    * `--function MFA` - Profile a specific function call

  ## Output

  By default, generates an SVG file that can be opened in any web browser.
  The SVG is interactive - hover to see function names and click to zoom.

  ## Requirements

  For SVG generation, install brendangregg/FlameGraph:

      git clone https://github.com/brendangregg/FlameGraph
      export PATH=$PATH:/path/to/FlameGraph

  Without this, output is saved in folded stack format which can be
  converted to SVG later.
  """

  use Mix.Task

  alias Raxol.CLI.Colors
  alias Raxol.Core.Performance.FlameGraph

  @shortdoc "Generate flame graphs for performance profiling"

  @switches [
    duration: :integer,
    output: :string,
    title: :string,
    width: :integer,
    format: :string,
    info: :boolean,
    function: :string,
    help: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: @switches)

    cond do
      opts[:help] ->
        print_help()

      opts[:info] ->
        show_tool_info()

      opts[:function] ->
        profile_function(opts[:function], opts)

      length(positional) > 0 ->
        [module_str | _] = positional
        profile_module(module_str, opts)

      true ->
        Mix.shell().error("No module specified. Use --help for usage.")
    end
  end

  defp profile_module(module_str, opts) do
    Mix.Task.run("app.start")

    module = String.to_atom("Elixir." <> module_str)
    duration = opts[:duration] || 5000

    Mix.shell().info(Colors.section_header("Flame Graph Profiler"))
    Mix.shell().info("")
    Mix.shell().info("  Module:   #{module_str}")
    Mix.shell().info("  Duration: #{duration}ms")
    Mix.shell().info("")

    Mix.shell().info(Colors.muted("Starting profiler..."))

    profile_opts = build_profile_opts(module_str, opts)

    case FlameGraph.profile_module(module, [
           {:duration, duration} | profile_opts
         ]) do
      {:ok, output} ->
        Mix.shell().info("")

        Mix.shell().info(
          "  " <> Colors.success("[OK]") <> " Flame graph generated"
        )

        Mix.shell().info("  " <> Colors.muted("Output:") <> " " <> output)
        Mix.shell().info("")
        suggest_viewing(output)

      {:error, reason} ->
        Mix.shell().error("  " <> Colors.error("[!!]") <> " Profiling failed")
        Mix.shell().error("  " <> Colors.muted("Reason:") <> " #{reason}")
    end
  end

  defp profile_function(mfa_str, opts) do
    Mix.Task.run("app.start")

    Mix.shell().info(Colors.section_header("Flame Graph Profiler"))
    Mix.shell().info("")
    Mix.shell().info("  Function: #{mfa_str}")
    Mix.shell().info("")

    case parse_mfa(mfa_str) do
      {:ok, {module, function, args}} ->
        Mix.shell().info(Colors.muted("Profiling function call..."))

        profile_opts = build_profile_opts(mfa_str, opts)

        case FlameGraph.profile(
               fn -> apply(module, function, args) end,
               profile_opts
             ) do
          {:ok, output, result} ->
            Mix.shell().info("")

            Mix.shell().info(
              "  " <> Colors.success("[OK]") <> " Flame graph generated"
            )

            Mix.shell().info("  " <> Colors.muted("Output:") <> " " <> output)

            Mix.shell().info(
              "  " <>
                Colors.muted("Result:") <> " #{inspect(result, limit: 50)}"
            )

            Mix.shell().info("")
            suggest_viewing(output)

          {:error, reason} ->
            Mix.shell().error(
              "  " <> Colors.error("[!!]") <> " Profiling failed: #{reason}"
            )
        end

      {:error, reason} ->
        Mix.shell().error("  " <> Colors.error("[!!]") <> " #{reason}")
    end
  end

  defp show_tool_info do
    Mix.shell().info(Colors.section_header("Flame Graph Tool Info"))
    Mix.shell().info("")

    info = FlameGraph.tool_info()

    tools = [
      {"fprof (Erlang built-in)", info.fprof, "Always available"},
      {"flamegraph.pl", info.flamegraph_pl, "For SVG generation"},
      {"eflambe", info.eflambe, "Alternative SVG generator"}
    ]

    Enum.each(tools, fn {name, available, desc} ->
      status =
        if available,
          do: Colors.success("[OK]"),
          else: Colors.muted("[--]")

      Mix.shell().info("  #{status} #{name}")
      Mix.shell().info("      " <> Colors.muted(desc))
    end)

    Mix.shell().info("")
    Mix.shell().info(Colors.info("Recommendation:"))
    Mix.shell().info("  " <> info.recommendation)
    Mix.shell().info("")

    unless info.flamegraph_pl do
      Mix.shell().info(Colors.muted("To install flamegraph.pl:"))
      Mix.shell().info("  git clone https://github.com/brendangregg/FlameGraph")
      Mix.shell().info("  export PATH=$PATH:/path/to/FlameGraph")
      Mix.shell().info("")
    end
  end

  defp build_profile_opts(name, opts) do
    base_opts = []

    base_opts =
      if opts[:output] do
        Keyword.put(base_opts, :output, opts[:output])
      else
        safe_name = name |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
        Keyword.put(base_opts, :output, "#{safe_name}_flamegraph.svg")
      end

    base_opts =
      if opts[:title] do
        Keyword.put(base_opts, :title, opts[:title])
      else
        Keyword.put(base_opts, :title, "Profile: #{name}")
      end

    base_opts =
      if opts[:width] do
        Keyword.put(base_opts, :width, opts[:width])
      else
        base_opts
      end

    base_opts =
      if opts[:format] do
        Keyword.put(base_opts, :format, String.to_atom(opts[:format]))
      else
        base_opts
      end

    base_opts
  end

  defp parse_mfa(mfa_str) do
    # Parse "Module.function/arity" or "Module.function(arg1, arg2)"
    cond do
      String.contains?(mfa_str, "(") ->
        # Has arguments: Module.function(arg1, arg2)
        case Regex.run(~r/^(.+)\.([^.(]+)\(([^)]*)\)$/, mfa_str) do
          [_, module_str, func_str, args_str] ->
            module = String.to_atom("Elixir." <> module_str)
            function = String.to_atom(func_str)
            args = parse_args(args_str)
            {:ok, {module, function, args}}

          _ ->
            {:error,
             "Invalid function format. Use Module.function(args) or Module.function/arity"}
        end

      String.contains?(mfa_str, "/") ->
        # Has arity: Module.function/2
        case Regex.run(~r|^(.+)\.([^./]+)/(\d+)$|, mfa_str) do
          [_, module_str, func_str, arity_str] ->
            module = String.to_atom("Elixir." <> module_str)
            function = String.to_atom(func_str)
            arity = String.to_integer(arity_str)
            # Create placeholder args
            args = List.duplicate(nil, arity)
            {:ok, {module, function, args}}

          _ ->
            {:error,
             "Invalid function format. Use Module.function(args) or Module.function/arity"}
        end

      true ->
        {:error,
         "Invalid function format. Use Module.function(args) or Module.function/arity"}
    end
  end

  defp parse_args(""), do: []

  defp parse_args(args_str) do
    args_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_arg/1)
  end

  defp parse_arg(arg_str) do
    # Try to parse as Elixir term
    case Code.eval_string(arg_str) do
      {value, _} -> value
      _ -> arg_str
    end
  rescue
    _ -> arg_str
  end

  defp suggest_viewing(output) do
    cond do
      String.ends_with?(output, ".svg") ->
        Mix.shell().info(Colors.muted("View in browser:"))
        Mix.shell().info("  open #{output}")

      String.ends_with?(output, ".folded") ->
        Mix.shell().info(Colors.muted("Convert to SVG:"))
        Mix.shell().info("  cat #{output} | flamegraph.pl > flamegraph.svg")

      true ->
        :ok
    end
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end
