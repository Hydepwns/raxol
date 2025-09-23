defmodule Raxol.Core.Runtime.Plugins.TimerManager do
  @moduledoc """
  Handles timer management for plugin operations including periodic ticks and file event timers.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Cancels an existing timer.
  """
  def cancel_existing_timer(state) do
    case state.file_event_timer do
      nil ->
        state

      timer_ref when is_reference(timer_ref) ->
        Raxol.Core.Runtime.Log.info(
          "[#{__MODULE__}] Cancelling existing file event timer",
          %{timer_ref: timer_ref}
        )

        _ = Process.cancel_timer(timer_ref)
        %{state | file_event_timer: nil}

      _ ->
        state
    end
  end

  @doc """
  Cancels a periodic tick timer.
  """
  def cancel_periodic_tick(state) do
    case state.tick_timer do
      nil ->
        {:ok, state}

      timer_ref when is_reference(timer_ref) ->
        Raxol.Core.Runtime.Log.info(
          "[#{__MODULE__}] Cancelling periodic tick timer",
          %{timer_ref: timer_ref}
        )

        _ = Process.cancel_timer(timer_ref)
        {:ok, %{state | tick_timer: nil}}

      _ ->
        {:ok, state}
    end
  end

  @doc """
  Starts a periodic tick timer.
  """
  def start_periodic_tick(state, interval \\ 5000) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Starting periodic tick timer",
      %{interval: interval}
    )

    timer_ref = Process.send_after(self(), :tick, interval)
    %{state | tick_timer: timer_ref}
  end

  @doc """
  Schedules a file event timer.
  """
  def schedule_file_event_timer(state, plugin_id, path, interval \\ 1000) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Scheduling file event timer",
      %{plugin_id: plugin_id, path: path, interval: interval}
    )

    # Cancel existing timer first
    new_state = cancel_existing_timer(state)

    # Schedule new timer
    timer_ref =
      Process.send_after(
        self(),
        {:reload_plugin_file_debounced, plugin_id, path},
        interval
      )

    %{new_state | file_event_timer: timer_ref}
  end
end
