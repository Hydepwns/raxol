defmodule Raxol.Core.Runtime.Events.DispatcherHooks do
  @moduledoc """
  Pure-function hooks extracted from Dispatcher for mouse hit testing,
  time-travel debugging, cycle profiling, and session recording.

  None of these functions depend on GenServer state -- they operate on
  explicit arguments and return values.
  """

  alias Raxol.Core.Events.Event

  # --- Mouse hit testing ---

  @doc """
  Walk positioned elements (last drawn = topmost) looking for a clickable
  element whose bounding box contains (x, y).

  Returns `{:click, handler}` or `:miss`.
  """
  @spec hit_test(integer(), integer(), list()) :: {:click, term()} | :miss
  def hit_test(_x, _y, []), do: :miss

  def hit_test(x, y, elements) when is_list(elements) do
    elements
    |> Enum.reverse()
    |> Enum.find_value(:miss, &clickable_at(&1, x, y))
  end

  def hit_test(_x, _y, _), do: :miss

  @doc """
  Checks whether a single positioned element is clickable at (x, y).

  Returns `{:click, handler}` when hit, `nil` when missed.
  """
  @spec clickable_at(map(), integer(), integer()) :: {:click, term()} | nil
  def clickable_at(
        %{x: ex, y: ey, width: ew, height: eh, attrs: %{on_click: handler}},
        x,
        y
      )
      when not is_nil(handler) and x >= ex and x < ex + ew and y >= ey and
             y < ey + eh do
    {:click, handler}
  end

  def clickable_at(_el, _x, _y), do: nil

  # --- Time-travel debugging hook ---

  @doc """
  Records a time-travel snapshot when the time-travel debugger PID is active.
  No-ops when disabled (nil or non-pid).
  """
  @spec maybe_record_time_travel(pid() | nil, term(), map(), map()) :: :ok
  def maybe_record_time_travel(nil, _message, _old, _new), do: :ok

  def maybe_record_time_travel(pid, message, old_model, new_model)
      when is_pid(pid) do
    if Process.alive?(pid) do
      Raxol.Debug.TimeTravel.record(pid, message, old_model, new_model)
    end

    :ok
  end

  def maybe_record_time_travel(_other, _message, _old, _new), do: :ok

  # --- Cycle profiler hooks ---

  @doc """
  Times the execution of `fun` when cycle profiling is enabled.
  Returns `{elapsed_us, mem_before, mem_after, result}`.
  When disabled (nil profiler), returns `{0, 0, 0, result}`.
  """
  @spec maybe_time_update(pid() | nil, (-> term())) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), term()}
  def maybe_time_update(nil, fun), do: {0, 0, 0, fun.()}

  def maybe_time_update(_pid, fun) do
    {:memory, mem_before} = Process.info(self(), :memory)
    start = System.monotonic_time(:microsecond)
    result = fun.()
    elapsed = System.monotonic_time(:microsecond) - start
    {:memory, mem_after} = Process.info(self(), :memory)
    {elapsed, mem_before, mem_after, result}
  end

  @doc """
  Records a cycle profiler update when the profiler PID is active.
  No-ops when disabled (nil or non-pid).
  """
  @spec maybe_record_cycle_update(
          pid() | nil,
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          term()
        ) :: :ok
  def maybe_record_cycle_update(nil, _us, _mem_b, _mem_a, _msg), do: :ok

  def maybe_record_cycle_update(pid, update_us, mem_before, mem_after, message)
      when is_pid(pid) do
    if Process.alive?(pid) do
      Raxol.Performance.CycleProfiler.record_update(pid, %{
        update_us: update_us,
        message_summary: inspect(message, limit: 3, printable_limit: 40),
        memory_before: mem_before,
        memory_after: mem_after
      })
    end

    :ok
  end

  def maybe_record_cycle_update(_other, _us, _mem_b, _mem_a, _msg), do: :ok

  # --- Session recording hook ---

  @doc """
  Records key input events to the session recorder when it is running.
  Only records `:key` type events; all others are ignored.
  """
  @spec maybe_record_input(Event.t() | term()) :: :ok
  def maybe_record_input(%Event{type: :key, data: data}) do
    if pid = Process.whereis(Raxol.Recording.Recorder) do
      input_str = key_event_to_string(data)
      Raxol.Recording.Recorder.record_input(pid, input_str)
    end

    :ok
  end

  def maybe_record_input(_event), do: :ok

  @doc """
  Converts a key event data map to a printable string for session recording.
  """
  @spec key_event_to_string(map()) :: String.t()
  def key_event_to_string(%{key: key})
      when is_integer(key) and key in 32..126 do
    <<key>>
  end

  def key_event_to_string(%{key: key}) when is_atom(key) do
    to_string(key)
  end

  def key_event_to_string(%{key: key}) when is_integer(key) do
    inspect(key)
  end

  def key_event_to_string(_), do: ""
end
