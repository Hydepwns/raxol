defmodule Raxol.Core.Standards.ConsistencyChecker do
  @moduledoc """
  Automated code consistency checker for the Raxol codebase.

  This module analyzes code files and reports inconsistencies with
  established coding standards.
  """

  @type issue :: %{
          file: String.t(),
          line: non_neg_integer(),
          type: atom(),
          message: String.t(),
          severity: :error | :warning | :info
        }

  @type report :: %{
          total_files: non_neg_integer(),
          issues: [issue()],
          summary: map()
        }

  @doc """
  Checks a single file for consistency issues.
  """
  @spec check_file(String.t()) :: {:ok, [issue()]} | {:error, term()}
  def check_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, ast} <-
           Code.string_to_quoted(content, warn_on_unnecessary_quotes: false) do
      issues = analyze_file(file_path, content, ast)
      {:ok, issues}
    else
      {:error, reason} ->
        {:error, {:file_read_error, file_path, reason}}
    end
  end

  @doc """
  Checks all Elixir files in a directory recursively.
  """
  @spec check_directory(String.t()) :: {:ok, report()} | {:error, term()}
  def check_directory(dir_path) do
    case find_elixir_files(dir_path) do
      {:ok, files} ->
        issues =
          Enum.flat_map(files, fn file ->
            case check_file(file) do
              {:ok, file_issues} -> file_issues
              {:error, _} -> []
            end
          end)

        report = %{
          total_files: length(files),
          issues: issues,
          summary: summarize_issues(issues)
        }

        {:ok, report}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a detailed consistency report.
  """
  @spec generate_report(report()) :: String.t()
  def generate_report(%{total_files: total, issues: issues, summary: summary}) do
    """
    # Raxol Code Consistency Report

    Total files analyzed: #{total}
    Total issues found: #{length(issues)}

    ## Summary by Type
    #{format_summary(summary)}

    ## Detailed Issues
    #{format_issues(issues)}

    ## Recommendations
    #{generate_recommendations(summary)}
    """
  end

  # Private functions

  defp analyze_file(file_path, content, ast) do
    lines = String.split(content, "\n")

    []
    |> check_module_structure(file_path, ast)
    |> check_documentation(file_path, content, ast)
    |> check_naming_conventions(file_path, ast)
    |> check_error_handling(file_path, ast)
    |> check_genserver_patterns(file_path, ast)
    |> check_formatting(file_path, lines)
    |> check_imports_and_aliases(file_path, ast)
    |> Enum.map(&format_issue/1)
  end

  defp check_module_structure(issues, file_path, ast) do
    case ast do
      {:defmodule, _, [{:__aliases__, _, module_parts}, [do: body]]} ->
        # Check module name matches file path
        expected_module = path_to_module_name(file_path)
        actual_module = Enum.join(module_parts, ".")

        issues =
          if expected_module != actual_module do
            [
              {:module_name_mismatch, 1, file_path,
               "Module name #{actual_module} doesn't match file path", :error}
              | issues
            ]
          else
            issues
          end

        # Check for moduledoc
        if not has_moduledoc?(body) do
          [
            {:missing_moduledoc, 1, file_path, "Module is missing @moduledoc",
             :warning}
            | issues
          ]
        else
          issues
        end

      _ ->
        issues
    end
  end

  defp check_documentation(issues, file_path, _content, ast) do
    # Walk AST to find public functions without docs
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        {:def, meta, [{name, _, args}, _body]} = node, acc when is_list(args) ->
          line = Keyword.get(meta, :line, 0)

          # Check if previous node was @doc
          if not has_preceding_doc?(ast, line) do
            {node,
             [
               {:missing_doc, line, file_path,
                "Public function #{name}/#{length(args)} is missing @doc",
                :warning}
               | acc
             ]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  defp check_naming_conventions(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check function names
        {:def, meta, [{name, _, _}, _]} = node, acc ->
          line = Keyword.get(meta, :line, 0)
          name_str = to_string(name)

          cond do
            String.contains?(name_str, "__") and
                name_str not in ["__MODULE__", "__DIR__", "__ENV__"] ->
              {node,
               [
                 {:naming_convention, line, file_path,
                  "Function name #{name} contains double underscores", :warning}
                 | acc
               ]}

            String.match?(name_str, ~r/[A-Z]/) ->
              {node,
               [
                 {:naming_convention, line, file_path,
                  "Function name #{name} contains uppercase letters", :error}
                 | acc
               ]}

            true ->
              {node, acc}
          end

        # Check variable names
        {name, meta, nil} = node, acc when is_atom(name) ->
          line = Keyword.get(meta, :line, 0)
          name_str = to_string(name)

          if String.length(name_str) == 1 and
               name_str not in ["_", "x", "y", "z"] do
            {node,
             [
               {:naming_convention, line, file_path,
                "Single letter variable #{name} should be avoided", :info}
               | acc
             ]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  defp check_error_handling(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check for consistent error tuple usage
        {:ok, _} = node, acc ->
          {node, acc}

        {:error, _} = node, acc ->
          {node, acc}

        # Flag non-standard error returns
        {atom, meta, value} = node, acc
        when atom in [:ok, :error] and is_list(meta) ->
          if value != nil do
            line = Keyword.get(meta, :line, 0)

            {node,
             [
               {:error_handling, line, file_path,
                "Use tagged tuples {:ok, value} or {:error, reason} instead of bare atoms",
                :warning}
               | acc
             ]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  defp check_genserver_patterns(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check for proper callback implementation
        {:def, meta, [{:handle_call, _, [_, _, _]}, _]} = node, acc ->
          line = Keyword.get(meta, :line, 0)

          # Check if @impl true precedes it
          if not has_impl_attribute?(ast, line) do
            {node,
             [
               {:genserver_pattern, line, file_path,
                "GenServer callback missing @impl true", :warning}
               | acc
             ]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  defp check_formatting(issues, file_path, lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce(issues, fn {line, line_num}, acc ->
      cond do
        # Check line length
        String.length(line) > 120 ->
          [
            {:formatting, line_num, file_path, "Line exceeds 120 characters",
             :info}
            | acc
          ]

        # Check trailing whitespace
        String.match?(line, ~r/\s+$/) ->
          [
            {:formatting, line_num, file_path, "Line has trailing whitespace",
             :warning}
            | acc
          ]

        # Check tabs vs spaces
        String.contains?(line, "\t") ->
          [
            {:formatting, line_num, file_path,
             "Line contains tabs (use spaces)", :error}
            | acc
          ]

        true ->
          acc
      end
    end)
  end

  defp check_imports_and_aliases(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check alias ordering
        {:alias, meta, [{:__aliases__, _, parts}]} = node, acc ->
          _line = Keyword.get(meta, :line, 0)
          _alias_name = Enum.join(parts, ".")

          # Would need to track previous aliases to check ordering
          {node, acc}

        # Check for unnecessary imports
        {:import, meta, [module | _opts]} = node, acc ->
          line = Keyword.get(meta, :line, 0)

          # Flag broad imports without :only
          case module do
            {:__aliases__, _, parts} when parts != [] ->
              if not has_only_option?(node) do
                {node,
                 [
                   {:import_style, line, file_path,
                    "Import without :only option may import too many functions",
                    :info}
                   | acc
                 ]}
              else
                {node, acc}
              end

            _ ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  # Helper functions

  defp find_elixir_files(dir_path) do
    case File.ls(dir_path) do
      {:ok, _} ->
        files = Path.wildcard(Path.join(dir_path, "**/*.ex"))
        exs_files = Path.wildcard(Path.join(dir_path, "**/*.exs"))
        {:ok, files ++ exs_files}

      {:error, reason} ->
        {:error, {:directory_error, dir_path, reason}}
    end
  end

  defp path_to_module_name(file_path) do
    file_path
    |> Path.rootname()
    |> Path.split()
    |> Enum.drop_while(&(&1 != "lib"))
    |> Enum.drop(1)
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join(".")
  end

  defp has_moduledoc?({:__block__, _, nodes}) do
    Enum.any?(nodes, fn
      {:@, _, [{:moduledoc, _, _}]} -> true
      _ -> false
    end)
  end

  defp has_moduledoc?(_), do: false

  defp has_preceding_doc?(_ast, _line) do
    # Simplified implementation - in a real implementation,
    # we would walk the AST to check if there's a @doc attribute
    # before the function definition at the given line
    false
  end

  defp has_impl_attribute?(_ast, _line) do
    # Simplified implementation - in a real implementation,
    # we would walk the AST to check if there's a @impl attribute
    # before the callback definition at the given line
    false
  end

  defp has_only_option?({:import, _, [_module, opts]}) when is_list(opts) do
    Keyword.has_key?(opts, :only)
  end

  defp has_only_option?(_), do: false

  defp format_issue({type, line, file, message, severity}) do
    %{
      file: file,
      line: line,
      type: type,
      message: message,
      severity: severity
    }
  end

  defp format_issue(%{
         type: type,
         line: line,
         file: file,
         message: message,
         severity: severity
       }) do
    %{
      file: file,
      line: line,
      type: type,
      message: message,
      severity: severity
    }
  end

  defp summarize_issues(issues) do
    issues
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Map.new()
  end

  defp format_summary(summary) do
    summary
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.map(fn {type, count} ->
      "- #{format_type(type)}: #{count}"
    end)
    |> Enum.join("\n")
  end

  defp format_issues(issues) do
    issues
    |> Enum.map(&format_issue/1)
    |> Enum.group_by(& &1.file)
    |> Enum.map(fn {file, file_issues} ->
      """
      ### #{file}
      #{format_file_issues(file_issues)}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_file_issues(issues) do
    issues
    |> Enum.sort_by(& &1.line)
    |> Enum.map(fn issue ->
      "- Line #{issue.line} [#{issue.severity}]: #{issue.message}"
    end)
    |> Enum.join("\n")
  end

  defp format_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp generate_recommendations(summary) do
    recommendations = []

    recommendations =
      if Map.get(summary, :missing_moduledoc, 0) > 0 do
        ["Add @moduledoc documentation to all modules" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(summary, :missing_doc, 0) > 0 do
        ["Add @doc documentation to all public functions" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(summary, :error_handling, 0) > 0 do
        [
          "Use consistent {:ok, result} | {:error, reason} patterns"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if Map.get(summary, :formatting, 0) > 0 do
        ["Run mix format to fix formatting issues" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      "No specific recommendations. Code follows standards well!"
    else
      recommendations
      |> Enum.with_index(1)
      |> Enum.map(fn {rec, idx} -> "#{idx}. #{rec}" end)
      |> Enum.join("\n")
    end
  end
end
