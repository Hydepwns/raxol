defmodule Raxol.Core.ErrorTemplates do
  @moduledoc """
  Enhanced error message templates for Phase 4.3 Error Experience.

  Provides contextual, actionable error messages that reference:
  - Phase 3 performance optimizations and targets
  - Phase 4.2 development tools for debugging
  - Specific fix suggestions with confidence ratings
  - Interactive recovery workflows
  """

  @type template_context :: map()
  @type error_template :: %{
          title: String.t(),
          description: String.t(),
          phase3_context: String.t() | nil,
          suggested_actions: [String.t()],
          related_tools: [atom()],
          recovery_steps: [String.t()],
          confidence: float()
        }

  # Performance-related error templates
  @performance_templates %{
    :parser_slow => %{
      title: "Parser Performance Below Target",
      description: """
      ANSI sequence parsing is taking longer than the Phase 3 target of 3.3μs/op.

      Current performance may indicate:
      - Complex nested sequences overwhelming the parser
      - Parser state cache misses
      - Memory pressure affecting allocation speed
      """,
      phase3_context: "Phase 3 target: 3.3μs/op average parsing time",
      suggested_actions: [
        "mix raxol.analyze --depth comprehensive --benchmark",
        "mix raxol.profile --module Raxol.Terminal.ANSI.Parser",
        "Check for parser state cache configuration"
      ],
      related_tools: [:raxol_analyze, :raxol_profile],
      recovery_steps: [
        "1. Run performance analysis to identify bottlenecks",
        "2. Check if parser state caching is enabled",
        "3. Consider reducing sequence complexity",
        "4. Verify memory usage is under 2.8MB target"
      ],
      confidence: 0.9
    },
    :memory_limit_exceeded => %{
      title: "Memory Usage Exceeds Phase 3 Target",
      description: """
      Application memory usage has exceeded the Phase 3 optimization target of 2.8MB per session.

      This may indicate:
      - Buffer pooling not properly configured
      - Memory leaks in component lifecycle
      - ETS table growth beyond expected bounds
      - Render batching queues accumulating
      """,
      phase3_context: "Phase 3 target: 2.8MB maximum memory per session",
      suggested_actions: [
        "mix raxol.debug --trace \"*\" --memory-threshold 2.8MB",
        "Enable automatic buffer pooling optimization",
        "Check ETS table usage patterns",
        "Review component lifecycle for memory leaks"
      ],
      related_tools: [:raxol_debug, :raxol_profile],
      recovery_steps: [
        "1. Start debug console to monitor memory usage",
        "2. Enable buffer pooling if not already active",
        "3. Force garbage collection and measure impact",
        "4. Identify largest memory consumers"
      ],
      confidence: 0.95
    },
    :render_batch_overflow => %{
      title: "Render Batch Queue Overflow",
      description: """
      The render batching system from Phase 3 optimizations has exceeded capacity.

      Possible causes:
      - Too many rapid UI updates overwhelming the batcher
      - Damage tracking not properly reducing render scope
      - Adaptive frame rate not throttling effectively
      - Component optimization markers missing
      """,
      phase3_context: "Phase 3 render batching with adaptive frame rate system",
      suggested_actions: [
        "mix raxol.debug --trace \"Raxol.UI.Rendering.*\"",
        "Check components for @raxol_optimized attribute",
        "Verify damage tracking is reducing render regions",
        "Review adaptive frame rate configuration"
      ],
      related_tools: [:raxol_debug, :raxol_gen_component],
      recovery_steps: [
        "1. Debug render pipeline to identify bottleneck",
        "2. Verify components have optimization markers",
        "3. Check if damage tracking is working correctly",
        "4. Consider reducing update frequency"
      ],
      confidence: 0.85
    }
  }

  # Component lifecycle error templates
  @component_templates %{
    :missing_optimization_marker => %{
      title: "Component Missing Phase 3 Optimizations",
      description: """
      Component created without Phase 3 optimization markers.

      Components should include:
      - @raxol_optimized true attribute
      - Damage tracking integration
      - Render batching compatibility
      - Proper lifecycle hooks
      """,
      phase3_context:
        "Phase 3 requires @raxol_optimized attribute for performance tracking",
      suggested_actions: [
        "Add @raxol_optimized true to component module",
        "mix raxol.gen.component YourComponent --optimized",
        "Review component against Phase 3 patterns",
        "Update existing components with optimization markers"
      ],
      related_tools: [:raxol_gen_component],
      recovery_steps: [
        "1. Add @raxol_optimized true attribute to module",
        "2. Implement damage tracking in render function",
        "3. Ensure component uses render batching",
        "4. Test component with mix raxol.analyze"
      ],
      confidence: 0.8
    },
    :component_lifecycle_error => %{
      title: "Component Lifecycle Integration Issue",
      description: """
      Component lifecycle hooks are not properly integrated with Phase 3 optimizations.

      Common issues:
      - Missing damage tracking callbacks
      - Render batching not implemented
      - State updates bypassing optimization layer
      """,
      phase3_context:
        "Phase 3 requires proper lifecycle integration for optimizations",
      suggested_actions: [
        "Review component lifecycle implementation",
        "mix raxol.debug --component YourComponent",
        "Check render function integration with damage tracking"
      ],
      related_tools: [:raxol_debug, :raxol_gen_component],
      recovery_steps: [
        "1. Debug component lifecycle events",
        "2. Verify render function uses damage tracking",
        "3. Check state update patterns",
        "4. Ensure optimization attributes are set"
      ],
      confidence: 0.75
    }
  }

  # Terminal I/O error templates  
  @terminal_templates %{
    :ansi_parse_error => %{
      title: "ANSI Sequence Parse Error",
      description: """
      Failed to parse ANSI escape sequence, which may indicate:
      - Malformed or non-standard sequence
      - Parser state corruption
      - Unsupported sequence type
      - Performance degradation affecting parser
      """,
      phase3_context:
        "Phase 3 parser optimizations target 3.3μs/op with full ANSI compliance",
      suggested_actions: [
        "mix raxol.analyze --target lib/raxol/terminal/ansi/",
        "Check sequence against ANSI standards",
        "Verify parser state is not corrupted",
        "Test with known-good sequences"
      ],
      related_tools: [:raxol_analyze, :raxol_debug],
      recovery_steps: [
        "1. Analyze parser performance and accuracy",
        "2. Test with simpler ANSI sequences",
        "3. Check for parser state issues",
        "4. Verify sequence format compliance"
      ],
      confidence: 0.8
    },
    :terminal_buffer_overflow => %{
      title: "Terminal Buffer Capacity Exceeded",
      description: """
      Terminal buffer has exceeded capacity limits set by Phase 3 optimizations.

      This may indicate:
      - Buffer pooling not properly limiting growth
      - Rapid terminal output overwhelming buffers
      - Memory pressure detection not triggering
      - ETS table growth beyond expected bounds
      """,
      phase3_context:
        "Phase 3 buffer pooling should prevent overflow through memory management",
      suggested_actions: [
        "Enable buffer pooling memory pressure detection",
        "mix raxol.debug --memory --buffer-stats",
        "Check terminal output rate and volume",
        "Verify ETS table size limits"
      ],
      related_tools: [:raxol_debug, :raxol_profile],
      recovery_steps: [
        "1. Enable memory pressure detection",
        "2. Check buffer pool configuration",
        "3. Monitor buffer usage patterns",
        "4. Consider output rate limiting"
      ],
      confidence: 0.85
    }
  }

  # Development tool integration error templates
  @tool_templates %{
    :tool_integration_failed => %{
      title: "Phase 4.2 Development Tool Integration Failed",
      description: """
      Failed to integrate with Phase 4.2 development tools for enhanced debugging.

      Possible issues:
      - Mix tasks not properly installed
      - Tool dependencies missing
      - Compilation errors preventing tool loading
      - Permissions issues with tool execution
      """,
      phase3_context:
        "Phase 4.2 tools provide insights into Phase 3 optimizations",
      suggested_actions: [
        "Verify mix raxol.* tasks are available with 'mix help'",
        "Check compilation errors with 'mix compile'",
        "Ensure proper permissions for tool execution",
        "Reinstall tools if necessary"
      ],
      related_tools: [
        :raxol_analyze,
        :raxol_profile,
        :raxol_debug,
        :raxol_gen_component
      ],
      recovery_steps: [
        "1. Check if Mix tasks are compiled and available",
        "2. Verify no compilation errors exist",
        "3. Test basic tool functionality",
        "4. Check file permissions and access"
      ],
      confidence: 0.7
    }
  }

  @doc """
  Get an enhanced error template based on error type and context.
  """
  def get_template(error_type, context \\ %{})

  def get_template(error_type, context) when is_atom(error_type) do
    template = find_template_by_type(error_type)

    if template do
      enhance_template(template, context)
    else
      get_generic_template(error_type, context)
    end
  end

  def get_template(error, context) when not is_atom(error) do
    error_type = classify_error_type(error)
    get_template(error_type, context)
  end

  @doc """
  Generate a formatted error message with Phase 3/4 context.
  """
  def format_error_message(template, _context \\ %{}) do
    """
    #{IO.ANSI.red()}#{IO.ANSI.bright()}#{template.title}#{IO.ANSI.reset()}
    #{String.duplicate("=", String.length(template.title))}

    #{template.description}

    #{if template.phase3_context do
      IO.ANSI.blue() <> "Phase 3 Context:" <> IO.ANSI.reset() <> "\n" <> template.phase3_context <> "\n"
    else
      ""
    end}
    #{IO.ANSI.green()}Suggested Actions:#{IO.ANSI.reset()}
    #{format_action_list(template.suggested_actions)}

    #{if length(template.related_tools) > 0 do
      IO.ANSI.cyan() <> "Related Tools:" <> IO.ANSI.reset() <> "\n" <> format_tool_list(template.related_tools) <> "\n"
    else
      ""
    end}
    #{IO.ANSI.yellow()}Recovery Steps:#{IO.ANSI.reset()}
    #{format_step_list(template.recovery_steps)}

    #{IO.ANSI.magenta()}Confidence: #{format_confidence(template.confidence)}#{IO.ANSI.reset()}
    """
  end

  @doc """
  Get all available templates for a category.
  """
  def get_templates_by_category(category) do
    case category do
      :performance -> @performance_templates
      :component -> @component_templates
      :terminal -> @terminal_templates
      :tools -> @tool_templates
      _ -> %{}
    end
  end

  @doc """
  Get template suggestions based on error pattern matching.
  """
  def suggest_templates(error_text) when is_binary(error_text) do
    lower_text = String.downcase(error_text)

    all_templates()
    |> Enum.filter(fn {_key, template} ->
      String.contains?(lower_text, extract_keywords(template))
    end)
    |> Enum.sort_by(fn {_key, template} -> template.confidence end, :desc)
    |> Enum.take(3)
  end

  # Private implementation

  @spec find_template_by_type(any()) :: any()
  defp find_template_by_type(error_type) do
    all_templates()[error_type]
  end

  defp all_templates do
    Map.merge(@performance_templates, @component_templates)
    |> Map.merge(@terminal_templates)
    |> Map.merge(@tool_templates)
  end

  @spec classify_error_type(any()) :: any()
  defp classify_error_type(error) do
    error_text = inspect(error) |> String.downcase()

    cond do
      String.contains?(error_text, ["parse", "parser", "slow"]) ->
        :parser_slow

      String.contains?(error_text, ["memory", "limit", "exceeded"]) ->
        :memory_limit_exceeded

      String.contains?(error_text, ["render", "batch", "overflow"]) ->
        :render_batch_overflow

      String.contains?(error_text, ["optimization", "marker"]) ->
        :missing_optimization_marker

      String.contains?(error_text, ["lifecycle", "component"]) ->
        :component_lifecycle_error

      String.contains?(error_text, ["ansi", "sequence", "parse"]) ->
        :ansi_parse_error

      String.contains?(error_text, ["buffer", "overflow", "terminal"]) ->
        :terminal_buffer_overflow

      String.contains?(error_text, ["tool", "integration", "mix"]) ->
        :tool_integration_failed

      true ->
        :generic_error
    end
  end

  @spec enhance_template(any(), any()) :: any()
  defp enhance_template(template, context) do
    enhanced_actions = enhance_actions(template.suggested_actions, context)
    enhanced_steps = enhance_steps(template.recovery_steps, context)

    %{
      template
      | suggested_actions: enhanced_actions,
        recovery_steps: enhanced_steps,
        confidence: adjust_confidence(template.confidence, context)
    }
  end

  @spec enhance_actions(any(), any()) :: any()
  defp enhance_actions(actions, context) do
    actions
    |> Enum.map_join(fn action ->
      action
      |> String.replace(
        "YourComponent",
        Map.get(context, :component_name, "YourComponent")
      )
      |> String.replace(
        "YourModule",
        Map.get(context, :module_name, "YourModule")
      )
    end)
  end

  @spec enhance_steps(any(), any()) :: any()
  defp enhance_steps(steps, context) do
    steps
    |> Enum.map(fn step ->
      step
      |> String.replace(
        "YourComponent",
        Map.get(context, :component_name, "YourComponent")
      )
    end)
  end

  @spec adjust_confidence(String.t() | integer(), any()) :: any()
  defp adjust_confidence(base_confidence, context) do
    adjustments = [
      if(Map.has_key?(context, :performance_metrics), do: 0.1, else: 0),
      if(Map.has_key?(context, :component_name), do: 0.05, else: 0),
      if(Map.has_key?(context, :phase3_context), do: 0.1, else: 0)
    ]

    adjusted = base_confidence + Enum.sum(adjustments)
    min(1.0, adjusted)
  end

  @spec get_generic_template(any(), any()) :: any() | nil
  defp get_generic_template(error_type, _context) do
    %{
      title: "Raxol Application Error",
      description: """
      An error occurred in your Raxol application.

      Error type: #{error_type}

      This error can be investigated using the Phase 4.2 development tools
      that provide insights into Phase 3 performance optimizations.
      """,
      phase3_context: "Use Phase 4.2 tools to investigate performance impact",
      suggested_actions: [
        "mix raxol.debug --trace \"*\"",
        "mix raxol.analyze --target .",
        "Check application logs for additional context"
      ],
      related_tools: [:raxol_debug, :raxol_analyze],
      recovery_steps: [
        "1. Start debug console to investigate",
        "2. Check recent code changes",
        "3. Verify Phase 3 optimizations are working",
        "4. Review error logs for patterns"
      ],
      confidence: 0.5
    }
  end

  @spec extract_keywords(any()) :: any()
  defp extract_keywords(template) do
    [
      String.downcase(template.title),
      String.downcase(template.description)
    ]
    |> Enum.join(" ")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
  end

  @spec format_action_list(any()) :: String.t()
  defp format_action_list(actions) do
    actions
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {action, index} ->
      "  #{index}. #{action}"
    end)
  end

  @spec format_step_list(any()) :: String.t()
  defp format_step_list(steps) do
    steps
    |> Enum.map_join("\n", fn step ->
      "  #{step}"
    end)
  end

  @spec format_tool_list(any()) :: String.t()
  defp format_tool_list(tools) do
    tools
    |> Enum.map_join("\n", fn tool ->
      "  • mix #{tool |> to_string() |> String.replace("_", ".")}"
    end)
  end

  @spec format_confidence(String.t() | integer()) :: String.t()
  defp format_confidence(confidence) do
    bar_length = 10
    filled_length = round(confidence * bar_length)

    bar =
      String.duplicate("█", filled_length) <>
        String.duplicate("░", bar_length - filled_length)

    "#{bar} #{round(confidence * 100)}%"
  end
end
