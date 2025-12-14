defmodule Raxol.CLI.ErrorDisplay do
  @moduledoc """
  Enhanced error display for CLI output with intelligent suggestions.

  Integrates the ErrorExperience system with terminal output to provide
  actionable fix suggestions when errors occur in mix tasks.

  ## Usage

      # In a mix task
      case run_operation() do
        {:ok, result} -> result
        {:error, error} ->
          Raxol.CLI.ErrorDisplay.display_error(error)
          Mix.raise("Operation failed")
      end

      # With context
      Raxol.CLI.ErrorDisplay.display_error(error, %{
        operation: "compilation",
        file: "lib/foo.ex"
      })
  """

  alias Raxol.CLI.Colors
  alias Raxol.Core.ErrorExperience

  @doc """
  Displays an enhanced error with suggestions.

  Takes the raw error and optional context, runs it through ErrorExperience
  for classification and suggestions, then displays formatted output.
  """
  @spec display_error(term(), map()) :: :ok
  def display_error(error, context \\ %{}) do
    enhanced = ErrorExperience.classify_and_enhance(error, context)

    display_error_header(enhanced)
    display_error_details(error)
    display_suggestions(enhanced.suggestions)
    display_recovery_hints(enhanced)

    :ok
  end

  @doc """
  Displays a simple error without full enhancement.

  Use this for simple errors that don't need full ErrorExperience processing.
  """
  @spec display_simple_error(String.t(), String.t() | nil) :: :ok
  def display_simple_error(message, details \\ nil) do
    Mix.shell().info("")
    Mix.shell().error("  " <> Colors.format_error(message))

    if details do
      Mix.shell().info("    " <> Colors.muted(details))
    end

    Mix.shell().info("")
    :ok
  end

  @doc """
  Wraps an operation and displays enhanced errors if it fails.

  ## Examples

      ErrorDisplay.with_error_handling("Compiling project", fn ->
        Mix.Task.run("compile", ["--warnings-as-errors"])
      end)
  """
  @spec with_error_handling(String.t(), (-> result), map()) ::
          {:ok, result} | {:error, term()}
        when result: term()
  def with_error_handling(operation_name, fun, context \\ %{}) do
    fun.()
    {:ok, :completed}
  rescue
    e ->
      display_error(e, Map.put(context, :operation, operation_name))
      {:error, e}
  catch
    kind, reason ->
      display_error(
        {kind, reason},
        Map.put(context, :operation, operation_name)
      )

      {:error, {kind, reason}}
  end

  # Private display functions

  defp display_error_header(enhanced) do
    Mix.shell().info("")
    Mix.shell().info(Colors.divider("=", 60))

    severity_color =
      case enhanced.severity do
        :critical -> &Colors.error/1
        :error -> &Colors.error/1
        :warning -> &Colors.warning/1
        _ -> &Colors.info/1
      end

    header = severity_color.("Error: #{format_category(enhanced.category)}")
    Mix.shell().info("  " <> header)

    if enhanced.performance_impact != :none do
      impact_str = format_performance_impact(enhanced.performance_impact)

      Mix.shell().info(
        "  " <> Colors.muted("Performance impact: #{impact_str}")
      )
    end

    Mix.shell().info(Colors.divider("-", 60))
  end

  defp display_error_details(error) do
    message = format_error_message(error)
    Mix.shell().info("")
    Mix.shell().info("  " <> message)
    Mix.shell().info("")
  end

  defp display_suggestions([]) do
    :ok
  end

  defp display_suggestions(suggestions) do
    top_suggestions = Enum.take(suggestions, 3)

    Mix.shell().info("  " <> Colors.info("Suggested fixes:"))
    Mix.shell().info("")

    Enum.each(top_suggestions, fn suggestion ->
      confidence_pct = trunc(suggestion.confidence * 100)
      confidence_str = Colors.muted("(#{confidence_pct}% confidence)")

      type_indicator =
        case suggestion.type do
          :automatic -> Colors.success("[auto]")
          :guided -> Colors.info("[guided]")
          :manual -> Colors.warning("[manual]")
          :documentation -> Colors.muted("[docs]")
        end

      Mix.shell().info(
        "  #{type_indicator} #{suggestion.description} #{confidence_str}"
      )

      if suggestion.action do
        Mix.shell().info("       " <> Colors.format_command(suggestion.action))
      end

      Mix.shell().info("")
    end)

    if length(suggestions) > 3 do
      remaining = length(suggestions) - 3

      Mix.shell().info(
        "  " <> Colors.muted("... and #{remaining} more suggestions")
      )

      Mix.shell().info("")
    end
  end

  defp display_recovery_hints(enhanced) do
    if enhanced.related_optimizations != [] do
      Mix.shell().info("  " <> Colors.muted("Related optimizations:"))

      Enum.each(enhanced.related_optimizations, fn opt ->
        Mix.shell().info("    - #{opt}")
      end)

      Mix.shell().info("")
    end

    # Show quick commands
    Mix.shell().info("  " <> Colors.muted("Quick commands:"))

    Mix.shell().info(
      "    " <>
        Colors.format_command("mix raxol.check --quick") <>
        " - Run quick checks"
    )

    Mix.shell().info(
      "    " <>
        Colors.format_command("mix raxol.perf analyze") <>
        " - Analyze performance"
    )

    Mix.shell().info("")
    Mix.shell().info(Colors.divider("=", 60))
    Mix.shell().info("")
  end

  defp format_category(category) do
    category
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_performance_impact(:none), do: "None"
  defp format_performance_impact(:low), do: "Low"
  defp format_performance_impact(:medium), do: "Medium"
  defp format_performance_impact(:high), do: "High"
  defp format_performance_impact(:critical), do: "Critical"

  defp format_error_message(error) when is_exception(error) do
    Exception.message(error)
  end

  defp format_error_message({:error, reason}) when is_binary(reason) do
    reason
  end

  defp format_error_message({:error, reason}) do
    inspect(reason)
  end

  defp format_error_message(error) when is_binary(error) do
    error
  end

  defp format_error_message(error) do
    inspect(error)
  end
end
