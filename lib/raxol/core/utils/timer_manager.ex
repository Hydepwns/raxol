defmodule Raxol.Core.Utils.TimerManager do
  @moduledoc """
  Centralized timer management utilities for consistent timer handling across the codebase.

  This module provides a unified interface for working with timers, including:
  - Periodic timers (intervals)
  - One-time delayed timers
  - Timer cancellation
  - Timer reference tracking

  All timer intervals are in milliseconds.
  """

  @type timer_ref :: reference() | {atom(), reference()} | nil
  @type timer_type :: :interval | :once
  @type timer_msg :: atom() | tuple()

  @doc """
  Starts a periodic timer that sends a message at regular intervals.

  ## Examples

      # Send :cleanup message every hour
      {:ok, ref} = TimerManager.start_interval(:cleanup, 3_600_000)

      # Send {:check_status, :database} every 5 seconds
      {:ok, ref} = TimerManager.start_interval({:check_status, :database}, 5000)
  """
  @spec start_interval(timer_msg(), non_neg_integer()) :: {:ok, reference()}
  def start_interval(message, interval_ms)
      when is_integer(interval_ms) and interval_ms > 0 do
    case :timer.send_interval(interval_ms, message) do
      {:ok, ref} -> {:ok, ref}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Starts a one-time delayed timer that sends a message after a delay.

  ## Examples

      # Send :timeout message after 30 seconds
      ref = TimerManager.send_after(:timeout, 30_000)

      # Send {:retry, attempt_num} after 1 second
      ref = TimerManager.send_after({:retry, 1}, 1000)
  """
  @spec send_after(timer_msg(), non_neg_integer()) :: reference()
  def send_after(message, delay_ms)
      when is_integer(delay_ms) and delay_ms >= 0 do
    Process.send_after(self(), message, delay_ms)
  end

  @doc """
  Cancels a timer and returns whether it was successfully cancelled.

  ## Examples

      {:ok, cancelled} = TimerManager.cancel_timer(timer_ref)
  """
  @spec cancel_timer(timer_ref()) :: {:ok, boolean() | :ok}
  def cancel_timer(nil), do: {:ok, false}

  def cancel_timer({:ok, ref}) when is_reference(ref) do
    case :timer.cancel(ref) do
      {:ok, _} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  def cancel_timer(ref) when is_reference(ref) do
    case Process.cancel_timer(ref) do
      false -> {:ok, false}
      _ -> {:ok, true}
    end
  end

  @doc """
  Safely cancels a timer if it exists, ignoring errors.

  ## Examples

      TimerManager.safe_cancel(timer_ref)
  """
  @spec safe_cancel(timer_ref()) :: :ok
  def safe_cancel(nil), do: :ok

  def safe_cancel({:ok, ref}) when is_reference(ref) do
    _ = :timer.cancel(ref)
    :ok
  end

  def safe_cancel(ref) when is_reference(ref) do
    _ = Process.cancel_timer(ref)
    :ok
  end

  def safe_cancel(_), do: :ok

  @doc """
  Manages multiple timers in a map, useful for GenServer state.

  ## Examples

      # Start a new timer in the timers map
      timers = TimerManager.add_timer(state.timers, :heartbeat, :interval, 5000)

      # Cancel and remove a timer
      timers = TimerManager.remove_timer(state.timers, :heartbeat)
  """
  @spec add_timer(map(), atom(), timer_type(), non_neg_integer()) :: map()
  def add_timer(timers, name, :interval, interval_ms) do
    # Cancel existing timer if present
    timers = remove_timer(timers, name)

    case start_interval(name, interval_ms) do
      {:ok, ref} -> Map.put(timers, name, ref)
      _ -> timers
    end
  end

  def add_timer(timers, name, :once, delay_ms) do
    # Cancel existing timer if present
    timers = remove_timer(timers, name)

    ref = send_after(name, delay_ms)
    Map.put(timers, name, ref)
  end

  @spec remove_timer(map(), atom()) :: map()
  def remove_timer(timers, name) do
    case Map.get(timers, name) do
      nil ->
        timers

      ref ->
        safe_cancel(ref)
        Map.delete(timers, name)
    end
  end

  @doc """
  Cancels all timers in a map, useful for GenServer terminate.

  ## Examples

      TimerManager.cancel_all_timers(state.timers)
  """
  @spec cancel_all_timers(map()) :: :ok
  def cancel_all_timers(timers) when is_map(timers) do
    Enum.each(timers, fn {_name, ref} -> safe_cancel(ref) end)
    :ok
  end

  @doc """
  Common timer intervals as constants for consistency.
  """
  def intervals do
    %{
      immediate: 0,
      millisecond: 1,
      second: 1_000,
      minute: 60_000,
      five_minutes: 300_000,
      ten_minutes: 600_000,
      half_hour: 1_800_000,
      hour: 3_600_000,
      day: 86_400_000,
      week: 604_800_000
    }
  end

  @doc """
  Calculates next timer interval for exponential backoff.

  ## Examples

      # First retry after 1 second, then 2, 4, 8, up to max 30 seconds
      delay = TimerManager.exponential_backoff(attempt, 1000, 30_000)
  """
  @spec exponential_backoff(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  def exponential_backoff(attempt, base_ms, max_ms) do
    delay = (base_ms * :math.pow(2, attempt)) |> round()
    min(delay, max_ms)
  end

  @doc """
  Adds jitter to a timer interval to prevent thundering herd.

  ## Examples

      # Add +/- 10% jitter to 5 second interval
      interval = TimerManager.add_jitter(5000, 0.1)
  """
  @spec add_jitter(non_neg_integer(), float()) :: non_neg_integer()
  def add_jitter(interval_ms, jitter_factor \\ 0.1)
      when jitter_factor >= 0 and jitter_factor <= 1 do
    jitter = interval_ms * jitter_factor * (2 * :rand.uniform() - 1)
    max(1, round(interval_ms + jitter))
  end
end
