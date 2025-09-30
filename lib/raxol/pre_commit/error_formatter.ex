defmodule Raxol.PreCommit.ErrorFormatter do
  @moduledoc """
  Formats error messages from pre-commit checks with helpful context
  and fix suggestions.
  """

  @doc """
  Format an error with context and fix suggestions.
  """
  def format_error(check_name, error_details, config \\ %{})

  # Format check errors
  def format_error(:format, %{files: files}, _config) when is_list(files) do
    file_count = length(files)

    %{
      message: "#{file_count} file(s) need formatting",
      details: format_file_list(files),
      fix_command: "mix format",
      fix_description: "Run the formatter to fix these files",
      auto_fixable: true,
      documentation: "https://hexdocs.pm/mix/Mix.Tasks.Format.html"
    }
  end

  def format_error(:compile, %{warnings: warnings}, _config)
      when is_list(warnings) do
    %{
      message: "Compilation produced #{length(warnings)} warning(s)",
      details: format_warnings(warnings),
      fix_command: nil,
      fix_description: "Review and fix the warnings listed above",
      auto_fixable: false,
      documentation: "https://hexdocs.pm/elixir/warnings.html"
    }
  end

  def format_error(:compile, %{errors: errors}, _config) when is_list(errors) do
    %{
      message: "Compilation failed with #{length(errors)} error(s)",
      details: format_compile_errors(errors),
      fix_command: nil,
      fix_description: "Fix the compilation errors listed above",
      auto_fixable: false,
      documentation: "https://hexdocs.pm/elixir/debugging.html"
    }
  end

  def format_error(:credo, %{issues: issues}, _config) when is_list(issues) do
    by_priority = group_credo_issues(issues)

    %{
      message: "Credo found #{length(issues)} issue(s)",
      details: format_credo_issues(by_priority),
      fix_command: "mix credo suggest --strict",
      fix_description: "Review Credo suggestions for code improvements",
      auto_fixable: false,
      documentation: "https://hexdocs.pm/credo/overview.html"
    }
  end

  def format_error(:tests, %{failures: failures}, _config)
      when is_list(failures) do
    %{
      message: "#{length(failures)} test(s) failed",
      details: format_test_failures(failures),
      fix_command: "mix test --failed",
      fix_description: "Run only the failing tests to debug",
      auto_fixable: false,
      documentation: "https://hexdocs.pm/ex_unit/ExUnit.html"
    }
  end

  def format_error(:docs, %{broken_links: links}, _config)
      when is_list(links) do
    %{
      message: "#{length(links)} broken documentation link(s)",
      details: format_broken_links(links),
      fix_command: "mix docs",
      fix_description: "Generate docs and verify all links",
      auto_fixable: false,
      documentation: "https://hexdocs.pm/ex_doc/readme.html"
    }
  end

  # Generic error fallback
  def format_error(check_name, error_details, _config) do
    %{
      message: "Check '#{check_name}' failed",
      details: inspect(error_details, pretty: true),
      fix_command: nil,
      fix_description: "Review the error details above",
      auto_fixable: false,
      documentation: nil
    }
  end

  @doc """
  Print formatted error to the console with colors and structure.
  """
  def print_error(check_name, error_info, opts \\ []) do
    verbose = Keyword.get(opts, :verbose, false)
    color = Keyword.get(opts, :color, true)

    formatted = format_error(check_name, error_info)

    # Print header
    Log.info("")

    Log.info(
      color_text(
        "═══ #{String.upcase(to_string(check_name))} CHECK FAILED ═══",
        :red,
        color
      )
    )

    Log.info("")

    # Print main message
    Log.info(color_text("  [FAIL] #{formatted.message}", :red, color))
    Log.info("")

    # Print details if verbose
    case verbose do
      true when formatted.details != nil ->
        Log.info(color_text("  Details:", :yellow, color))
        Log.info(formatted.details)
        Log.info("")

      _ ->
        :ok
    end

    # Print fix suggestion
    case formatted.fix_command do
      nil ->
        Log.info(
          color_text("  [TIP] #{formatted.fix_description}", :cyan, color)
        )

      cmd ->
        Log.info(color_text("  [TIP] To fix:", :cyan, color))
        Log.info(color_text("     $ #{cmd}", :green, color))
        Log.info("")
        Log.info(color_text("  #{formatted.fix_description}", :white, color))
    end

    # Print auto-fix hint
    case formatted.auto_fixable do
      true ->
        Log.info("")

        Log.info(
          color_text(
            "  [FIX] This can be auto-fixed with: mix raxol.pre_commit --fix",
            :blue,
            color
          )
        )

      false ->
        :ok
    end

    # Print documentation link
    case formatted.documentation do
      nil ->
        :ok

      url ->
        Log.info("")
        Log.info(color_text("  [DOCS] Learn more: #{url}", :white, color))
    end

    Log.info("")
    Log.info(color_text("═" |> String.duplicate(50), :red, color))
  end

  @doc """
  Generate a summary of all errors across checks.
  """
  def print_summary(results, opts \\ []) do
    failed_checks =
      results
      |> Enum.filter(fn {_, result} -> result.status == :error end)
      |> Enum.map(fn {name, result} -> {name, result} end)

    case failed_checks do
      [] ->
        :ok

      checks ->
        color = Keyword.get(opts, :color, true)

        Log.info("")
        Log.info(color_text("FAILED CHECKS SUMMARY", :red, color))
        Log.info(color_text("─" |> String.duplicate(50), :red, color))

        Enum.each(checks, fn {name, result} ->
          reason = Map.get(result, :reason, "Unknown error")
          Log.info("  • #{String.capitalize(to_string(name))}: #{reason}")
        end)

        Log.info("")
        Log.info(color_text("Quick fixes:", :yellow, color))

        # Group by fix type
        auto_fixable =
          Enum.filter(checks, fn {name, _} ->
            name in [:format]
          end)

        case auto_fixable do
          [] ->
            Log.info("  • Review each error above and apply manual fixes")

          _ ->
            Log.info("  • Run: mix raxol.pre_commit --fix")
            Log.info("  • Then review any remaining issues")
        end

        Log.info("")
    end
  end

  # Private formatting helpers

  defp format_file_list(files) do
    files
    |> Enum.take(10)
    |> Enum.map_join("\n", fn file -> "    • #{file}" end)
    |> then(fn list ->
      case length(files) > 10 do
        true -> list <> "\n    ... and #{length(files) - 10} more"
        false -> list
      end
    end)
  end

  defp format_warnings(warnings) do
    warnings
    |> Enum.take(5)
    |> Enum.map_join("\n", fn warning ->
      case warning do
        %{file: file, line: line, message: msg} ->
          "    #{file}:#{line} - #{msg}"

        text when is_binary(text) ->
          "    #{text}"

        _ ->
          "    #{inspect(warning)}"
      end
    end)
  end

  defp format_compile_errors(errors) do
    errors
    |> Enum.take(5)
    |> Enum.map_join("\n\n", fn error ->
      case error do
        %{file: file, line: line, description: desc} ->
          "    #{file}:#{line}\n      #{desc}"

        text when is_binary(text) ->
          "    #{text}"

        _ ->
          "    #{inspect(error)}"
      end
    end)
  end

  defp group_credo_issues(issues) do
    Enum.group_by(issues, fn issue ->
      case issue do
        %{priority: priority} -> priority
        _ -> :normal
      end
    end)
  end

  defp format_credo_issues(grouped_issues) do
    [:high, :normal, :low]
    |> Enum.map_join(fn priority ->
      case Map.get(grouped_issues, priority, []) do
        [] ->
          nil

        issues ->
          header =
            "  #{String.capitalize(to_string(priority))} priority (#{length(issues)}):"

          items =
            issues
            |> Enum.take(3)
            |> Enum.map_join("\n", fn issue ->
              case issue do
                %{file: file, line: line, message: msg} ->
                  "    • #{file}:#{line} - #{msg}"

                _ ->
                  "    • #{inspect(issue)}"
              end
            end)

          "#{header}\n#{items}"
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp format_test_failures(failures) do
    failures
    |> Enum.take(5)
    |> Enum.map_join("\n", fn failure ->
      case failure do
        %{test: test, module: module, error: error} ->
          """
            Test: #{module}.#{test}
            Error: #{inspect(error, pretty: true)}
          """

        %{file: file, line: line} ->
          "    Failed at #{file}:#{line}"

        text when is_binary(text) ->
          "    #{text}"

        _ ->
          "    #{inspect(failure)}"
      end
    end)
  end

  defp format_broken_links(links) do
    links
    |> Enum.take(10)
    |> Enum.map_join("\n", fn link ->
      case link do
        %{file: file, link: url} ->
          "    • #{file}: #{url}"

        text when is_binary(text) ->
          "    • #{text}"

        _ ->
          "    • #{inspect(link)}"
      end
    end)
  end

  defp color_text(text, _color, false), do: text

  defp color_text(text, color, true) do
    color_code =
      case color do
        :red -> "\e[31m"
        :green -> "\e[32m"
        :yellow -> "\e[33m"
        :blue -> "\e[34m"
        :magenta -> "\e[35m"
        :cyan -> "\e[36m"
        :white -> "\e[37m"
      end

    "#{color_code}#{text}\e[0m"
  end
end
