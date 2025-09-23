defmodule Raxol.Terminal.TelemetryLogger do
  @moduledoc """
  Logs all Raxol.Terminal telemetry events for observability and debugging.

  Call `Raxol.Terminal.TelemetryLogger.attach_all/0` in your application start to enable logging.
  """
  require Logger

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
    _ = for event <- @events do
      handler_id = "raxol-terminal-logger-" <> Enum.join(event, "-")
      _ = :telemetry.attach(handler_id, event, &__MODULE__.handle_event/4, nil)
    end

    :ok
  end

  @doc false
  def handle_event(event_name, measurements, metadata, _config) do
    Logger.info(
      "[TELEMETRY] #{inspect(event_name)}: #{inspect(measurements)} | #{inspect(metadata)}"
    )
  end
end
