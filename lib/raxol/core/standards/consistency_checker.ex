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

  @doc """
  Analyzes a file's AST and content for consistency issues.

  This function is useful for testing or when you already have the content
  and AST available and want to bypass file I/O.
  """
  @spec analyze_file(String.t(), String.t(), any()) :: any()
  def analyze_file(file_path, content, ast) do
    lines = String.split(content, "\n")

    []
    |> check_module_structure(file_path, ast)
    |> check_documentation(file_path, content, ast)
    |> check_naming_conventions(file_path, ast)
    |> check_error_handling(file_path, ast)
    |> check_genserver_patterns(file_path, ast)
    |> check_formatting(file_path, lines)
    |> check_imports_and_aliases(file_path, ast)
  end

  # Helper to create issue maps
  @spec create_issue(any(), any(), any(), String.t(), any()) :: any()
  defp create_issue(type, line, file, message, severity) do
    %{
      type: type,
      line: line,
      file: file,
      message: message,
      severity: severity
    }
  end

  @spec check_module_structure(any(), String.t(), any()) :: any()
  defp check_module_structure(issues, file_path, ast) do
    case ast do
      {:defmodule, _, [{:__aliases__, _, module_parts}, [do: body]]} ->
        # Check module name matches file path
        expected_module = path_to_module_name(file_path)
        actual_module = Enum.join(module_parts, ".")

        issues =
          check_module_name_match(
            expected_module,
            actual_module,
            file_path,
            issues
          )

        # Check for moduledoc
        check_moduledoc_presence(body, file_path, issues)

      _ ->
        issues
    end
  end

  @dialyzer {:nowarn_function, check_documentation: 4}
  @compile {:no_warn_conditional, true}
  @spec check_documentation(any(), String.t(), String.t(), any()) :: any()
  defp check_documentation(issues, file_path, _content, ast) do
    # Walk AST to find public functions without docs
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        {:def, meta, [{name, _, args}, _body]} = node, acc when is_list(args) ->
          line = Keyword.get(meta, :line, 0)

          # Check if previous node was @doc
          # Note: has_preceding_doc? always returns false (placeholder implementation)
          handle_missing_doc_check(ast, line, node, acc, file_path, name, args)

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  @spec check_naming_conventions(any(), String.t(), any()) :: any()
  defp check_naming_conventions(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check function names
        {:def, meta, [{name, _, _}, _]} = node, acc ->
          line = Keyword.get(meta, :line, 0)
          name_str = to_string(name)

          case validate_function_name(name_str) do
            {:error, :double_underscores} ->
              {node,
               [
                 create_issue(
                   :naming_convention,
                   line,
                   file_path,
                   "Function name #{name} contains double underscores",
                   :warning
                 )
                 | acc
               ]}

            {:error, :uppercase} ->
              {node,
               [
                 create_issue(
                   :naming_convention,
                   line,
                   file_path,
                   "Function name #{name} contains uppercase letters",
                   :error
                 )
                 | acc
               ]}

            :ok ->
              {node, acc}
          end

        # Check variable names
        {name, meta, nil} = node, acc when is_atom(name) ->
          line = Keyword.get(meta, :line, 0)
          name_str = to_string(name)

          handle_single_letter_variable(
            name_str,
            name,
            line,
            file_path,
            node,
            acc
          )

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  @spec check_error_handling(any(), String.t(), any()) :: any()
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
          handle_error_atom_check(value, meta, file_path, node, acc)

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  @dialyzer {:nowarn_function, check_genserver_patterns: 3}
  @compile {:no_warn_conditional, true}
  @spec check_genserver_patterns(any(), String.t(), any()) :: any()
  defp check_genserver_patterns(issues, file_path, ast) do
    {_, new_issues} =
      Macro.prewalk(ast, issues, fn
        # Check for proper callback implementation
        {:def, meta, [{:handle_call, _, [_, _, _]}, _]} = node, acc ->
          line = Keyword.get(meta, :line, 0)

          # Check if @impl true precedes it
          # Note: has_impl_attribute? always returns false (placeholder implementation)
          handle_impl_attribute_check(ast, line, file_path, node, acc)

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  @spec check_formatting(any(), String.t(), any()) :: any()
  defp check_formatting(issues, file_path, lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce(issues, fn {line, line_num}, acc ->
      case check_line_formatting(line) do
        {:error, :line_too_long} ->
          [
            create_issue(
              :formatting,
              line_num,
              file_path,
              "Line exceeds 120 characters",
              :info
            )
            | acc
          ]

        {:error, :trailing_whitespace} ->
          [
            create_issue(
              :formatting,
              line_num,
              file_path,
              "Line has trailing whitespace",
              :warning
            )
            | acc
          ]

        {:error, :contains_tabs} ->
          [
            create_issue(
              :formatting,
              line_num,
              file_path,
              "Line contains tabs (use spaces)",
              :error
            )
            | acc
          ]

        :ok ->
          acc
      end
    end)
  end

  @spec check_imports_and_aliases(any(), String.t(), any()) :: any()
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
              handle_only_option_check(node, line, file_path, acc)

            _ ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    new_issues
  end

  # Helper functions

  @spec check_module_name_match(any(), any(), String.t(), any()) :: any()
  defp check_module_name_match(expected, actual, file_path, issues)
       when expected != actual do
    [
      create_issue(
        :module_name_mismatch,
        1,
        file_path,
        "Module name #{actual} doesn't match file path",
        :error
      )
      | issues
    ]
  end

  @spec check_module_name_match(any(), any(), any(), any()) :: any()
  defp check_module_name_match(_, _, _, issues), do: issues

  @spec check_moduledoc_presence(any(), String.t(), any()) :: any()
  defp check_moduledoc_presence(body, file_path, issues) do
    case has_moduledoc?(body) do
      true ->
        issues

      false ->
        [
          create_issue(
            :missing_moduledoc,
            1,
            file_path,
            "Module is missing @moduledoc",
            :warning
          )
          | issues
        ]
    end
  end

  @spec handle_missing_doc_check(
          any(),
          any(),
          any(),
          any(),
          String.t(),
          String.t() | atom(),
          list()
        ) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_missing_doc_check(ast, line, node, acc, file_path, name, args) do
    # has_preceding_doc?/2 currently always returns false (simplified implementation)
    false = has_preceding_doc?(ast, line)

    {node,
     [
       create_issue(
         :missing_doc,
         line,
         file_path,
         "Public function #{name}/#{length(args)} is missing @doc",
         :warning
       )
       | acc
     ]}
  end

  @spec handle_single_letter_variable(
          String.t() | atom(),
          String.t() | atom(),
          any(),
          String.t(),
          any(),
          any()
        ) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_single_letter_variable(name_str, name, line, file_path, node, acc) do
    case should_flag_single_letter_variable?(name_str) do
      true ->
        {node,
         [
           create_issue(
             :naming_convention,
             line,
             file_path,
             "Single letter variable #{name} should be avoided",
             :info
           )
           | acc
         ]}

      false ->
        {node, acc}
    end
  end

  @spec should_flag_single_letter_variable?(String.t() | atom()) :: boolean()
  defp should_flag_single_letter_variable?(name_str) do
    String.length(name_str) == 1 and name_str not in ["_", "x", "y", "z"]
  end

  @spec handle_error_atom_check(any(), any(), String.t(), any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_error_atom_check(nil, _meta, _file_path, node, acc),
    do: {node, acc}

  @spec handle_error_atom_check(any(), any(), String.t(), any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_error_atom_check(_value, meta, file_path, node, acc) do
    line = Keyword.get(meta, :line, 0)

    {node,
     [
       create_issue(
         :error_handling,
         line,
         file_path,
         "Use tagged tuples {:ok, value} or {:error, reason} instead of bare atoms",
         :warning
       )
       | acc
     ]}
  end

  @spec handle_impl_attribute_check(any(), any(), String.t(), any(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_impl_attribute_check(_ast, line, file_path, node, acc) do
    # has_impl_attribute?/2 always returns false, so we only handle the false case
    {node,
     [
       create_issue(
         :genserver_pattern,
         line,
         file_path,
         "GenServer callback missing @impl true",
         :warning
       )
       | acc
     ]}
  end

  @spec handle_only_option_check(any(), any(), String.t(), any()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_only_option_check(node, line, file_path, acc) do
    case has_only_option?(node) do
      true ->
        {node, acc}

      false ->
        {node,
         [
           create_issue(
             :import_style,
             line,
             file_path,
             "Import without :only option may import too many functions",
             :info
           )
           | acc
         ]}
    end
  end

  @spec add_moduledoc_recommendation(any(), any()) :: any()
  defp add_moduledoc_recommendation(summary, recommendations) do
    case Map.get(summary, :missing_moduledoc, 0) do
      count when count > 0 ->
        ["Add @moduledoc documentation to all modules" | recommendations]

      _ ->
        recommendations
    end
  end

  @spec add_doc_recommendation(any(), any()) :: any()
  defp add_doc_recommendation(summary, recommendations) do
    case Map.get(summary, :missing_doc, 0) do
      count when count > 0 ->
        ["Add @doc documentation to all public functions" | recommendations]

      _ ->
        recommendations
    end
  end

  @spec add_error_handling_recommendation(any(), any()) :: any()
  defp add_error_handling_recommendation(summary, recommendations) do
    case Map.get(summary, :error_handling, 0) do
      count when count > 0 ->
        [
          "Use consistent {:ok, result} | {:error, reason} patterns"
          | recommendations
        ]

      _ ->
        recommendations
    end
  end

  @spec add_formatting_recommendation(any(), any()) :: any()
  defp add_formatting_recommendation(summary, recommendations) do
    case Map.get(summary, :formatting, 0) do
      count when count > 0 ->
        ["Run mix format to fix formatting issues" | recommendations]

      _ ->
        recommendations
    end
  end

  @spec format_final_recommendations(any()) :: String.t()
  defp format_final_recommendations([]) do
    "No specific recommendations. Code follows standards well!"
  end

  @spec format_final_recommendations(any()) :: String.t()
  defp format_final_recommendations(recommendations) do
    recommendations
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {rec, idx} -> "#{idx}. #{rec}" end)
  end

  @spec find_elixir_files(String.t()) :: any()
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

  @spec path_to_module_name(String.t()) :: any()
  defp path_to_module_name(file_path) do
    file_path
    |> Path.rootname()
    |> Path.split()
    |> Enum.drop_while(&(&1 != "lib"))
    |> Enum.drop(1)
    |> Enum.map_join(".", &Macro.camelize/1)
  end

  @spec has_moduledoc?(any()) :: boolean()
  defp has_moduledoc?({:__block__, _, nodes}) do
    Enum.any?(nodes, fn
      {:@, _, [{:moduledoc, _, _}]} -> true
      _ -> false
    end)
  end

  @spec has_moduledoc?(any()) :: boolean()
  defp has_moduledoc?(_), do: false

  @spec has_preceding_doc?(any(), any()) :: boolean()
  defp has_preceding_doc?(_ast, _line) do
    # Simplified implementation - in a real implementation,
    # we would walk the AST to check if there's a @doc attribute
    # before the function definition at the given line
    false
  end

  @spec has_only_option?(any()) :: boolean()
  defp has_only_option?({:import, _, [_module, opts]}) when is_list(opts) do
    Keyword.has_key?(opts, :only)
  end

  @spec has_only_option?(any()) :: boolean()
  defp has_only_option?(_), do: false

  @spec summarize_issues(any()) :: any()
  defp summarize_issues(issues) do
    issues
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Map.new()
  end

  @spec format_summary(any()) :: String.t()
  defp format_summary(summary) do
    summary
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.map_join("\n", fn {type, count} ->
      "- #{format_type(type)}: #{count}"
    end)
  end

  @spec format_issues(any()) :: String.t()
  defp format_issues(issues) do
    issues
    |> Enum.group_by(& &1.file)
    |> Enum.map_join("\n\n", fn {file, file_issues} ->
      """
      ### #{file}
      #{format_file_issues(file_issues)}
      """
    end)
  end

  @spec format_file_issues(any()) :: String.t()
  defp format_file_issues(issues) do
    issues
    |> Enum.sort_by(& &1.line)
    |> Enum.map_join(
      "\n",
      fn issue ->
        "- Line #{issue.line} [#{issue.severity}]: #{issue.message}"
      end
    )
  end

  @spec format_type(any()) :: String.t()
  defp format_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @spec generate_recommendations(any()) :: any()
  defp generate_recommendations(summary) do
    recommendations = []

    recommendations = add_moduledoc_recommendation(summary, recommendations)

    recommendations = add_doc_recommendation(summary, recommendations)

    recommendations =
      add_error_handling_recommendation(summary, recommendations)

    recommendations = add_formatting_recommendation(summary, recommendations)

    format_final_recommendations(recommendations)
  end

  @spec validate_function_name(String.t() | atom()) ::
          {:ok, any()} | {:error, any()}
  defp validate_function_name(name_str)
       when name_str in ["__MODULE__", "__DIR__", "__ENV__"],
       do: :ok

  @spec validate_function_name(String.t() | atom()) ::
          {:ok, any()} | {:error, any()}
  defp validate_function_name(name_str) do
    case {String.contains?(name_str, "__"), String.match?(name_str, ~r/[A-Z]/)} do
      {true, _} -> {:error, :double_underscores}
      {false, true} -> {:error, :uppercase}
      {false, false} -> :ok
    end
  end

  @spec check_line_formatting(any()) :: any()
  defp check_line_formatting(line) do
    Enum.find_value(
      [
        {String.length(line) > 120, {:error, :line_too_long}},
        {String.match?(line, ~r/\s+$/), {:error, :trailing_whitespace}},
        {String.contains?(line, "\t"), {:error, :contains_tabs}}
      ],
      :ok,
      fn {condition, result} ->
        case condition do
          true -> result
          false -> nil
        end
      end
    )
  end
end
