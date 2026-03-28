defmodule Raxol.Terminal.TelemetryLogger do
  alias Raxol.Core.Runtime.Log

  @moduledoc """
  Logs all Raxol.Terminal telemetry events for observability and debugging.

  Call `Raxol.Terminal.TelemetryLogger.attach_all/0` in your application start to enable logging.

  ## Trace Context

  When trace context is available in event metadata, the logger includes
  trace_id and span_id for request correlation:

      [TELEMETRY] [trace:abc12345 span:def67890] [:raxol, :terminal, :resized]: %{...}

  Use `Raxol.Core.Telemetry.TraceContext` to start traces for request correlation.
  """

  @events [
    [:raxol, :terminal, :focus_changed],
    [:raxol, :terminal, :resized],
    [:raxol, :terminal, :mode_changed],
    [:raxol, :terminal, :clipboard_event],
    [:raxol, :terminal, :selection_changed],
    [:raxol, :terminal, :paste_event],
    [:raxol, :terminal, :cursor_event],
    [:raxol, :terminal, :scroll_event]
  ]

  @doc """
  Attaches the logger to all Raxol.Terminal telemetry events.
  """
  def attach_all do
    _ =
      for event <- @events do
        handler_id = "raxol-terminal-logger-" <> Enum.join(event, "-")

        _ =
          :telemetry.attach(handler_id, event, &__MODULE__.handle_event/4, nil)
      end

    :ok
  end

  @doc false
  def handle_event(event_name, measurements, metadata, _config) do
    trace_prefix = format_trace_context(metadata)
    clean_metadata = Map.drop(metadata, [:trace_id, :span_id, :parent_span_id])

    Log.info(
      "[TELEMETRY] #{trace_prefix}#{inspect(event_name)}: #{inspect(measurements)} | #{inspect(clean_metadata)}"
    )
  end

  @spec format_trace_context(map()) :: String.t()
  defp format_trace_context(%{trace_id: trace_id, span_id: span_id})
       when is_binary(trace_id) do
    trace_short = String.slice(trace_id, 0..7)
    span_short = if span_id, do: String.slice(span_id, 0..7), else: "none"
    "[trace:#{trace_short} span:#{span_short}] "
  end

  defp format_trace_context(_metadata), do: ""
end
