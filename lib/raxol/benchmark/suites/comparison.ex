defmodule Raxol.Benchmark.Suites.Comparison do
  @moduledoc """
  Static competitor reference numbers for context.

  These are published estimates from each framework's documentation and
  community benchmarks. Raxol's numbers are measured live.
  """

  @competitors [
    %{
      name: "Ratatui",
      language: "Rust",
      render_fps: "~45,000",
      startup_ms: "~5",
      memory_per_widget: "~1KB",
      source: "Rust benchmarks (Dec 2024)"
    },
    %{
      name: "Bubble Tea",
      language: "Go",
      render_fps: "~30,000",
      startup_ms: "~10",
      memory_per_widget: "~5KB",
      source: "Go benchmarks (Dec 2024)"
    },
    %{
      name: "Textual",
      language: "Python",
      render_fps: "~3,000",
      startup_ms: "~200",
      memory_per_widget: "~50KB",
      source: "Python benchmarks (Dec 2024)"
    }
  ]

  @doc "Returns the list of competitor reference data."
  @spec competitors :: [
          %{
            name: String.t(),
            language: String.t(),
            render_fps: String.t(),
            startup_ms: String.t(),
            memory_per_widget: String.t(),
            source: String.t()
          }
        ]
  def competitors, do: @competitors

  @doc "Formats a comparison table as a list of lines."
  @spec comparison_table(map()) :: [String.t()]
  def comparison_table(raxol_stats \\ %{}) do
    header =
      format_row("Framework", "Language", "Render", "Startup", "Mem/Widget")

    separator = String.duplicate("-", 75)

    competitor_rows =
      Enum.map(@competitors, fn c ->
        format_row(
          c.name,
          c.language,
          c.render_fps,
          c.startup_ms,
          c.memory_per_widget
        )
      end)

    raxol_row =
      format_row(
        "Raxol",
        "Elixir",
        Map.get(raxol_stats, :render_fps, "measured"),
        Map.get(raxol_stats, :startup_ms, "measured"),
        Map.get(raxol_stats, :memory_per_widget, "measured")
      )

    # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
    [header, separator | competitor_rows] ++ [raxol_row]
  end

  defp format_row(name, lang, render, startup, memory) do
    String.pad_trailing(name, 12) <>
      String.pad_trailing(lang, 10) <>
      String.pad_trailing(to_string(render), 16) <>
      String.pad_trailing(to_string(startup), 12) <>
      to_string(memory)
  end
end
