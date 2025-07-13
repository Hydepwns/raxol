defmodule RaxolWeb.Metrics do
  @moduledoc """
  Provides metrics collection and monitoring for RaxolWeb.
  """

  @doc """
  Tracks terminal events for performance monitoring.
  """
  def track_terminal_event(event_type, duration, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol_web, :terminal, event_type],
      %{duration: duration},
      Map.merge(metadata, %{timestamp: System.system_time()})
    )
  end

  @doc """
  Tracks channel events for monitoring.
  """
  def track_channel_event(event_type, duration, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol_web, :channel, event_type],
      %{duration: duration},
      Map.merge(metadata, %{timestamp: System.system_time()})
    )
  end

  @doc """
  Tracks LiveView events for monitoring.
  """
  def track_liveview_event(event_type, duration, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol_web, :liveview, event_type],
      %{duration: duration},
      Map.merge(metadata, %{timestamp: System.system_time()})
    )
  end

  @doc """
  Records error metrics.
  """
  def track_error(error_type, error_details, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol_web, :error, error_type],
      %{count: 1},
      Map.merge(metadata, %{
        error_details: error_details,
        timestamp: System.system_time()
      })
    )
  end
end
