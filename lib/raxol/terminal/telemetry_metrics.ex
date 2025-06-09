defmodule Raxol.Terminal.TelemetryMetrics do
  @moduledoc """
  Example integration of Telemetry.Metrics and TelemetryMetricsStatsd for Raxol terminal events.

  Add this module to your supervision tree to automatically report terminal metrics to StatsD (or Datadog).

  ## Usage

      def start(_type, _args) do
        children = [
          {TelemetryMetricsStatsd, metrics: Raxol.Terminal.TelemetryMetrics.metrics(), formatter: :datadog}
          # ...other children
        ]
        Supervisor.start_link(children, strategy: :one_for_one)
      end

  ## Richer Metrics Example

  - `summary/2` for scroll delta (average scroll amount)
  - `counter/2` for mode changes, tagged by mode

  """
  import Telemetry.Metrics

  @doc """
  Returns a list of Telemetry metrics for Raxol terminal events.
  """
  def metrics do
    [
      counter("raxol.terminal.focus_changed"),
      counter("raxol.terminal.resized"),
      counter("raxol.terminal.mode_changed",
        tags: [:mode],
        tag_values: &__MODULE__.mode_tag/1
      ),
      counter("raxol.terminal.clipboard_event"),
      counter("raxol.terminal.selection_changed"),
      counter("raxol.terminal.paste_event"),
      counter("raxol.terminal.cursor_event"),
      summary("raxol.terminal.scroll_event.delta",
        measurement: :delta,
        unit: :event,
        tags: [:direction],
        tag_values: &__MODULE__.scroll_tags/1
      )
    ]
  end

  # Extract mode from measurements or metadata for tagging
  def mode_tag(%{mode: mode}), do: %{mode: mode}
  def mode_tag(_), do: %{}

  # Extract direction from measurements or metadata for tagging scroll events
  def scroll_tags(%{direction: dir}), do: %{direction: dir}
  def scroll_tags(_), do: %{}
end
