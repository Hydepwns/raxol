defmodule Raxol.Core.Runtime.Plugins.TimerManager do
  @moduledoc """
  Manages timers and scheduling for plugin operations.
  """

  require Raxol.Core.Runtime.Log
  require Logger

  # 1 second
  @debounce_timeout 1000

  def schedule_reload(plugin_id, path, state) do
    # Cancel any existing timer
    state = cancel_existing_timer(state)

    # Schedule new reload
    timer_id = System.unique_integer([:positive])

    Process.send_after(
      self(),
      {:reload_plugin_file_debounced, plugin_id, path},
      @debounce_timeout
    )

    {:ok, %{state | file_event_timer: timer_id}}
  end

  def cancel_existing_timer(state) do
    if Map.get(state, :file_event_timer) do
      Process.cancel_timer(Map.get(state, :file_event_timer))
    end

    Map.put(state, :file_event_timer, nil)
  end

  def schedule_periodic_tick(state, interval \\ 5000) do
    if Map.get(state, :tick_timer) do
      Process.cancel_timer(Map.get(state, :tick_timer))
    end

    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:tick, timer_id}, interval)
    %{state | tick_timer: timer_id}
  end

  def cancel_periodic_tick(state) when is_map(state) do
    require Logger

    Logger.debug(
      "[TimerManager] cancel_periodic_tick called with state type: #{inspect(typeof(state))}"
    )

    case Map.fetch(state, :tick_timer) do
      {:ok, tick_timer} when not is_nil(tick_timer) ->
        Process.cancel_timer(tick_timer)
        Map.put(state, :tick_timer, nil)

      {:ok, _} ->
        Map.put(state, :tick_timer, nil)

      :error ->
        Logger.warn(
          "[TimerManager] :tick_timer key missing in state: #{inspect(state)}"
        )

        Map.put(state, :tick_timer, nil)
    end
  end

  def cancel_periodic_tick(state) do
    require Logger

    Logger.warn(
      "[TimerManager] cancel_periodic_tick called with non-map state: #{inspect(state)}"
    )

    # Return a default state or the original state if it's not a map
    if is_map(state) do
      Map.put(state, :tick_timer, nil)
    else
      %{tick_timer: nil}
    end
  end

  defp typeof(value) when is_map(value), do: "map"
  defp typeof(value) when is_list(value), do: "list"
  defp typeof(value) when is_tuple(value), do: "tuple"
  defp typeof(value) when is_atom(value), do: "atom"
  defp typeof(value) when is_integer(value), do: "integer"
  defp typeof(value) when is_float(value), do: "float"
  defp typeof(value) when is_binary(value), do: "binary"
  defp typeof(value) when is_boolean(value), do: "boolean"
  defp typeof(value) when is_function(value), do: "function"
  defp typeof(value) when is_pid(value), do: "pid"
  defp typeof(value) when is_reference(value), do: "reference"
  defp typeof(value) when is_port(value), do: "port"
  defp typeof(_value), do: "unknown"
end
