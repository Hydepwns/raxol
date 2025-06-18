defmodule Raxol.TestAnalyzer do
  @moduledoc '''
  Analyzes test results and categorizes failures and skipped tests.
  '''

  def analyze_test_output(output) do
    failures = extract_failures(output)
    skipped = extract_skipped(output)
    invalid = extract_invalid(output)

    %{
      failures: failures,
      skipped: skipped,
      invalid: invalid,
      total_failures: length(failures),
      total_skipped: length(skipped),
      total_invalid: length(invalid)
    }
  end

  defp extract_failures(output) do
    output
    |> String.split("\n")
    |> Enum.filter(fn line ->
      case line do
        "test " <> rest -> String.contains?(rest, "failed")
        _ -> false
      end
    end)
  end

  defp extract_skipped(output) do
    output
    |> String.split("\n")
    |> Enum.filter(fn line ->
      case line do
        "test " <> rest -> String.contains?(rest, "skipped")
        _ -> false
      end
    end)
  end

  defp extract_invalid(output) do
    output
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      case line do
        "test " <> rest ->
          if String.contains?(rest, "invalid") do
            [line | acc]
          else
            acc
          end

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  def categorize_failures(failures) do
    failures
    |> Enum.group_by(fn failure ->
      cond do
        String.contains?(failure, "timeout") -> :timeout
        String.contains?(failure, "assertion") -> :assertion
        String.contains?(failure, "exception") -> :exception
        true -> :other
      end
    end)
  end
end
