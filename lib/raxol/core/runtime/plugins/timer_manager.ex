defmodule Raxol.Core.Runtime.Plugins.TimerManager do
  @moduledoc """
  Manages timers and scheduling for plugin operations.
  """

  require Raxol.Core.Runtime.Log

  @debounce_timeout 1000 # 1 second

  def schedule_reload(plugin_id, path, state) do
    # Cancel any existing timer
    state = cancel_existing_timer(state)

    # Schedule new reload
    timer_ref = Process.send_after(
      self(),
      {:reload_plugin_file_debounced, plugin_id, path},
      @debounce_timeout
    )

    {:ok, %{state | file_event_timer: timer_ref}}
  end

  def cancel_existing_timer(state) do
    if state.file_event_timer do
      Process.cancel_timer(state.file_event_timer)
    end

    %{state | file_event_timer: nil}
  end

  def schedule_periodic_tick(state, interval \\ 5000) do
    if state.tick_timer do
      Process.cancel_timer(state.tick_timer)
    end

    timer_ref = Process.send_after(self(), :tick, interval)
    %{state | tick_timer: timer_ref}
  end

  def cancel_periodic_tick(state) do
    if state.tick_timer do
      Process.cancel_timer(state.tick_timer)
    end

    %{state | tick_timer: nil}
  end
end
