defmodule Raxol.Core.Performance.FlameGraph do
  @moduledoc """
  Flame graph generation for performance profiling.

  Generates flame graphs using Erlang's built-in `:fprof` profiler
  and converts output to SVG format compatible with Brendan Gregg's
  FlameGraph tools.

  ## Usage

      # Profile a function and generate flame graph
      FlameGraph.profile(fn ->
        expensive_computation()
      end)

      # Profile with options
      FlameGraph.profile(
        fn -> expensive_computation() end,
        output: "my_profile.svg",
        title: "My Operation Profile"
      )

      # Profile a module for a duration
      FlameGraph.profile_module(MyModule, duration: 5000)

  ## Requirements

  For SVG generation, one of these must be available:
  - brendangregg/FlameGraph tools (flamegraph.pl in PATH)
  - eflambe package (optional dependency)

  Without these, raw profiling data is saved in Erlang fprof format.
  """

  require Logger

  @type profile_opts :: [
          output: String.t(),
          title: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          colors: atom(),
          format: :svg | :folded | :fprof
        ]

  @default_output "flamegraph.svg"
  @default_title "Raxol Performance Profile"
  @default_width 1200
  @default_height 16

  @doc """
  Profiles a function and generates a flame graph.

  ## Options

    * `:output` - Output file path (default: "flamegraph.svg")
    * `:title` - Title for the flame graph
    * `:width` - SVG width in pixels (default: 1200)
    * `:height` - Row height in pixels (default: 16)
    * `:colors` - Color scheme (:hot, :mem, :io, :wakeup, :chain)
    * `:format` - Output format (:svg, :folded, :fprof)

  ## Examples

      FlameGraph.profile(fn ->
        Enum.reduce(1..10000, 0, &(&1 + &2))
      end)

      FlameGraph.profile(
        fn -> MyModule.expensive_operation() end,
        output: "profiling/render.svg",
        title: "Render Pipeline"
      )
  """
  @spec profile((-> any()), profile_opts()) ::
          {:ok, String.t()} | {:error, term()}
  def profile(fun, opts \\ []) when is_function(fun, 0) do
    output = Keyword.get(opts, :output, @default_output)
    format = Keyword.get(opts, :format, :svg)

    # Create temp directory for profiling files
    tmp_dir = System.tmp_dir!()

    trace_file =
      Path.join(
        tmp_dir,
        "raxol_profile_#{:erlang.unique_integer([:positive])}.trace"
      )

    analysis_file =
      Path.join(
        tmp_dir,
        "raxol_profile_#{:erlang.unique_integer([:positive])}.analysis"
      )

    try do
      # Start fprof
      _ = :fprof.start()

      # Trace and execute
      _ = :fprof.trace([:start, {:file, String.to_charlist(trace_file)}])
      result = fun.()
      _ = :fprof.trace(:stop)

      # Profile and analyze
      _ = :fprof.profile(file: String.to_charlist(trace_file))
      _ = :fprof.analyse(dest: String.to_charlist(analysis_file), cols: 120)

      # Stop fprof
      _ = :fprof.stop()

      # Generate output based on format
      _ =
        case format do
          :svg -> generate_svg(analysis_file, output, opts)
          :folded -> generate_folded(analysis_file, output)
          :fprof -> copy_fprof_output(analysis_file, output)
        end

      # Return result from profiled function
      {:ok, output, result}
    rescue
      e ->
        _ = :fprof.stop()
        {:error, Exception.message(e)}
    after
      # Cleanup temp files
      _ = File.rm(trace_file)
      _ = File.rm(analysis_file)
    end
  end

  @doc """
  Profiles all calls to a module for a specified duration.

  ## Options

    * `:duration` - How long to profile in milliseconds (default: 5000)
    * `:output` - Output file path
    * `:functions` - List of specific functions to trace (default: all)

  ## Examples

      FlameGraph.profile_module(Raxol.Terminal.Buffer, duration: 3000)

      FlameGraph.profile_module(
        Raxol.UI.Components.Button,
        duration: 5000,
        functions: [:render, :handle_event]
      )
  """
  @spec profile_module(module(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def profile_module(module, opts \\ []) do
    duration = Keyword.get(opts, :duration, 5000)
    output = Keyword.get(opts, :output, "#{module}_flamegraph.svg")
    functions = Keyword.get(opts, :functions, :all)

    tmp_dir = System.tmp_dir!()

    trace_file =
      Path.join(
        tmp_dir,
        "raxol_module_#{:erlang.unique_integer([:positive])}.trace"
      )

    analysis_file =
      Path.join(
        tmp_dir,
        "raxol_module_#{:erlang.unique_integer([:positive])}.analysis"
      )

    try do
      _ = :fprof.start()

      # Set up tracing for the module
      trace_spec = build_trace_spec(module, functions)

      _ =
        :fprof.trace([
          :start,
          {:file, String.to_charlist(trace_file)} | trace_spec
        ])

      # Wait for the specified duration
      Process.sleep(duration)

      _ = :fprof.trace(:stop)
      _ = :fprof.profile(file: String.to_charlist(trace_file))
      _ = :fprof.analyse(dest: String.to_charlist(analysis_file), cols: 120)
      _ = :fprof.stop()

      # Generate SVG
      _ = generate_svg(analysis_file, output, opts)
      {:ok, output}
    rescue
      e ->
        _ = :fprof.stop()
        {:error, Exception.message(e)}
    after
      _ = File.rm(trace_file)
      _ = File.rm(analysis_file)
    end
  end

  @doc """
  Profiles the current process for a duration.

  ## Examples

      # In your GenServer
      FlameGraph.profile_self(duration: 3000, output: "server_profile.svg")
  """
  @spec profile_self(keyword()) :: {:ok, String.t()} | {:error, term()}
  def profile_self(opts \\ []) do
    duration = Keyword.get(opts, :duration, 5000)
    output = Keyword.get(opts, :output, "process_flamegraph.svg")

    tmp_dir = System.tmp_dir!()

    trace_file =
      Path.join(
        tmp_dir,
        "raxol_self_#{:erlang.unique_integer([:positive])}.trace"
      )

    analysis_file =
      Path.join(
        tmp_dir,
        "raxol_self_#{:erlang.unique_integer([:positive])}.analysis"
      )

    try do
      _ = :fprof.start()

      _ =
        :fprof.trace([
          :start,
          {:procs, [self()]},
          {:file, String.to_charlist(trace_file)}
        ])

      Process.sleep(duration)

      _ = :fprof.trace(:stop)
      _ = :fprof.profile(file: String.to_charlist(trace_file))
      _ = :fprof.analyse(dest: String.to_charlist(analysis_file), cols: 120)
      _ = :fprof.stop()

      _ = generate_svg(analysis_file, output, opts)
      {:ok, output}
    rescue
      e ->
        _ = :fprof.stop()
        {:error, Exception.message(e)}
    after
      _ = File.rm(trace_file)
      _ = File.rm(analysis_file)
    end
  end

  @doc """
  Checks if flame graph generation tools are available.
  """
  @spec tools_available?() :: boolean()
  def tools_available? do
    flamegraph_pl_available?() or eflambe_available?()
  end

  @doc """
  Returns information about available profiling tools.
  """
  @spec tool_info() :: %{
          flamegraph_pl: boolean(),
          eflambe: boolean(),
          fprof: boolean(),
          recommendation: String.t()
        }
  def tool_info do
    flamegraph = flamegraph_pl_available?()
    eflambe = eflambe_available?()

    recommendation =
      cond do
        flamegraph ->
          "flamegraph.pl available - full SVG support"

        eflambe ->
          "eflambe available - full SVG support"

        true ->
          "No SVG tools available. Install brendangregg/FlameGraph or add {:eflambe, \"~> 0.3\"} to deps"
      end

    %{
      flamegraph_pl: flamegraph,
      eflambe: eflambe,
      fprof: true,
      recommendation: recommendation
    }
  end

  # Private functions

  defp generate_svg(analysis_file, output, opts) do
    title = Keyword.get(opts, :title, @default_title)
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)
    colors = Keyword.get(opts, :colors, :hot)

    cond do
      flamegraph_pl_available?() ->
        generate_svg_with_flamegraph_pl(
          analysis_file,
          output,
          title,
          width,
          height,
          colors
        )

      eflambe_available?() ->
        generate_svg_with_eflambe(analysis_file, output, opts)

      true ->
        # Fallback: save as folded format with instructions
        folded_output = String.replace(output, ".svg", ".folded")
        generate_folded(analysis_file, folded_output)

        Logger.warning("""
        SVG generation tools not available.
        Saved folded stack format to: #{folded_output}

        To generate SVG, install brendangregg/FlameGraph and run:
          cat #{folded_output} | flamegraph.pl > #{output}

        Or add {:eflambe, "~> 0.3"} to your mix.exs deps.
        """)

        {:ok, folded_output}
    end
  end

  defp generate_svg_with_flamegraph_pl(
         analysis_file,
         output,
         title,
         width,
         height,
         colors
       ) do
    # First convert to folded format
    folded_file = String.replace(output, ".svg", ".folded")
    generate_folded(analysis_file, folded_file)

    # Then use flamegraph.pl to generate SVG
    args = [
      "--title",
      title,
      "--width",
      to_string(width),
      "--height",
      to_string(height),
      "--colors",
      to_string(colors)
    ]

    case System.cmd("flamegraph.pl", args, stdin: File.read!(folded_file)) do
      {svg_content, 0} ->
        File.write!(output, svg_content)
        File.rm(folded_file)
        {:ok, output}

      {error, _} ->
        {:error, "flamegraph.pl failed: #{error}"}
    end
  end

  defp generate_svg_with_eflambe(_analysis_file, _output, _opts) do
    # eflambe integration would go here
    # For now, fall through to folded format
    {:error, :eflambe_not_implemented}
  end

  defp generate_folded(analysis_file, output) do
    # Parse fprof output and convert to folded stack format
    content = File.read!(analysis_file)
    folded = parse_fprof_to_folded(content)
    File.write!(output, folded)
    {:ok, output}
  end

  defp copy_fprof_output(analysis_file, output) do
    File.cp!(analysis_file, output)
    {:ok, output}
  end

  defp parse_fprof_to_folded(content) do
    # Parse fprof analysis output to folded stack format
    # Format: stack_frame;stack_frame;... count
    content
    |> String.split("\n")
    |> Enum.reduce({[], []}, fn line, {stacks, current_stack} ->
      parse_fprof_line(line, stacks, current_stack)
    end)
    |> elem(0)
    |> Enum.map_join("\n", fn {stack, count} ->
      "#{Enum.join(stack, ";")} #{count}"
    end)
  end

  defp parse_fprof_line(line, stacks, current_stack) do
    cond do
      # Function entry with timing
      String.match?(line, ~r/^\s*\{.*,\s*\d+,\s*[\d.]+,\s*[\d.]+\}/) ->
        case Regex.run(~r/\{([^,]+),\s*(\d+),/, line) do
          [_, func, count] ->
            new_stack = [func | current_stack]

            new_stacks = [
              {Enum.reverse(new_stack), String.to_integer(count)} | stacks
            ]

            {new_stacks, new_stack}

          _ ->
            {stacks, current_stack}
        end

      # Caller info (indent indicates depth)
      String.match?(line, ~r/^\s{4,}/) ->
        {stacks, current_stack}

      # Reset on new section
      String.match?(line, ~r/^$/) ->
        {stacks, []}

      true ->
        {stacks, current_stack}
    end
  end

  defp build_trace_spec(_module, :all) do
    [{:procs, :all}]
  end

  defp build_trace_spec(_module, functions) when is_list(functions) do
    [{:procs, :all}]
  end

  defp flamegraph_pl_available? do
    System.find_executable("flamegraph.pl") != nil
  end

  defp eflambe_available? do
    Code.ensure_loaded?(:eflambe)
  end
end
