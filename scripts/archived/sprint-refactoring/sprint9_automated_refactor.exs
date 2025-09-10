#!/usr/bin/env elixir

defmodule Sprint9AutomatedRefactor do
  @moduledoc """
  Automated refactoring tool for Sprint 9 - Pattern Matching improvements
  """

  def run do
    IO.puts("\n🤖 SPRINT 9 - Automated Pattern Matching Refactoring\n")
    IO.puts("=" |> String.duplicate(80))

    # Start with simple if/else to guard clause transformations
    refactor_simple_type_checks()

    # Then handle cond statements
    refactor_cond_statements()

    # Fix clause grouping in GenServers
    fix_genserver_clause_grouping()

    IO.puts("\n✅ Refactoring complete! Run tests to verify changes.")
  end

  defp refactor_simple_type_checks do
    IO.puts("\n📝 Refactoring simple type checks to guard clauses...")

    patterns = [
      # is_binary check
      {~r/if\s+is_binary\((\w+)\),\s*do:\s*(.+),\s*else:\s*(.+)/,
       fn
         [_, var, true_branch, false_branch] ->
           """
           def helper(#{var}) when is_binary(#{var}), do: #{true_branch}
           def helper(#{var}), do: #{false_branch}
           """

         _ ->
           nil
       end},

      # is_nil check
      {~r/if\s+is_nil\((\w+)\),\s*do:\s*(.+),\s*else:\s*(.+)/,
       fn
         [_, var, true_branch, false_branch] ->
           """
           def helper(nil), do: #{true_branch}
           def helper(#{var}), do: #{false_branch}
           """

         _ ->
           nil
       end},

      # Equality check
      {~r/if\s+(\w+)\s*==\s*(\w+),\s*do:\s*(.+),\s*else:\s*(.+)/,
       fn
         [_, var1, var2, true_branch, false_branch] ->
           if var2 =~ ~r/^[A-Z]/ or var2 =~ ~r/^:/ do
             # It's a constant or atom
             """
             case #{var1} do
               #{var2} -> #{true_branch}
               _ -> #{false_branch}
             end
             """
           else
             # Skip variable comparisons
             nil
           end

         _ ->
           nil
       end}
    ]

    files_modified = 0

    Path.wildcard("lib/**/*.ex")
    |> Enum.each(fn file ->
      content = File.read!(file)
      modified = false

      new_content =
        Enum.reduce(patterns, content, fn {pattern, replacer}, acc ->
          if Regex.match?(pattern, acc) do
            modified = true

            Regex.replace(pattern, acc, fn match, captures ->
              replacer.([match | captures]) || match
            end)
          else
            acc
          end
        end)

      if modified do
        # File.write!(file, new_content)
        files_modified = files_modified + 1
        IO.puts("  Modified: #{Path.relative_to(file, "lib/raxol/")}")
      end
    end)

    IO.puts("  Total files that would be modified: #{files_modified}")
  end

  defp refactor_cond_statements do
    IO.puts("\n📝 Analyzing cond statements for refactoring...")

    # Find files with cond statements
    files_with_cond =
      Path.wildcard("lib/**/*.ex")
      |> Enum.filter(fn file ->
        File.read!(file) |> String.contains?("cond do")
      end)

    IO.puts("  Found #{length(files_with_cond)} files with cond statements")

    # Analyze each file
    files_with_cond
    # Process first 5 as examples
    |> Enum.take(5)
    |> Enum.each(fn file ->
      analyze_cond_in_file(file)
    end)
  end

  defp analyze_cond_in_file(file) do
    content = File.read!(file)
    lines = String.split(content, "\n")

    # Find cond blocks
    cond_blocks = find_cond_blocks(lines)

    if length(cond_blocks) > 0 do
      IO.puts("\n  File: #{Path.relative_to(file, "lib/raxol/")}")

      Enum.each(cond_blocks, fn {start_line, conditions} ->
        IO.puts(
          "    Line #{start_line}: cond with #{length(conditions)} conditions"
        )

        if can_convert_to_pattern_match?(conditions) do
          IO.puts("      ✅ Can be converted to pattern matching")
          suggest_pattern_match_conversion(conditions)
        else
          IO.puts("      ⚠️  Complex conditions - manual refactoring needed")
        end
      end)
    end
  end

  defp find_cond_blocks(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({[], nil, []}, fn {line, idx},
                                     {blocks, current_start, conditions} ->
      cond do
        String.contains?(line, "cond do") ->
          {blocks, idx, []}

        current_start && String.match?(line, ~r/^\s*end\s*$/) ->
          {[{current_start, Enum.reverse(conditions)} | blocks], nil, []}

        current_start && String.contains?(line, "->") ->
          {blocks, current_start, [extract_condition(line) | conditions]}

        true ->
          {blocks, current_start, conditions}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp extract_condition(line) do
    # Extract the condition part before ->
    case String.split(line, "->", parts: 2) do
      [condition, _action] -> String.trim(condition)
      _ -> nil
    end
  end

  defp can_convert_to_pattern_match?(conditions) do
    # Check if all conditions are simple type checks or comparisons
    Enum.all?(conditions, fn condition ->
      condition &&
        (String.match?(condition, ~r/^is_\w+\(/) ||
           String.match?(condition, ~r/^\w+\s*==\s*/) ||
           String.match?(condition, ~r/^\w+\s+in\s+/) ||
           condition == "true")
    end)
  end

  defp suggest_pattern_match_conversion(conditions) do
    IO.puts("      Suggested conversion:")

    Enum.each(conditions, fn condition ->
      cond do
        String.match?(condition, ~r/^is_(\w+)\((\w+)\)/) ->
          [_, type, var] = Regex.run(~r/^is_(\w+)\((\w+)\)/, condition)

          IO.puts(
            "        def function(#{var}) when is_#{type}(#{var}), do: ..."
          )

        String.match?(condition, ~r/^(\w+)\s*==\s*(.+)/) ->
          [_, var, value] = Regex.run(~r/^(\w+)\s*==\s*(.+)/, condition)
          IO.puts("        def function(#{value}), do: ...")

        String.match?(condition, ~r/^(\w+)\s+in\s+(.+)/) ->
          [_, var, range] = Regex.run(~r/^(\w+)\s+in\s+(.+)/, condition)

          IO.puts(
            "        def function(#{var}) when #{var} in #{range}, do: ..."
          )

        condition == "true" ->
          IO.puts("        def function(_), do: ... # default case")

        true ->
          IO.puts("        # Complex: #{condition}")
      end
    end)
  end

  defp fix_genserver_clause_grouping do
    IO.puts("\n📝 Fixing GenServer clause grouping...")

    genserver_files =
      Path.wildcard("lib/**/*{server,manager}.ex")
      |> Enum.filter(fn file ->
        content = File.read!(file)

        String.contains?(content, "use GenServer") ||
          String.contains?(content, "def handle_call") ||
          String.contains?(content, "def handle_cast")
      end)

    IO.puts("  Found #{length(genserver_files)} GenServer modules")

    # Check for clause grouping issues
    issues =
      genserver_files
      |> Enum.map(fn file ->
        check_clause_grouping(file)
      end)
      |> Enum.filter(fn {_file, has_issue} -> has_issue end)

    IO.puts("  Files with clause grouping issues: #{length(issues)}")

    Enum.each(issues, fn {file, _} ->
      IO.puts("    - #{Path.relative_to(file, "lib/raxol/")}")
    end)
  end

  defp check_clause_grouping(file) do
    content = File.read!(file)
    lines = String.split(content, "\n")

    # Look for non-grouped handle_* functions
    handle_functions =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _} ->
        String.match?(line, ~r/^\s*def\s+handle_(call|cast|info)/)
      end)

    # Check if they're properly grouped
    has_issue = check_if_scattered(handle_functions)

    {file, has_issue}
  end

  defp check_if_scattered(functions) do
    # Group by function type
    grouped =
      functions
      |> Enum.group_by(fn {line, _idx} ->
        cond do
          String.contains?(line, "handle_call") -> :call
          String.contains?(line, "handle_cast") -> :cast
          String.contains?(line, "handle_info") -> :info
          true -> :other
        end
      end)

    # Check if any group is scattered (non-consecutive line numbers)
    Enum.any?(grouped, fn {_type, funcs} ->
      if length(funcs) > 1 do
        indices = Enum.map(funcs, fn {_, idx} -> idx end) |> Enum.sort()

        # Check if indices are not consecutive (allowing for function bodies)
        Enum.zip(indices, tl(indices))
        # Allow up to 50 lines between clauses
        |> Enum.any?(fn {a, b} -> b - a > 50 end)
      else
        false
      end
    end)
  end
end

# Run the refactoring tool
Sprint9AutomatedRefactor.run()
