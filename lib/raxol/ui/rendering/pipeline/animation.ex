defmodule Raxol.UI.Rendering.Pipeline.Animation do
  @moduledoc """
  Animation frame management for the rendering pipeline.
  Handles animation frame requests, timing, and callbacks.
  """

  require Logger

  # Animation frame timing (16ms = ~60fps, 25ms for tests)
  @animation_tick_interval_ms if Mix.env() == :test, do: 25, else: 16

  @type state :: map()
  @type animation_request :: {pid(), reference()}

  @doc """
  Ensures the animation ticker is running.
  Starts a timer if not already active.
  """
  @spec ensure_animation_ticker_running(state()) :: state()
  def ensure_animation_ticker_running(state) do
    start_animation_ticker(is_nil(state.animation_ticker_ref), state)
  end

  defp start_animation_ticker(false, state) do
    # Already running
    state
  end

  defp start_animation_ticker(_should_start, state) do
    Logger.debug("Pipeline: Animation ticker not running, starting it.")

    # Use the actual timer reference returned by Process.send_after
    timer_ref =
      Process.send_after(
        self(),
        {:animation_tick, :timer_ref},
        @animation_tick_interval_ms
      )

    %{state | animation_ticker_ref: timer_ref}
  end

  @doc """
  Stops the animation ticker if no more requests are pending.
  """
  @spec maybe_stop_animation_ticker(state()) :: state()
  def maybe_stop_animation_ticker(state) do
    should_stop =
      :queue.is_empty(state.animation_frame_requests) and
        not is_nil(state.animation_ticker_ref)

    stop_animation_ticker(should_stop, state)
  end

  defp stop_animation_ticker(false, state) do
    state
  end

  defp stop_animation_ticker(_should_stop, state) do
    Logger.debug("Pipeline: No more animation requests, stopping ticker.")

    # Cancel the timer
    Process.cancel_timer(state.animation_ticker_ref)

    %{state | animation_ticker_ref: nil}
  end

  @doc """
  Processes pending animation frame requests.
  Notifies all waiting processes that a frame is ready.
  """
  @spec process_animation_requests(state()) :: state()
  def process_animation_requests(state) do
    # Process all pending animation frame requests
    {requests_to_notify, remaining_requests} =
      :queue.split(
        :queue.len(state.animation_frame_requests),
        state.animation_frame_requests
      )

    # Convert queue to list for processing
    requests_list = :queue.to_list(requests_to_notify)

    # Notify all requesters
    Enum.each(requests_list, fn {pid, ref} ->
      send(pid, {:animation_frame, ref})
    end)

    Logger.debug(
      "Pipeline: Notified #{length(requests_list)} animation frame requesters."
    )

    %{state | animation_frame_requests: remaining_requests}
  end

  @doc """
  Handles animation tick - processes requests and schedules next tick if needed.
  """
  @spec handle_animation_tick(state()) :: state()
  def handle_animation_tick(state) do
    # Process animation requests
    state_after_requests = process_animation_requests(state)

    # Clear the current ticker reference
    state_cleared = %{state_after_requests | animation_ticker_ref: nil}

    # Restart ticker if there are more requests
    restart_ticker_if_needed(
      :queue.is_empty(state_cleared.animation_frame_requests),
      state_cleared
    )
  end

  defp restart_ticker_if_needed(true, state_cleared) do
    state_cleared
  end

  defp restart_ticker_if_needed(_queue_empty, state_cleared) do
    ensure_animation_ticker_running(state_cleared)
  end

  @doc """
  Schedules the next animation tick.
  """
  @spec schedule_next_tick() :: reference()
  def schedule_next_tick do
    Process.send_after(
      self(),
      {:animation_tick, :timer_ref},
      @animation_tick_interval_ms
    )
  end

  @doc """
  Gets the animation tick interval in milliseconds.
  """
  @spec tick_interval() :: non_neg_integer()
  def tick_interval(), do: @animation_tick_interval_ms
end
