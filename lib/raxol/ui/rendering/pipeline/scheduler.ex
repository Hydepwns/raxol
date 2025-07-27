defmodule Raxol.UI.Rendering.Pipeline.Scheduler do
  @moduledoc """
  Render scheduling and debouncing for the pipeline.
  Manages when renders are executed to optimize performance.
  """

  require Logger
  alias Raxol.UI.Rendering.Pipeline.Stages

  @type state :: map()
  @type diff_result :: term()
  @type tree :: map() | nil

  # Render debounce delay in milliseconds
  @render_debounce_ms if Mix.env() == :test, do: 5, else: 10

  @doc """
  Schedules or immediately executes a render based on current state.
  Implements debouncing to batch rapid updates.
  """
  @spec schedule_or_execute_render(diff_result(), tree(), state()) :: state()
  def schedule_or_execute_render(_diff_result, _tree, state) do
    cond do
      # If a render is already scheduled, let it handle this update
      state.render_scheduled_for_next_frame ->
        Logger.debug(
          "Pipeline: Render already scheduled for next frame, skipping additional scheduling."
        )

        state

      # If we have a render timer pending, cancel and reschedule
      not is_nil(state.render_timer_ref) ->
        Logger.debug(
          "Pipeline: Cancelling existing render timer and rescheduling."
        )

        Process.cancel_timer(state.render_timer_ref)
        schedule_render(state)

      # No render scheduled, schedule one
      true ->
        schedule_render(state)
    end
  end

  @doc """
  Schedules a render after the debounce delay.
  """
  @spec schedule_render(state()) :: state()
  def schedule_render(state) do
    timer_ref = Process.send_after(self(), :execute_render, @render_debounce_ms)
    %{state | render_timer_ref: timer_ref}
  end

  @doc """
  Executes the actual render pipeline.
  """
  @spec execute_render(state()) :: state()
  def execute_render(state) do
    if state.current_tree do
      Logger.debug("Pipeline: Executing render with current tree.")

      start_time = System.monotonic_time(:microsecond)

      # Execute the rendering pipeline stages
      {painted_output, composed_tree} =
        Stages.execute_render_stages(
          {:replace, state.current_tree},
          state.current_tree,
          state.renderer_module,
          state.previous_composed_tree,
          state.previous_painted_output
        )

      # Commit the painted output to the renderer
      if painted_output do
        commit_to_renderer(painted_output, state.renderer_module)
      end

      end_time = System.monotonic_time(:microsecond)
      render_time_ms = (end_time - start_time) / 1000

      Logger.debug("Pipeline: Render completed in #{render_time_ms}ms")

      %{
        state
        | render_timer_ref: nil,
          render_scheduled_for_next_frame: false,
          last_render_time: render_time_ms,
          previous_composed_tree: composed_tree,
          previous_painted_output: painted_output
      }
    else
      Logger.debug(
        "Pipeline: Execute render called but no current tree available."
      )

      %{
        state
        | render_timer_ref: nil,
          render_scheduled_for_next_frame: false
      }
    end
  end

  @doc """
  Marks that a render should occur on the next animation frame.
  """
  @spec mark_render_for_next_frame(state()) :: state()
  def mark_render_for_next_frame(state) do
    %{state | render_scheduled_for_next_frame: true}
  end

  @doc """
  Commits the painted output to the renderer.
  """
  @spec commit_to_renderer(term(), module()) :: :ok
  defp commit_to_renderer(painted_output, renderer_module) do
    renderer = renderer_module || Raxol.UI.Rendering.Renderer

    try do
      renderer.render(painted_output)

      Logger.debug(
        "Pipeline: Committed output to renderer #{inspect(renderer)}"
      )
    rescue
      error ->
        Logger.error(
          "Pipeline: Failed to commit to renderer: #{inspect(error)}"
        )
    end

    :ok
  end

  @doc """
  Gets the render debounce delay in milliseconds.
  """
  @spec debounce_delay() :: non_neg_integer()
  def debounce_delay(), do: @render_debounce_ms
end
