#!/usr/bin/env elixir

defmodule Sprint9Analysis do
  @moduledoc """
  Analyzes codebase for Sprint 9 pattern matching and optimization opportunities
  """

  def run do
    IO.puts("\n🔍 SPRINT 9 ANALYSIS - Pattern Matching & Optimizations\n")
    IO.puts("=" |> String.duplicate(80))
    
    lib_files = Path.wildcard("lib/**/*.ex")
    test_files = Path.wildcard("test/**/*.ex")
    all_files = lib_files ++ test_files
    
    IO.puts("\n📊 File Statistics:")
    IO.puts("  Library files: #{length(lib_files)}")
    IO.puts("  Test files: #{length(test_files)}")
    IO.puts("  Total files: #{length(all_files)}")
    
    # Analyze patterns
    patterns = analyze_patterns(lib_files)
    
    IO.puts("\n🎯 Pattern Analysis (lib/ only):")
    IO.puts("\n1. IF/ELSE Patterns:")
    IO.puts("   Total if statements: #{patterns.if_count}")
    IO.puts("   Files with most if statements:")
    patterns.if_by_file
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    |> Enum.each(fn {file, count} ->
      short_file = String.replace(file, "lib/raxol/", "")
      IO.puts("     #{count} - #{short_file}")
    end)
    
    IO.puts("\n2. COND Patterns:")
    IO.puts("   Total cond statements: #{patterns.cond_count}")
    IO.puts("   Files with most cond statements:")
    patterns.cond_by_file
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    |> Enum.each(fn {file, count} ->
      short_file = String.replace(file, "lib/raxol/", "")
      IO.puts("     #{count} - #{short_file}")
    end)
    
    IO.puts("\n3. Try/Catch Patterns:")
    IO.puts("   Total try/catch blocks: #{patterns.try_count}")
    IO.puts("   Files with most try/catch blocks:")
    patterns.try_by_file
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    |> Enum.each(fn {file, count} ->
      short_file = String.replace(file, "lib/raxol/", "")
      IO.puts("     #{count} - #{short_file}")
    end)
    
    IO.puts("\n4. Deprecation Issues:")
    IO.puts("   Logger.warn calls: #{patterns.logger_warn_count}")
    IO.puts("   Single-quoted strings: #{patterns.charlist_count}")
    
    IO.puts("\n5. Complex Functions (candidates for refactoring):")
    patterns.complex_functions
    |> Enum.sort_by(&elem(&1, 2), :desc)
    |> Enum.take(15)
    |> Enum.each(fn {file, func, complexity} ->
      short_file = String.replace(file, "lib/raxol/", "")
      IO.puts("   #{complexity} - #{short_file}:#{func}")
    end)
    
    IO.puts("\n📈 Optimization Opportunities:")
    IO.puts("   Functions with nested conditions: #{length(patterns.nested_conditions)}")
    IO.puts("   Case statements that could be function heads: #{patterns.case_to_function_count}")
    IO.puts("   Guard clause opportunities: #{patterns.guard_opportunities}")
    
    IO.puts("\n✅ Recommended Refactoring Priority:")
    IO.puts("   1. Replace #{patterns.simple_if_count} simple if/else with pattern matching")
    IO.puts("   2. Convert #{patterns.cond_count} cond statements to pattern matching functions")
    IO.puts("   3. Refactor #{patterns.try_count} remaining try/catch blocks")
    IO.puts("   4. Update #{patterns.logger_warn_count} Logger.warn to Logger.warning")
    IO.puts("   5. Fix clause grouping in #{patterns.clause_grouping_count} GenServer modules")
    
    generate_refactoring_plan(patterns)
  end
  
  defp analyze_patterns(files) do
    Enum.reduce(files, initial_state(), fn file, acc ->
      content = File.read!(file)
      lines = String.split(content, "\n")
      
      acc
      |> count_if_statements(file, lines)
      |> count_cond_statements(file, lines)
      |> count_try_catch(file, lines)
      |> count_deprecations(file, lines)
      |> analyze_complexity(file, lines)
      |> find_optimization_opportunities(file, lines)
    end)
  end
  
  defp initial_state do
    %{
      if_count: 0,
      if_by_file: %{},
      simple_if_count: 0,
      cond_count: 0,
      cond_by_file: %{},
      try_count: 0,
      try_by_file: %{},
      logger_warn_count: 0,
      charlist_count: 0,
      complex_functions: [],
      nested_conditions: [],
      case_to_function_count: 0,
      guard_opportunities: 0,
      clause_grouping_count: 0
    }
  end
  
  defp count_if_statements(acc, file, lines) do
    if_count = Enum.count(lines, &String.match?(&1, ~r/^\s*if\s+/))
    simple_if = Enum.count(lines, &String.match?(&1, ~r/^\s*if\s+.*do\s*$/))
    
    %{acc |
      if_count: acc.if_count + if_count,
      if_by_file: Map.update(acc.if_by_file, file, if_count, &(&1 + if_count)),
      simple_if_count: acc.simple_if_count + simple_if
    }
  end
  
  defp count_cond_statements(acc, file, lines) do
    cond_count = Enum.count(lines, &String.match?(&1, ~r/^\s*cond\s+do/))
    
    %{acc |
      cond_count: acc.cond_count + cond_count,
      cond_by_file: Map.update(acc.cond_by_file, file, cond_count, &(&1 + cond_count))
    }
  end
  
  defp count_try_catch(acc, file, lines) do
    try_count = Enum.count(lines, &String.match?(&1, ~r/^\s*try\s+do/))
    
    %{acc |
      try_count: acc.try_count + try_count,
      try_by_file: Map.update(acc.try_by_file, file, try_count, &(&1 + try_count))
    }
  end
  
  defp count_deprecations(acc, file, lines) do
    logger_warn = Enum.count(lines, &String.contains?(&1, "Logger.warn"))
    charlist = Enum.count(lines, &String.match?(&1, ~r/'[^']+'/))
    
    %{acc |
      logger_warn_count: acc.logger_warn_count + logger_warn,
      charlist_count: acc.charlist_count + charlist
    }
  end
  
  defp analyze_complexity(acc, file, lines) do
    # Find functions with high cyclomatic complexity
    functions = extract_functions(lines)
    
    complex_functions = 
      functions
      |> Enum.map(fn {name, body} ->
        complexity = calculate_complexity(body)
        {file, name, complexity}
      end)
      |> Enum.filter(fn {_, _, complexity} -> complexity > 5 end)
    
    %{acc | complex_functions: acc.complex_functions ++ complex_functions}
  end
  
  defp extract_functions(lines) do
    lines
    |> Enum.with_index()
    |> Enum.reduce({[], nil, []}, fn {line, _idx}, {functions, current_func, body} ->
      cond do
        String.match?(line, ~r/^\s*def(p)?\s+\w+/) ->
          func_name = extract_function_name(line)
          if current_func do
            {[{current_func, body} | functions], func_name, [line]}
          else
            {functions, func_name, [line]}
          end
        
        current_func && String.match?(line, ~r/^\s*end\s*$/) ->
          {[{current_func, body ++ [line]} | functions], nil, []}
        
        current_func ->
          {functions, current_func, body ++ [line]}
        
        true ->
          {functions, current_func, body}
      end
    end)
    |> elem(0)
  end
  
  defp extract_function_name(line) do
    case Regex.run(~r/def(p)?\s+(\w+)/, line) do
      [_, _, name] -> name
      [_, name] -> name
      _ -> "unknown"
    end
  end
  
  defp calculate_complexity(body) do
    body
    |> Enum.reduce(1, fn line, acc ->
      conditions = 
        String.split(line, ~r/\b(if|unless|cond|case|when|catch|rescue)\b/)
        |> length()
        |> Kernel.-(1)
      
      acc + conditions
    end)
  end
  
  defp find_optimization_opportunities(acc, file, lines) do
    # Count nested conditions
    nested = count_nested_conditions(lines)
    
    # Find case statements that could be function heads
    case_to_func = count_case_to_function_opportunities(lines)
    
    # Find guard clause opportunities
    guard_ops = count_guard_opportunities(lines)
    
    # Check for clause grouping issues
    clause_grouping = if String.contains?(file, "server.ex") || String.contains?(file, "manager.ex") do
      check_clause_grouping(lines)
    else
      0
    end
    
    %{acc |
      nested_conditions: (if nested > 0, do: [{file, nested} | acc.nested_conditions], else: acc.nested_conditions),
      case_to_function_count: acc.case_to_function_count + case_to_func,
      guard_opportunities: acc.guard_opportunities + guard_ops,
      clause_grouping_count: acc.clause_grouping_count + clause_grouping
    }
  end
  
  defp count_nested_conditions(lines) do
    lines
    |> Enum.reduce({0, 0}, fn line, {depth, max_depth} ->
      new_depth = 
        cond do
          String.match?(line, ~r/\b(if|cond|case)\b/) -> depth + 1
          String.match?(line, ~r/^\s*end\s*$/) -> max(0, depth - 1)
          true -> depth
        end
      
      {new_depth, max(max_depth, new_depth)}
    end)
    |> elem(1)
  end
  
  defp count_case_to_function_opportunities(lines) do
    lines
    |> Enum.count(&String.match?(&1, ~r/^\s*case\s+.*\s+do$/))
  end
  
  defp count_guard_opportunities(lines) do
    lines
    |> Enum.count(&String.match?(&1, ~r/^\s*if\s+is_(atom|binary|list|map|integer|float|number|nil)/))
  end
  
  defp check_clause_grouping(lines) do
    lines
    |> Enum.chunk_by(&String.match?(&1, ~r/^\s*def\s+handle_(call|cast|info)/))
    |> Enum.count(fn chunk ->
      Enum.any?(chunk, &String.match?(&1, ~r/^\s*def\s+handle_(call|cast|info)/))
    end)
    |> then(&if &1 > 3, do: 1, else: 0)
  end
  
  defp generate_refactoring_plan(patterns) do
    plan_file = "scripts/sprint9_refactoring_plan.md"
    
    content = """
    # Sprint 9 Refactoring Plan
    
    Generated: #{DateTime.utc_now() |> DateTime.to_string()}
    
    ## Phase 1: Quick Wins (Day 1)
    
    ### Logger.warn → Logger.warning
    - Files to update: #{patterns.logger_warn_count}
    - Automated with: `find lib -name "*.ex" -exec sed -i '' 's/Logger\.warn/Logger.warning/g' {} +`
    
    ### Simple if/else → Pattern Matching
    Target: #{patterns.simple_if_count} simple conditionals
    
    Example transformation:
    ```elixir
    # Before
    if condition do
      action_a()
    else
      action_b()
    end
    
    # After
    case condition do
      true -> action_a()
      false -> action_b()
    end
    ```
    
    ## Phase 2: Cond Elimination (Day 2)
    
    Target: #{patterns.cond_count} cond statements
    
    Strategy:
    1. Convert to pattern matching functions
    2. Use guard clauses
    3. Implement decision tables for complex logic
    
    ## Phase 3: Complex Refactoring (Day 3-4)
    
    ### High Complexity Functions
    Focus on functions with complexity > 10:
    #{patterns.complex_functions |> Enum.take(5) |> Enum.map(fn {f, n, c} -> "- #{f}:#{n} (complexity: #{c})" end) |> Enum.join("\n")}
    
    ### Nested Conditions
    Files with deep nesting:
    #{patterns.nested_conditions |> Enum.take(5) |> Enum.map(fn {f, d} -> "- #{f} (depth: #{d})" end) |> Enum.join("\n")}
    
    ## Phase 4: Performance Optimization (Day 5)
    
    ### ETS Caching Strategy
    - Implement for frequently accessed data
    - Add TTL mechanisms
    - Monitor cache hit rates
    
    ### GenServer Optimization
    - Batch operations where possible
    - Implement backpressure mechanisms
    - Add circuit breakers for external calls
    
    ## Success Metrics
    
    - [ ] 0 Logger.warn calls
    - [ ] <100 if statements (from #{patterns.if_count})
    - [ ] 0 cond statements (from #{patterns.cond_count})
    - [ ] <50 try/catch blocks (from #{patterns.try_count})
    - [ ] All GenServer modules with proper clause grouping
    - [ ] Memory usage < 2.5MB per session
    - [ ] 10% performance improvement in hot paths
    """
    
    File.write!(plan_file, content)
    IO.puts("\n📝 Refactoring plan written to: #{plan_file}")
  end
end

Sprint9Analysis.run()