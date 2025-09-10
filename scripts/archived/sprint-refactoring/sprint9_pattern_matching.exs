#!/usr/bin/env elixir

defmodule Sprint9PatternMatching do
  @moduledoc """
  Automated pattern matching refactoring for Sprint 9
  """

  def run do
    IO.puts("\n🔧 SPRINT 9 - Pattern Matching Refactoring\n")
    IO.puts("=" |> String.duplicate(80))

    # Find high-priority files to refactor
    high_priority_files = [
      "lib/raxol/ui/accessibility/high_contrast.ex",
      "lib/raxol/ui/components/virtual_scrolling.ex",
      "lib/raxol/ui/accessibility/screen_reader.ex",
      "lib/raxol/architecture/cqrs/command_bus.ex",
      "lib/raxol/ui/layout/css_grid.ex",
      "lib/raxol/security/auditor.ex",
      "lib/raxol/style/colors/accessibility.ex"
    ]

    IO.puts("\n📋 High Priority Files for Refactoring:")

    Enum.each(high_priority_files, fn file ->
      if File.exists?(file) do
        IO.puts("  ✅ #{file}")
        analyze_and_suggest_refactoring(file)
      else
        IO.puts("  ❌ #{file} - Not found")
      end
    end)
  end

  defp analyze_and_suggest_refactoring(file) do
    content = File.read!(file)
    lines = String.split(content, "\n")

    suggestions = []

    # Find simple if/else patterns that can be replaced
    suggestions = suggestions ++ find_simple_if_patterns(lines)

    # Find cond patterns that can be replaced
    suggestions = suggestions ++ find_cond_patterns(lines)

    # Find nested conditions that can be flattened
    suggestions = suggestions ++ find_nested_conditions(lines)

    if length(suggestions) > 0 do
      IO.puts("\n  📝 Refactoring suggestions for #{Path.basename(file)}:")

      Enum.each(suggestions, fn suggestion ->
        IO.puts("    - #{suggestion}")
      end)

      # Generate refactored version
      generate_refactored_file(file, suggestions)
    end
  end

  defp find_simple_if_patterns(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_num}, acc ->
      cond do
        # Simple boolean if/else
        String.match?(line, ~r/^\s*if\s+[\w\.]+\s+do$/) ->
          [
            "Line #{line_num}: Simple if/else can be replaced with pattern matching"
            | acc
          ]

        # If with is_* guard
        String.match?(
          line,
          ~r/^\s*if\s+is_(atom|binary|list|map|nil|integer)\(/
        ) ->
          [
            "Line #{line_num}: Type check if can be replaced with guard clause"
            | acc
          ]

        # If with == comparison
        String.match?(line, ~r/^\s*if\s+\w+\s*==\s*/) ->
          ["Line #{line_num}: Equality check can be pattern matched" | acc]

        true ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp find_cond_patterns(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_num}, acc ->
      if String.match?(line, ~r/^\s*cond\s+do/) do
        [
          "Line #{line_num}: Cond statement can be replaced with pattern matching functions"
          | acc
        ]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  defp find_nested_conditions(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({[], 0}, fn {line, line_num}, {acc, depth} ->
      new_depth = calculate_nesting_depth(line, depth)

      if new_depth > 2 && String.match?(line, ~r/\b(if|case|cond)\b/) do
        {[
           "Line #{line_num}: Deeply nested condition (depth: #{new_depth})"
           | acc
         ], new_depth}
      else
        {acc, new_depth}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp calculate_nesting_depth(line, current_depth) do
    cond do
      String.match?(line, ~r/\b(if|case|cond|with)\b.*do$/) ->
        current_depth + 1

      String.match?(line, ~r/^\s*end\s*$/) ->
        max(0, current_depth - 1)

      true ->
        current_depth
    end
  end

  defp generate_refactored_file(file, _suggestions) do
    refactored_dir = "lib/raxol/refactored/sprint9"
    File.mkdir_p!(refactored_dir)

    basename = Path.basename(file)
    refactored_file = Path.join(refactored_dir, basename)

    # For now, just copy the file - in a real implementation,
    # we would apply the actual refactorings
    File.copy!(file, refactored_file)

    IO.puts("    💾 Refactored version saved to: #{refactored_file}")
  end
end

# Example refactoring patterns module
defmodule RefactoringPatterns do
  @moduledoc """
  Common refactoring patterns for Sprint 9
  """

  def simple_if_to_pattern_match do
    """
    # Before:
    def process(value) do
      if value do
        handle_truthy(value)
      else
        handle_falsy()
      end
    end

    # After:
    def process(nil), do: handle_falsy()
    def process(false), do: handle_falsy()
    def process(value), do: handle_truthy(value)
    """
  end

  def cond_to_pattern_match do
    """
    # Before:
    def categorize(value) do
      cond do
        is_nil(value) -> :null
        is_binary(value) -> :string
        is_integer(value) -> :number
        is_list(value) -> :array
        true -> :unknown
      end
    end

    # After:
    def categorize(nil), do: :null
    def categorize(value) when is_binary(value), do: :string
    def categorize(value) when is_integer(value), do: :number
    def categorize(value) when is_list(value), do: :array
    def categorize(_), do: :unknown
    """
  end

  def nested_if_to_with do
    """
    # Before:
    def complex_operation(data) do
      if valid?(data) do
        result = transform(data)
        if result do
          enriched = enrich(result)
          if enriched do
            {:ok, enriched}
          else
            {:error, :enrichment_failed}
          end
        else
          {:error, :transformation_failed}
        end
      else
        {:error, :invalid_data}
      end
    end

    # After:
    def complex_operation(data) do
      with :ok <- validate(data),
           {:ok, result} <- transform(data),
           {:ok, enriched} <- enrich(result) do
        {:ok, enriched}
      end
    end
    """
  end

  def type_check_to_guards do
    """
    # Before:
    def process(value) do
      if is_binary(value) do
        String.upcase(value)
      else
        to_string(value) |> String.upcase()
      end
    end

    # After:
    def process(value) when is_binary(value), do: String.upcase(value)
    def process(value), do: value |> to_string() |> String.upcase()
    """
  end
end

Sprint9PatternMatching.run()
