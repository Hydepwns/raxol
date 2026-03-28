defmodule Raxol.Benchmark.Formatter do
  @moduledoc """
  Formats benchmark results as console tables, JSON, or Markdown.
  """

  @doc """
  Formats results as a console table string.

  Expects a map of `%{suite_name => %Benchee.Suite{}}` or raw timing maps.
  """
  @spec console(map()) :: String.t()
  def console(results) when is_map(results) do
    results
    |> Enum.map_join("\n", fn {suite, data} ->
      header = "\n=== #{String.upcase(to_string(suite))} ===\n"
      body = format_suite_console(data)
      header <> body
    end)
  end

  @doc """
  Formats results as a JSON string with metadata.
  """
  @spec json(map(), keyword()) :: String.t()
  def json(results, opts \\ []) do
    data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      raxol_version: Application.spec(:raxol, :vsn) |> to_string(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version(),
      suites: serialize_results(results)
    }

    data =
      if opts[:include_system] do
        Map.put(data, :system, %{
          cpus: System.schedulers_online(),
          memory_mb: div(:erlang.memory(:total), 1_048_576)
        })
      else
        data
      end

    Jason.encode!(data, pretty: true)
  end

  @doc """
  Formats results as a Markdown table.
  """
  @spec markdown(map()) :: String.t()
  def markdown(results) when is_map(results) do
    header = """
    # Raxol Benchmark Results

    **Date**: #{Date.utc_today()}
    **Elixir**: #{System.version()}
    **OTP**: #{:erlang.system_info(:otp_release)}

    """

    body =
      results
      |> Enum.map_join("\n", fn {suite, data} ->
        "## #{format_suite_name(suite)}\n\n#{format_suite_markdown(data)}\n"
      end)

    header <> body
  end

  @doc "Writes formatted output to a file."
  @spec write(String.t(), Path.t()) :: :ok | {:error, term()}
  def write(content, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write(path, content)
  end

  # -- Console formatting --

  defp format_suite_console(%{scenarios: scenarios}) when is_list(scenarios) do
    scenarios
    |> Enum.map_join("\n", fn scenario ->
      name = scenario.name
      avg = format_time(scenario.run_time_data.statistics.average)
      min = format_time(Enum.min(scenario.run_time_data.samples))
      max = format_time(Enum.max(scenario.run_time_data.samples))
      ips = Float.round(scenario.run_time_data.statistics.ips, 1)

      "  #{String.pad_trailing(name, 30)} avg=#{avg}  min=#{min}  max=#{max}  (#{ips} ips)"
    end)
  end

  defp format_suite_console(data) when is_map(data) do
    data
    |> Enum.map_join("\n", fn {name, timing} ->
      "  #{String.pad_trailing(to_string(name), 30)} #{inspect(timing)}"
    end)
  end

  defp format_suite_console(_), do: "  (no data)"

  # -- Markdown formatting --

  defp format_suite_markdown(%{scenarios: scenarios}) when is_list(scenarios) do
    header = "| Benchmark | Average | Min | Max | IPS |"
    separator = "|---|---|---|---|---|"

    rows =
      Enum.map(scenarios, fn s ->
        avg = format_time(s.run_time_data.statistics.average)
        min = format_time(Enum.min(s.run_time_data.samples))
        max = format_time(Enum.max(s.run_time_data.samples))
        ips = Float.round(s.run_time_data.statistics.ips, 1)
        "| #{s.name} | #{avg} | #{min} | #{max} | #{ips} |"
      end)

    Enum.join([header, separator | rows], "\n")
  end

  defp format_suite_markdown(data) when is_map(data) do
    header = "| Benchmark | Value |"
    separator = "|---|---|"

    rows =
      Enum.map(data, fn {name, val} ->
        "| #{name} | #{inspect(val)} |"
      end)

    Enum.join([header, separator | rows], "\n")
  end

  defp format_suite_markdown(_), do: "(no data)"

  # -- JSON serialization --

  defp serialize_results(results) do
    Map.new(results, fn {suite, data} ->
      {suite, serialize_suite(data)}
    end)
  end

  defp serialize_suite(%{scenarios: scenarios}) when is_list(scenarios) do
    Enum.map(scenarios, fn s ->
      %{
        name: s.name,
        average_ns: s.run_time_data.statistics.average,
        ips: s.run_time_data.statistics.ips,
        sample_count: length(s.run_time_data.samples)
      }
    end)
  end

  defp serialize_suite(data) when is_map(data), do: data
  defp serialize_suite(_), do: nil

  # -- Helpers --

  defp format_time(ns) when is_number(ns) do
    cond do
      ns >= 1_000_000_000 -> "#{Float.round(ns / 1_000_000_000, 2)}s"
      ns >= 1_000_000 -> "#{Float.round(ns / 1_000_000, 2)}ms"
      ns >= 1_000 -> "#{Float.round(ns / 1_000, 2)}us"
      true -> "#{Float.round(ns * 1.0, 1)}ns"
    end
  end

  defp format_time(_), do: "?"

  defp format_suite_name(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
