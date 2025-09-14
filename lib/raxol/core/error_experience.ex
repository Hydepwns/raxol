defmodule Raxol.Core.ErrorExperience do
  @moduledoc """
  Enhanced error experience system for Raxol applications.

  Phase 4.3 enhancement that provides intelligent error handling with:
  - Contextual fix suggestions based on Phase 3 optimizations
  - Integration with Phase 4.2 development tools
  - Pattern learning for common error scenarios
  - Interactive error recovery workflows

  ## Features

  - Smart error classification with performance context
  - Automatic fix suggestions using Phase 3 knowledge
  - Integration with `mix raxol.analyze` and `mix raxol.debug`
  - Error pattern learning and prevention
  - Interactive recovery console
  """

  alias Raxol.Core.ErrorHandler
  require Logger

  @type error_category ::
          :performance
          | :compilation
          | :runtime
          | :ui_rendering
          | :terminal_io
          | :component_lifecycle
          | :optimization
          | :integration

  @type fix_suggestion :: %{
          type: :automatic | :guided | :manual | :documentation,
          description: String.t(),
          action: String.t() | nil,
          confidence: float(),
          related_tools: [atom()],
          phase3_context: map() | nil
        }

  @type enhanced_error :: %{
          original_error: term(),
          category: error_category(),
          severity: ErrorHandler.error_severity(),
          context: map(),
          suggestions: [fix_suggestion()],
          performance_impact: :none | :low | :medium | :high | :critical,
          related_optimizations: [String.t()],
          recovery_options: [atom()]
        }

  # Error patterns learned from Phase 3 work
  @performance_patterns %{
    slow_parsing: %{
      indicators: [:timeout, :performance_warning, "parser took"],
      suggestions: [
        %{
          type: :guided,
          description: "Parser performance below 3.3μs/op target",
          action: "mix raxol.analyze --depth comprehensive --benchmark",
          confidence: 0.9,
          related_tools: [:raxol_analyze, :raxol_profile],
          phase3_context: %{optimization: "parser_caching", target: "3.3μs/op"}
        }
      ]
    },
    memory_pressure: %{
      indicators: [:memory_limit, :allocation_failed, "memory usage"],
      suggestions: [
        %{
          type: :automatic,
          description: "Memory usage above 2.8MB threshold detected",
          action: "Enable buffer pooling and garbage collection optimization",
          confidence: 0.8,
          related_tools: [:raxol_debug, :raxol_profile],
          phase3_context: %{optimization: "buffer_pooling", target: "2.8MB"}
        }
      ]
    },
    render_batch_failure: %{
      indicators: [:render_timeout, :batch_overflow, "render queue"],
      suggestions: [
        %{
          type: :guided,
          description: "Render batching system overloaded",
          action: "mix raxol.debug --trace \"Raxol.UI.Rendering.*\"",
          confidence: 0.85,
          related_tools: [:raxol_debug, :raxol_analyze],
          phase3_context: %{
            optimization: "render_batching",
            system: "damage_tracking"
          }
        }
      ]
    }
  }

  @doc """
  Enhanced error handling with intelligent suggestions and recovery.
  """
  def handle_enhanced_error(error, context \\ %{}) do
    enhanced = classify_and_enhance(error, context)

    # Log with Phase 3 context
    log_enhanced_error(enhanced)

    # Trigger appropriate Phase 4.2 tools if available
    maybe_trigger_analysis_tools(enhanced)

    # Return enhanced error for interactive handling
    enhanced
  end

  @doc """
  Classify error and provide enhancement based on Phase 3 patterns.
  """
  def classify_and_enhance(error, context) do
    category = classify_error(error, context)
    suggestions = generate_suggestions(error, category, context)
    performance_impact = assess_performance_impact(error, context)
    related_opts = find_related_optimizations(error, category)

    %{
      original_error: error,
      category: category,
      severity: determine_severity(error, performance_impact),
      context: enrich_context(context, category),
      suggestions: suggestions,
      performance_impact: performance_impact,
      related_optimizations: related_opts,
      recovery_options: determine_recovery_options(category, performance_impact)
    }
  end

  @doc """
  Classify error type for reporting purposes.
  """
  def classify_error_type(error) do
    classify_error(error, %{})
  end

  @doc """
  Interactive error recovery console.
  """
  def start_recovery_console(enhanced_error) do
    IO.puts(
      "\n" <> IO.ANSI.red() <> "Raxol Error Recovery Console" <> IO.ANSI.reset()
    )

    IO.puts(String.duplicate("=", 35))

    display_error_summary(enhanced_error)
    display_suggestions(enhanced_error.suggestions)

    if enhanced_error.performance_impact != :none do
      display_performance_context(enhanced_error)
    end

    handle_recovery_interaction(enhanced_error)
  end

  @doc """
  Generate automatic error report for learning system.
  """
  def generate_error_report(enhanced_error) do
    report = %{
      timestamp: DateTime.utc_now(),
      error_id: generate_error_id(enhanced_error),
      category: enhanced_error.category,
      severity: enhanced_error.severity,
      performance_impact: enhanced_error.performance_impact,
      context: enhanced_error.context,
      suggestions_used: [],
      resolution_outcome: :pending,
      phase3_metrics: extract_phase3_metrics(enhanced_error)
    }

    store_error_report(report)
    report
  end

  # Private implementation

  defp classify_error(error, context) do
    error_string = inspect(error) |> String.downcase()

    cond do
      String.contains?(error_string, ["parse", "ansi", "sequence"]) ->
        :terminal_io

      String.contains?(error_string, ["render", "damage", "batch"]) ->
        :ui_rendering

      String.contains?(error_string, ["component", "lifecycle"]) ->
        :component_lifecycle

      String.contains?(error_string, ["memory", "allocation", "buffer"]) ->
        :performance

      String.contains?(error_string, ["timeout", "slow", "latency"]) ->
        :performance

      String.contains?(error_string, ["compilation", "syntax"]) ->
        :compilation

      String.contains?(error_string, ["optimization", "phase3"]) ->
        :optimization

      Map.has_key?(context, :performance_metrics) ->
        :performance

      true ->
        :runtime
    end
  end

  defp generate_suggestions(error, category, context) do
    # Pattern-based suggestions from Phase 3 experience
    pattern_suggestions = find_pattern_suggestions(error)

    # Category-specific suggestions
    category_suggestions =
      case category do
        :performance -> performance_suggestions(error, context)
        :ui_rendering -> rendering_suggestions(error, context)
        :terminal_io -> terminal_suggestions(error, context)
        :optimization -> optimization_suggestions(error, context)
        _ -> general_suggestions(error, context)
      end

    (pattern_suggestions ++ category_suggestions)
    |> Enum.uniq_by(& &1.description)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  defp find_pattern_suggestions(error) do
    error_text = inspect(error) |> String.downcase()

    @performance_patterns
    |> Enum.flat_map(fn {_pattern_name, pattern} ->
      if Enum.any?(
           pattern.indicators,
           &String.contains?(error_text, to_string(&1))
         ) do
        pattern.suggestions
      else
        []
      end
    end)
  end

  defp performance_suggestions(_error, context) do
    base_suggestions = [
      %{
        type: :guided,
        description: "Analyze performance with Phase 3 tools",
        action: "mix raxol.analyze --target . --benchmark",
        confidence: 0.8,
        related_tools: [:raxol_analyze],
        phase3_context: %{component: "performance_analyzer"}
      },
      %{
        type: :guided,
        description: "Profile with real-time monitoring",
        action: "mix raxol.profile --live --threshold 1",
        confidence: 0.8,
        related_tools: [:raxol_profile],
        phase3_context: %{component: "interactive_profiler"}
      }
    ]

    # Add context-specific suggestions
    if Map.get(context, :memory_usage, 0) > 2_800_000 do
      memory_suggestion = %{
        type: :automatic,
        description: "Memory usage exceeds Phase 3 target (2.8MB)",
        action: "Enable buffer pooling optimization",
        confidence: 0.9,
        related_tools: [:raxol_debug],
        phase3_context: %{target: "2.8MB", current: context.memory_usage}
      }

      [memory_suggestion | base_suggestions]
    else
      base_suggestions
    end
  end

  defp rendering_suggestions(_error, _context) do
    [
      %{
        type: :guided,
        description: "Debug render pipeline with damage tracking",
        action: "mix raxol.debug --trace \"Raxol.UI.Rendering.*\"",
        confidence: 0.85,
        related_tools: [:raxol_debug],
        phase3_context: %{
          system: "damage_tracking",
          optimization: "render_batching"
        }
      },
      %{
        type: :manual,
        description: "Check component for optimization markers",
        action: "Verify @raxol_optimized attribute is set",
        confidence: 0.7,
        related_tools: [:raxol_gen_component],
        phase3_context: %{pattern: "optimization_marker"}
      }
    ]
  end

  defp terminal_suggestions(_error, _context) do
    [
      %{
        type: :guided,
        description: "Analyze ANSI parsing performance",
        action: "mix raxol.analyze --depth comprehensive",
        confidence: 0.8,
        related_tools: [:raxol_analyze],
        phase3_context: %{target: "3.3μs/op", component: "ansi_parser"}
      }
    ]
  end

  defp optimization_suggestions(_error, _context) do
    [
      %{
        type: :documentation,
        description: "Review Phase 3 optimization guide",
        action: "Check docs/performance/phase3_optimizations.md",
        confidence: 0.6,
        related_tools: [],
        phase3_context: %{documentation: "phase3_guide"}
      }
    ]
  end

  defp general_suggestions(_error, _context) do
    [
      %{
        type: :guided,
        description: "Start debug console for investigation",
        action: "mix raxol.debug",
        confidence: 0.5,
        related_tools: [:raxol_debug],
        phase3_context: nil
      }
    ]
  end

  defp assess_performance_impact(error, context) do
    error_text = inspect(error) |> String.downcase()

    cond do
      String.contains?(error_text, ["critical", "crash", "abort"]) -> :critical
      String.contains?(error_text, ["timeout", "slow", "latency"]) -> :high
      String.contains?(error_text, ["memory", "allocation"]) -> :medium
      String.contains?(error_text, ["warning", "deprecated"]) -> :low
      Map.get(context, :performance_degradation, false) -> :medium
      true -> :none
    end
  end

  defp find_related_optimizations(_error, category) do
    case category do
      :performance ->
        ["parser_caching", "buffer_pooling", "memory_pressure_detection"]

      :ui_rendering ->
        ["damage_tracking", "render_batching", "adaptive_frame_rate"]

      :terminal_io ->
        ["ansi_parsing", "parser_state_caching"]

      :optimization ->
        ["phase3_all"]

      _ ->
        []
    end
  end

  defp determine_severity(error, performance_impact) do
    case {error, performance_impact} do
      {_, :critical} -> :critical
      {{:error, _}, :high} -> :error
      {_, :high} -> :warning
      {{:error, _}, _} -> :warning
      {_, :medium} -> :info
      _ -> :debug
    end
  end

  defp enrich_context(context, category) do
    base_context =
      Map.merge(context, %{
        category: category,
        phase: "4.3_error_experience",
        tools_available: available_tools()
      })

    case category do
      :performance ->
        Map.merge(base_context, %{
          phase3_targets: %{parser: "3.3μs/op", memory: "2.8MB"},
          analysis_tools: [:raxol_analyze, :raxol_profile]
        })

      :ui_rendering ->
        Map.merge(base_context, %{
          render_system: "damage_tracking_batching",
          debug_tools: [:raxol_debug]
        })

      _ ->
        base_context
    end
  end

  defp determine_recovery_options(category, performance_impact) do
    base_options = [:retry, :ignore, :debug]

    case {category, performance_impact} do
      {:performance, impact} when impact in [:high, :critical] ->
        [:analyze, :profile, :optimize] ++ base_options

      {:ui_rendering, _} ->
        [:debug_render, :check_optimizations] ++ base_options

      {:terminal_io, _} ->
        [:analyze_parser, :check_ansi] ++ base_options

      _ ->
        base_options
    end
  end

  defp available_tools do
    [
      :raxol_analyze,
      :raxol_profile,
      :raxol_debug,
      :raxol_gen_component
    ]
  end

  defp display_error_summary(enhanced_error) do
    IO.puts("\n" <> IO.ANSI.yellow() <> "Error Summary:" <> IO.ANSI.reset())
    IO.puts("Category: #{enhanced_error.category}")
    IO.puts("Severity: #{enhanced_error.severity}")
    IO.puts("Performance Impact: #{enhanced_error.performance_impact}")

    if enhanced_error.related_optimizations != [] do
      IO.puts(
        "Related Phase 3 Optimizations: #{Enum.join(enhanced_error.related_optimizations, ", ")}"
      )
    end
  end

  defp display_suggestions(suggestions) do
    IO.puts("\n" <> IO.ANSI.green() <> "Fix Suggestions:" <> IO.ANSI.reset())

    suggestions
    |> Enum.with_index(1)
    |> Enum.each(fn {suggestion, index} ->
      confidence_bar = String.duplicate("█", round(suggestion.confidence * 10))
      IO.puts("#{index}. #{suggestion.description}")

      if suggestion.action do
        IO.puts(
          "   Action: #{IO.ANSI.cyan()}#{suggestion.action}#{IO.ANSI.reset()}"
        )
      end

      IO.puts(
        "   Confidence: #{confidence_bar} (#{trunc(suggestion.confidence * 100)}%)"
      )

      if suggestion.phase3_context do
        IO.puts("   Phase 3 Context: #{inspect(suggestion.phase3_context)}")
      end

      IO.puts("")
    end)
  end

  defp display_performance_context(enhanced_error) do
    IO.puts(
      "\n" <> IO.ANSI.magenta() <> "Performance Context:" <> IO.ANSI.reset()
    )

    IO.puts("Impact Level: #{enhanced_error.performance_impact}")

    if enhanced_error.context[:phase3_targets] do
      targets = enhanced_error.context[:phase3_targets]
      IO.puts("Phase 3 Targets: #{inspect(targets)}")
    end

    IO.puts(
      "Available Analysis Tools: #{inspect(enhanced_error.context[:analysis_tools] || [])}"
    )
  end

  defp handle_recovery_interaction(enhanced_error) do
    IO.puts("\n" <> IO.ANSI.blue() <> "Recovery Options:" <> IO.ANSI.reset())

    enhanced_error.recovery_options
    |> Enum.with_index(1)
    |> Enum.each(fn {option, index} ->
      IO.puts("#{index}. #{format_recovery_option(option)}")
    end)

    IO.puts("#{length(enhanced_error.recovery_options) + 1}. Exit")

    choice = IO.gets("Select option: ") |> String.trim() |> String.to_integer()

    if choice <= length(enhanced_error.recovery_options) do
      option = Enum.at(enhanced_error.recovery_options, choice - 1)
      execute_recovery_option(option, enhanced_error)
    end
  end

  defp format_recovery_option(option) do
    case option do
      :retry -> "Retry operation"
      :ignore -> "Ignore and continue"
      :debug -> "Start debug console"
      :analyze -> "Run performance analysis"
      :profile -> "Start interactive profiler"
      :optimize -> "Apply automatic optimizations"
      :debug_render -> "Debug rendering pipeline"
      :check_optimizations -> "Check Phase 3 optimizations"
      :analyze_parser -> "Analyze parser performance"
      :check_ansi -> "Check ANSI sequence handling"
      _ -> to_string(option)
    end
  end

  defp execute_recovery_option(option, _enhanced_error) do
    case option do
      :analyze ->
        IO.puts("Starting performance analysis...")
        System.cmd("mix", ["raxol.analyze", "--target", ".", "--benchmark"])

      :profile ->
        IO.puts("Starting interactive profiler...")
        System.cmd("mix", ["raxol.profile", "--live"])

      :debug ->
        IO.puts("Starting debug console...")
        System.cmd("mix", ["raxol.debug"])

      :debug_render ->
        IO.puts("Starting render pipeline debugging...")
        System.cmd("mix", ["raxol.debug", "--trace", "Raxol.UI.Rendering.*"])

      _ ->
        IO.puts("Executing #{option}...")
        :ok
    end
  end

  defp log_enhanced_error(enhanced_error) do
    level =
      case enhanced_error.severity do
        :critical -> :error
        :error -> :error
        :warning -> :warning
        :info -> :info
        :debug -> :debug
      end

    Logger.log(level, "Enhanced error detected",
      category: enhanced_error.category,
      performance_impact: enhanced_error.performance_impact,
      suggestions_count: length(enhanced_error.suggestions),
      phase3_context: enhanced_error.context[:phase3_targets]
    )
  end

  defp maybe_trigger_analysis_tools(enhanced_error) do
    # Auto-trigger tools for critical performance issues
    case enhanced_error.performance_impact do
      :critical ->
        IO.puts("Critical performance impact detected. Starting analysis...")

        Task.start(fn ->
          System.cmd("mix", ["raxol.analyze", "--depth", "comprehensive"])
        end)

      :high ->
        IO.puts(
          "High performance impact detected. Consider running: mix raxol.analyze"
        )

      _ ->
        :ok
    end
  end

  defp extract_phase3_metrics(enhanced_error) do
    %{
      targets_referenced: enhanced_error.context[:phase3_targets],
      optimizations_involved: enhanced_error.related_optimizations,
      tools_suggested:
        enhanced_error.suggestions
        |> Enum.flat_map(& &1.related_tools)
        |> Enum.uniq()
    }
  end

  defp generate_error_id(enhanced_error) do
    :crypto.hash(:md5, inspect(enhanced_error.original_error))
    |> Base.encode16(case: :lower)
    |> String.slice(0..7)
  end

  defp store_error_report(report) do
    # Store in tmp for now - in production would use proper storage
    reports_dir = "/tmp/raxol_error_reports"
    File.mkdir_p!(reports_dir)

    filename = "#{report.error_id}_#{DateTime.to_unix(report.timestamp)}.json"
    filepath = Path.join(reports_dir, filename)

    File.write!(filepath, Jason.encode!(report, pretty: true))
  end
end
