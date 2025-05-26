defmodule Raxol.Terminal.TelemetryPrometheus do
  @moduledoc """
  Example integration of Telemetry.Metrics and TelemetryMetricsPrometheus for Raxol terminal events.

  Add this module to your supervision tree to automatically export terminal metrics for Prometheus scraping.

  ## Usage

      def start(_type, _args) do
        children = [
          {TelemetryMetricsPrometheus, metrics: Raxol.Terminal.TelemetryPrometheus.metrics()}
          # ...other children
        ]
        Supervisor.start_link(children, strategy: :one_for_one)
      end

  ## Exposing the Metrics Endpoint

  TelemetryMetricsPrometheus exposes metrics at `/metrics` by default using Plug. You can add it to your router:

      forward "/metrics", TelemetryMetricsPrometheus

  ## Advanced Metrics Example

  - `histogram/2` for scroll delta with custom buckets (e.g., [-20, -10, 0, 10, 20, 50, 100])
  - `summary/2` for paste event text length

  """
  import Telemetry.Metrics

  @doc """
  Returns a list of Telemetry metrics for Raxol terminal events, including advanced Prometheus metrics.
  """
  def metrics do
    [
      counter("raxol.terminal.focus_changed"),
      counter("raxol.terminal.resized"),
      counter("raxol.terminal.mode_changed", tags: [:mode], tag_values: &__MODULE__.mode_tag/1),
      counter("raxol.terminal.clipboard_event"),
      counter("raxol.terminal.selection_changed"),
      counter("raxol.terminal.paste_event"),
      counter("raxol.terminal.cursor_event"),
      histogram("raxol.terminal.scroll_event.delta", measurement: :delta, unit: :event, tags: [:direction], tag_values: &__MODULE__.scroll_tags/1, buckets: [-20, -10, 0, 10, 20, 50, 100]),
      summary("raxol.terminal.paste_event.length", measurement: :length, unit: :character)
    ]
  end

  def mode_tag(%{mode: mode}), do: %{mode: mode}
  def mode_tag(_), do: %{}

  def scroll_tags(%{direction: dir}), do: %{direction: dir}
  def scroll_tags(_), do: %{}
end
