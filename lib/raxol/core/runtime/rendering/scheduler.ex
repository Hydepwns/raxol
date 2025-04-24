defmodule Raxol.Core.Runtime.Rendering.Scheduler do
  @moduledoc """
  Manages the timing and scheduling of render frames in Raxol applications.

  This module is responsible for:
  * Coordinating when frames are rendered
  * Managing the frame rate
  * Throttling renders to maintain performance
  """

  require Logger

  @doc """
  Schedules the next frame render.

  ## Parameters
  - `state`: The current application state
  - `force_immediate`: If true, render immediately instead of waiting for the next frame

  ## Returns
  `{:ok, timer_ref}` if scheduling succeeded,
  `{:error, reason}` otherwise.
  """
  def schedule_frame(state, force_immediate \\ false) do
    if force_immediate do
      # Send a message immediately
      send(self(), :render)
      {:ok, nil}
    else
      # Calculate delay based on target FPS
      delay = calculate_frame_delay(state.fps)

      # Schedule the next frame
      timer_ref = Process.send_after(self(), :render, delay)

      {:ok, timer_ref}
    end
  end

  @doc """
  Calculates the delay between frames based on the target FPS.

  ## Parameters
  - `fps`: Target frames per second

  ## Returns
  Delay in milliseconds between frames.
  """
  def calculate_frame_delay(fps) do
    max_fps = min(fps, 120)  # Cap at 120 FPS for sanity

    # Calculate milliseconds per frame (mpf)
    mpf = trunc(1000 / max_fps)

    # Ensure at least 1ms delay
    max(mpf, 1)
  end

  @doc """
  Handles a render tick event.

  This is called when a scheduled render should occur.

  ## Parameters
  - `state`: The current application state

  ## Returns
  `{:ok, updated_state}` if the render was processed,
  `{:error, reason, state}` otherwise.
  """
  def handle_render_tick(state) do
    # Get current time for performance tracking
    start_time = :os.system_time(:millisecond)

    # Render the frame
    case Raxol.Core.Runtime.Rendering.Engine.render_frame(state) do
      {:ok, updated_state} ->
        # Calculate render duration for debugging
        end_time = :os.system_time(:millisecond)
        render_duration = end_time - start_time

        # Log performance if in debug mode
        if updated_state.debug_mode do
          Logger.debug("Frame rendered in #{render_duration}ms (target: #{trunc(1000 / updated_state.fps)}ms)")
        end

        # Schedule the next frame
        {:ok, timer_ref} = schedule_frame(updated_state)

        # Return updated state with the timer reference
        {:ok, %{updated_state | render_timer_ref: timer_ref}}

      {:error, reason, updated_state} ->
        Logger.error("Error rendering frame: #{inspect(reason)}")

        # Still schedule the next frame to keep the app responsive
        {:ok, timer_ref} = schedule_frame(updated_state)

        # Return updated state with error information
        {:error, reason, %{updated_state | render_timer_ref: timer_ref}}
    end
  end

  @doc """
  Cancels any scheduled renders.

  ## Parameters
  - `state`: The current application state

  ## Returns
  `{:ok, updated_state}` with any timer references cleared.
  """
  def cancel_scheduled_renders(state) do
    if state.render_timer_ref do
      Process.cancel_timer(state.render_timer_ref)
    end

    {:ok, %{state | render_timer_ref: nil}}
  end

  @doc """
  Adjusts the frame rate dynamically based on system performance.

  ## Parameters
  - `state`: The current application state
  - `render_times`: List of recent render durations in milliseconds

  ## Returns
  `{:ok, updated_state}` with potentially adjusted FPS.
  """
  def adjust_frame_rate(state, render_times) when is_list(render_times) and length(render_times) > 0 do
    # Calculate average render time
    avg_render_time = Enum.sum(render_times) / length(render_times)

    # Target frame time (in ms)
    target_frame_time = 1000 / state.fps

    # If we're consistently taking too long to render frames,
    # reduce the target FPS to avoid overloading the system
    new_fps =
      cond do
        avg_render_time > target_frame_time * 1.5 and state.fps > 10 ->
          # Reduce FPS by 10%
          max(trunc(state.fps * 0.9), 10)

        avg_render_time < target_frame_time * 0.5 and state.fps < state.target_fps ->
          # Increase FPS by 10% up to original target
          min(trunc(state.fps * 1.1), state.target_fps)

        true ->
          # Keep current FPS
          state.fps
      end

    if new_fps != state.fps do
      Logger.info("Adjusting frame rate to #{new_fps} FPS (was #{state.fps})")
    end

    {:ok, %{state | fps: new_fps}}
  end

  # If no render times provided, just return the state unchanged
  def adjust_frame_rate(state, _render_times), do: {:ok, state}
end
