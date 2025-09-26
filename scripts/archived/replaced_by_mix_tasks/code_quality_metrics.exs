#!/usr/bin/env elixir

defmodule CodeQualityMetrics do
  @moduledoc """
  Script to analyze code quality metrics for the Raxol codebase.
  Tracks imperative patterns and functional programming adherence.
  """

  def run do
    IO.puts("\n[CHECK] Raxol Code Quality Metrics Analysis")
    IO.puts("=" |> String.duplicate(50))
    
    lib_files = find_elixir_files("lib")
    test_files = find_elixir_files("test")
    all_files = lib_files ++ test_files
    
    IO.puts("\n[REPORT] File Statistics:")
    IO.puts("  Library files: #{length(lib_files)}")
    IO.puts("  Test files: #{length(test_files)}")
    IO.puts("  Total files: #{length(all_files)}")
    
    # Analyze patterns
    metrics = %{
      process_dict: analyze_pattern(lib_files, ~r/Process\.(get|put)\(/),
      try_catch: analyze_pattern(all_files, ~r/try\s+do/),
      with_statements: analyze_pattern(all_files, ~r/with\s+[{:%]/),
      if_else: analyze_pattern(all_files, ~r/\bif\s+.+\s+do/),
      cond_statements: analyze_pattern(all_files, ~r/\bcond\s+do/),
      pattern_matching: analyze_pattern(all_files, ~r/def\s+\w+\([^)]*%\{/),
      agents: analyze_pattern(lib_files, ~r/Agent\.(get|update|cast|start)/),
      genservers: analyze_pattern(lib_files, ~r/GenServer\.(call|cast|start)/),
      ets_usage: analyze_pattern(lib_files, ~r/:ets\.(new|insert|lookup|delete)/),
      imperative_loops: analyze_imperative_loops(all_files)
    }
    
    print_metrics(metrics)
    calculate_score(metrics)
    save_report(metrics)
  end
  
  defp find_elixir_files(dir) do
    Path.wildcard("#{dir}/**/*.{ex,exs}")
    |> Enum.reject(&String.contains?(&1, "_build"))
    |> Enum.reject(&String.contains?(&1, "deps"))
  end
  
  defp analyze_pattern(files, pattern) do
    files
    |> Enum.map(fn file ->
      content = File.read!(file)
      matches = Regex.scan(pattern, content)
      {file, length(matches)}
    end)
    |> Enum.filter(fn {_, count} -> count > 0 end)
    |> Enum.sort_by(fn {_, count} -> -count end)
  end
  
  defp analyze_imperative_loops(files) do
    patterns = [
      ~r/for\s+.+\s+<-\s+.+\s+do/,
      ~r/Enum\.each\(/,
      ~r/\|>\s*Enum\.each\(/
    ]
    
    files
    |> Enum.map(fn file ->
      content = File.read!(file)
      total = patterns
        |> Enum.map(fn pattern -> 
          Regex.scan(pattern, content) |> length()
        end)
        |> Enum.sum()
      {file, total}
    end)
    |> Enum.filter(fn {_, count} -> count > 0 end)
    |> Enum.sort_by(fn {_, count} -> -count end)
  end
  
  defp print_metrics(metrics) do
    IO.puts("\n[TARGET] Code Quality Metrics:\n")
    
    print_metric("[FAIL] Process Dictionary Usage", metrics.process_dict, :critical)
    print_metric("[WARN]  Try/Catch Blocks", metrics.try_catch, :high)
    print_metric("[OK] With Statements", metrics.with_statements, :good)
    print_metric("🔄 If/Else Statements", metrics.if_else, :medium)
    print_metric("🔄 Cond Statements", metrics.cond_statements, :low)
    print_metric("[OK] Pattern Matching in Functions", metrics.pattern_matching, :good)
    print_metric("📦 Agent Usage", metrics.agents, :medium)
    print_metric("[OK] GenServer Usage", metrics.genservers, :good)
    print_metric("💾 ETS Tables", metrics.ets_usage, :low)
    print_metric("[WARN]  Imperative Loops", metrics.imperative_loops, :high)
  end
  
  defp print_metric(label, data, severity) do
    total = data |> Enum.map(fn {_, count} -> count end) |> Enum.sum()
    file_count = length(data)
    
    color = case severity do
      :critical -> "\e[31m"  # Red
      :high -> "\e[33m"      # Yellow
      :medium -> "\e[36m"    # Cyan
      :low -> "\e[35m"       # Magenta
      :good -> "\e[32m"      # Green
      _ -> "\e[0m"
    end
    
    IO.puts("#{color}#{label}\e[0m")
    IO.puts("  Total occurrences: #{total}")
    IO.puts("  Files affected: #{file_count}")
    
    if file_count > 0 do
      IO.puts("  Top 3 files:")
      data
      |> Enum.take(3)
      |> Enum.each(fn {file, count} ->
        short_file = file |> String.replace(~r/^lib\//, "") |> String.replace(~r/^test\//, "t/")
        IO.puts("    - #{short_file}: #{count}")
      end)
    end
    IO.puts("")
  end
  
  defp calculate_score(metrics) do
    # Calculate a functional programming score
    process_dict_count = count_total(metrics.process_dict)
    try_catch_count = count_total(metrics.try_catch)
    with_count = count_total(metrics.with_statements)
    if_else_count = count_total(metrics.if_else)
    pattern_match_count = count_total(metrics.pattern_matching)
    genserver_count = count_total(metrics.genservers)
    imperative_count = count_total(metrics.imperative_loops)
    
    # Scoring formula (higher is better)
    good_patterns = with_count + pattern_match_count + genserver_count
    bad_patterns = process_dict_count + try_catch_count + imperative_count + (if_else_count / 10)
    
    score = if bad_patterns > 0 do
      (good_patterns / bad_patterns * 100) |> Float.round(2)
    else
      100.0
    end
    
    grade = cond do
      score >= 80 -> "A"
      score >= 60 -> "B"
      score >= 40 -> "C"
      score >= 20 -> "D"
      true -> "F"
    end
    
    IO.puts("=" |> String.duplicate(50))
    IO.puts("\n📈 Functional Programming Score: #{score}/100 (Grade: #{grade})")
    IO.puts("\nRecommendations:")
    
    if process_dict_count > 0 do
      IO.puts("  🔴 CRITICAL: Eliminate all #{process_dict_count} Process dictionary calls")
    end
    
    if try_catch_count > 10 do
      IO.puts("  🟠 HIGH: Replace #{try_catch_count} try/catch blocks with 'with' statements")
    end
    
    if imperative_count > 50 do
      IO.puts("  🟡 MEDIUM: Refactor #{imperative_count} imperative loops to functional pipelines")
    end
    
    if with_count < 100 do
      IO.puts("  💡 TIP: Increase usage of 'with' statements for better error handling")
    end
    
    IO.puts("")
  end
  
  defp count_total(data) do
    data |> Enum.map(fn {_, count} -> count end) |> Enum.sum()
  end
  
  defp save_report(metrics) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    report = %{
      timestamp: timestamp,
      metrics: %{
        process_dictionary: count_total(metrics.process_dict),
        try_catch: count_total(metrics.try_catch),
        with_statements: count_total(metrics.with_statements),
        if_else: count_total(metrics.if_else),
        cond_statements: count_total(metrics.cond_statements),
        pattern_matching: count_total(metrics.pattern_matching),
        agents: count_total(metrics.agents),
        genservers: count_total(metrics.genservers),
        ets_tables: count_total(metrics.ets_usage),
        imperative_loops: count_total(metrics.imperative_loops)
      },
      files: %{
        process_dict_files: length(metrics.process_dict),
        try_catch_files: length(metrics.try_catch),
        imperative_loop_files: length(metrics.imperative_loops)
      }
    }
    
    File.mkdir_p!("metrics")
    File.write!("metrics/code_quality_#{Date.utc_today()}.json", Jason.encode!(report, pretty: true))
    
    IO.puts("[REPORT] Report saved to metrics/code_quality_#{Date.utc_today()}.json")
  end
end

# Run the analysis
CodeQualityMetrics.run()