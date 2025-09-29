defmodule Raxol.UI.Rendering.Pipeline do
  @moduledoc """
  Manages the rendering pipeline for the UI as a GenServer.

  ## Pipeline Stages (Planned)

  1. **Diffing**: Compare the new UI tree to the previous one and compute minimal changes.
     DELEGATED TO: `Raxol.UI.Rendering.TreeDiffer`
  2. **Layout**: Calculate positions and sizes for all UI elements.
  3. **Composition**: Build a render tree or command list from the layout.
  4. **Paint**: Convert the render tree into draw commands or buffer updates.
  5. **Commit**: Send the final output to the Renderer process for display.

  ## Data Flow

  - UI state changes or events call `update_tree/1` (or `update_tree/2`) to submit a new UI tree.
  - The pipeline stores the latest tree, may batch or debounce rapid updates, and triggers a render via the Renderer process.
  - The GenServer holds pipeline state (current tree, previous tree, pending updates, etc.).

  ## Extension Points

  - Custom diffing or batching strategies
  - Animation frame scheduling
  - Hooks for custom renderers or output backends

  - Implement diffing and minimal update computation (DELEGATED: `TreeDiffer` handles core diffing. Layout stage has partial diff-awareness. Compose and Paint stages now reuse previous results if their respective inputs are unchanged, providing a level of minimal update.)
  - Add batching/debouncing of rapid updates (partially implemented with send_after for debouncing)
  - Integrate animation frame scheduling (request_animation_frame now uses GenServer.call with deferred reply from :animation_tick; this is more robust.)
  - Store and manage pipeline state (previous tree, pending updates, etc.) (GenServer state has current_tree, previous_tree)
  - Connect to the real rendering backend (commit stage calls a renderer module)
  """

  use Raxol.Core.Behaviours.BaseManager


  alias Raxol.UI.Rendering.Renderer
  alias Raxol.UI.Rendering.TreeDiffer
  alias Raxol.UI.Rendering.UnifiedTimerManager

  # New pipeline modules
  alias Raxol.UI.Rendering.Pipeline.{State, Stages}

  # Animation tick interval in milliseconds
  @animation_tick_interval_ms (case Mix.env() do
                                 :test -> 25
                                 _ -> 16
                               end)

  require Raxol.Core.Runtime.Log
  require Logger

  @default_renderer Raxol.UI.Rendering.Renderer

  # Public API


  @doc """
  Child spec for supervision trees.
  """
  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Renders a buffer directly without updating the tree.
  This is a convenience function for benchmarking.
  """
  @spec render(buffer :: term()) :: {:ok, term()}
  def render(buffer) do
    # For benchmarking purposes, just return the buffer as-is
    # In a real implementation, this would go through the pipeline stages
    {:ok, buffer}
  end

  @doc """
  Updates the UI tree in the pipeline and triggers a render.
  """
  @spec update_tree(tree :: map()) :: :ok
  def update_tree(tree) do
    GenServer.cast(__MODULE__, {:update_tree, tree})
  end

  @doc """
  Triggers a render with the current UI tree (or provided data).
  """
  @spec trigger_render(data :: any()) :: :ok
  def trigger_render(data \\ nil) do
    GenServer.cast(__MODULE__, {:trigger_render, data})
  end

  @doc """
  Applies animation settings (delegates to Renderer).
  """
  @spec apply_animation_settings(
          atom() | nil,
          String.t() | nil,
          pos_integer(),
          boolean(),
          float(),
          float(),
          float(),
          :fit | :fill | :stretch
        ) :: :ok
  def apply_animation_settings(
        animation_type,
        animation_path,
        fps,
        loop,
        blend,
        opacity,
        blur,
        scale
      ) do
    settings = %{
      type: animation_type,
      path: animation_path,
      fps: fps,
      loop: loop,
      blend: blend,
      opacity: opacity,
      blur: blur,
      scale: scale
    }

    Renderer.set_animation_settings(settings)
    :ok
  end

  @doc """
  Computes the minimal set of changes (diff) between two UI trees.

  Returns:
    * :no_change if trees are identical
    * `{:replace, new_tree}` if the root node differs
    * `{:update, path, changes}` for subtree updates (path is a list of indices)

  """
  @spec diff_trees(old_tree :: map() | nil, new_tree :: map() | nil) ::
          :no_change
          | {:replace, map()}
          | {:update, [integer()], any()}
  def diff_trees(old_tree, new_tree),
    do: TreeDiffer.diff_trees(old_tree, new_tree)

  @doc """
  Requests notification on the next animation frame. The caller will receive {:animation_frame, ref}.
  Returns a unique reference for the request.
  """
  @spec request_animation_frame(pid()) ::
          {:animation_frame, reference()} | {:error, any()}
  def request_animation_frame(pid \\ self()) do
    ref = System.unique_integer([:positive])
    GenServer.call(__MODULE__, {:request_animation_frame, pid, ref})
  end

  @doc """
  Schedules a render to occur on the next animation frame.
  Only one render will be scheduled per frame, regardless of how many times this is called before the next frame.
  """
  @spec schedule_render_on_next_frame() :: :ok
  def schedule_render_on_next_frame do
    GenServer.cast(__MODULE__, :schedule_render_on_next_frame)
    :ok
  end

  # --- Pipeline Stages (Stubbed) ---

  @doc """
  Commits the final output to the Renderer process for display.
  This is where the pipeline would send the output (a list of paint operations)
  to the configured renderer.
  """
  @spec commit(
          painted_output :: list(map()),
          renderer :: module(),
          diff_result :: any(),
          new_tree :: any()
        ) :: :ok
  def commit(
        painted_output,
        renderer \\ @default_renderer,
        diff_result \\ nil,
        new_tree \\ nil
      ) do
    require Logger

    Logger.debug(
      "[Pipeline] commit called with painted_output=#{inspect(painted_output)}, diff_result=#{inspect(diff_result)}, new_tree=#{inspect(new_tree)}"
    )

    Raxol.Core.Runtime.Log.debug(
      "Commit Stage: Sending #{Enum.count(painted_output)} paint operations to renderer #{inspect(renderer)}."
    )

    renderer_pid = get_renderer_pid(renderer)
    send_to_renderer(renderer_pid, diff_result, new_tree)
    :ok
  end

  defp get_renderer_pid(renderer) do
    case renderer do
      module when is_atom(module) ->
        # Try to find the process by module name
        case Process.whereis(module) do
          nil ->
            # If not found by module name, try the default renderer name
            Process.whereis(Raxol.UI.Rendering.Renderer) || module

          pid ->
            pid
        end

      pid when is_pid(pid) ->
        pid

      other ->
        other
    end
  end

  defp send_to_renderer(renderer_pid, diff_result, new_tree) do
    case diff_result do
      {:update, _path, _changes} ->
        GenServer.cast(renderer_pid, {:apply_diff, diff_result, new_tree})

      {:replace, _} ->
        GenServer.cast(renderer_pid, {:render, new_tree})

      :no_change ->
        :ok

      _ ->
        GenServer.cast(renderer_pid, {:render, new_tree})
    end
  end

  # --- Extension Points ---

  @doc """
  Sets the renderer module to use for output (default: Raxol.UI.Rendering.Renderer).
  This allows for custom renderers or output backends.
  """
  @spec set_renderer(module()) :: :ok
  def set_renderer(renderer_module) do
    Application.put_env(:raxol, :renderer_module, renderer_module)
    :ok
  end

  @doc """
  Gets the current renderer module (default: Raxol.UI.Rendering.Renderer).
  """
  @spec get_renderer() :: module()
  def get_renderer do
    Application.get_env(:raxol, :renderer_module, @default_renderer)
  end

  # BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    initial_tree = Keyword.get(opts, :initial_tree, %{})
    opts_with_renderer = Keyword.put(opts, :renderer, get_renderer())

    state = State.new(opts_with_renderer)

    state_with_tree = maybe_update_initial_tree(state, initial_tree)

    # Start unified timer manager if not already running
    start_unified_timer_manager()

    {:ok, state_with_tree}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:update_tree, new_tree}, state) do
    case tree_changed?(state.current_tree, new_tree) do
      false ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: No change in tree, skipping render."
        )

        {:noreply, state}

      true ->
        # Delegate to TreeDiffer - use current_tree as the old tree for comparison
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Calling TreeDiffer with current_tree: #{inspect(state.current_tree)}, new_tree: #{inspect(new_tree)}"
        )

        diff_result = TreeDiffer.diff_trees(state.current_tree, new_tree)

        Raxol.Core.Runtime.Log.debug(
          "Pipeline: TreeDiffer returned: #{inspect(diff_result)}"
        )

        case diff_result do
          :no_change ->
            Raxol.Core.Runtime.Log.debug(
              "Pipeline: Diff result is :no_change, skipping render."
            )

            new_state_after_diff = %{
              state
              | previous_tree: state.current_tree,
                current_tree: new_tree
            }

            {:noreply, new_state_after_diff}

          _ ->
            Raxol.Core.Runtime.Log.debug(
              "Pipeline: Tree updated, scheduling render."
            )

            # Store the new tree now, so a scheduled render uses the latest
            updated_state = %{
              state
              | previous_tree: state.current_tree,
                current_tree: new_tree
            }

            final_state =
              schedule_or_execute_render(diff_result, new_tree, updated_state)

            {:noreply, final_state}
        end
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:trigger_render, data}, state) do
    tree_to_render = data || state.current_tree

    case tree_to_render do
      nil ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Triggering render, but no tree available."
        )

        {:noreply, state}

      tree_to_render ->
        Raxol.Core.Runtime.Log.debug("Pipeline: Triggering render for tree.")

        # If data is provided, use it as the new tree
        # If data is nil, use the current tree without changing it
        {diff_result, updated_state} =
          prepare_render_state(data, tree_to_render, state)

        final_state =
          schedule_or_execute_render(diff_result, tree_to_render, updated_state)

        {:noreply, final_state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:request_animation_frame, pid, ref}, state) do
    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Received request_animation_frame from #{inspect(pid)} with ref #{inspect(ref)}"
    )

    updated_requests = :queue.in({pid, ref}, state.animation_frame_requests)
    new_state = %{state | animation_frame_requests: updated_requests}
    final_state = ensure_animation_ticker_running(new_state)
    {:noreply, final_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast(:schedule_render_on_next_frame, state) do
    case state.current_tree do
      nil ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: schedule_render_on_next_frame called, but no current_tree to render."
        )

        {:noreply, state}

      _current_tree ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Scheduling render for next frame."
        )

        new_state = %{state | render_scheduled_for_next_frame: true}
        final_state = ensure_animation_ticker_running(new_state)
        {:noreply, final_state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:request_animation_frame, pid, ref}, from, state) do
    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Received request_animation_frame call from #{inspect(pid)}, ref #{inspect(ref)}, from #{inspect(from)}"
    )

    updated_requests =
      :queue.in({pid, ref, from}, state.animation_frame_requests)

    new_state = %{state | animation_frame_requests: updated_requests}
    final_state = ensure_animation_ticker_running(new_state)
    # Reply will be sent by :animation_tick
    {:noreply, final_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(
        {:deferred_render, diff_result, new_tree_for_reference, timer_id},
        state
      ) do
    case timer_matches?(state.render_timer_ref, timer_id) do
      true ->
        {painted_data, composed_data} =
          execute_render_stages(
            diff_result,
            new_tree_for_reference,
            state.renderer,
            state.previous_composed_tree,
            state.previous_painted_output
          )

        # Commit the painted output to the renderer
        commit(
          painted_data,
          state.renderer,
          diff_result,
          new_tree_for_reference
        )

        new_state = %{
          state
          | last_render_time: System.monotonic_time(:millisecond),
            render_timer_ref: nil,
            render_scheduled_for_next_frame: false,
            previous_composed_tree: composed_data,
            previous_painted_output: painted_data
        }

        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:render_debounce_tick}, state) do
    # Handle deferred render from unified timer manager
    case state.deferred_render_data do
      {diff_result, new_tree_for_reference, _unique_id} ->
        Raxol.Core.Runtime.Log.debug("Pipeline: Processing deferred render from unified timer")

        render_result =
          execute_render_stages(
            diff_result,
            new_tree_for_reference,
            state.renderer,
            state.previous_composed_tree,
            state.previous_painted_output
          )

        painted_data = render_result
        composed_data = render_result.content

        commit(painted_data, state.renderer, diff_result, new_tree_for_reference)

        new_state = %{
          state
          | last_render_time: System.monotonic_time(:millisecond),
            render_timer_ref: nil,
            render_scheduled_for_next_frame: false,
            previous_composed_tree: composed_data,
            previous_painted_output: painted_data,
            deferred_render_data: nil
        }

        {:noreply, new_state}

      nil ->
        Raxol.Core.Runtime.Log.debug("Pipeline: Received debounce tick but no deferred render data")
        {:noreply, state}
    end
  end

  # Handle direct animation tick (fallback when UnifiedTimerManager unavailable)
  def handle_manager_info(:animation_tick, state) do
    # Delegate to the main animation tick handler
    handle_manager_info({:animation_tick, :timer_ref}, state)
  end

  def handle_manager_info({:animation_tick, :timer_ref}, state) do
    case state.animation_ticker_ref do
      nil ->
        {:noreply, state}

      _ticker_ref ->
        # Process all queued animation frame requests
        responses = :queue.to_list(state.animation_frame_requests)
        remaining_requests_q = :queue.new()

        # Send replies for all pending animation frame requests
        for {pid, ref, from} <- responses do
          Raxol.Core.Runtime.Log.debug(
            "Pipeline: Sending :animation_frame to #{inspect(pid)}, ref #{inspect(ref)} via GenServer.reply to #{inspect(from)}"
          )

          GenServer.reply(from, {:animation_frame, ref})
        end

        current_state = %{
          state
          | animation_frame_requests: remaining_requests_q,
            animation_ticker_ref: nil
        }

        # Process render if scheduled for next frame
        final_state =
          case should_process_scheduled_render?(current_state) do
            true ->
              Raxol.Core.Runtime.Log.debug(
                "Pipeline: Animation tick triggering scheduled render."
              )

              # Pass the full state to schedule_or_execute_render so it can manage its own state updates (like last_render_time)
              # The diff should be against the previous tree state before this current_tree was set.
              # For simplicity in this tick, we'll treat it as a full replace of the current tree.
              # A more sophisticated approach might store the pending diff that led to scheduling.
              render_state =
                schedule_or_execute_render(
                  # Treat as full render for simplicity in tick
                  {:replace, current_state.current_tree},
                  current_state.current_tree,
                  # Reset flag before render call
                  %{current_state | render_scheduled_for_next_frame: false}
                )

              render_state

            _ ->
              current_state
          end

        # Always reschedule the ticker if there are pending requests or if a render was scheduled
        # This ensures the ticker continues running for future requests
        case should_continue_ticker?(final_state) do
          true ->
            # Try unified timer manager first, fallback to direct timer
            case UnifiedTimerManager.start_animation_timer(self(), @animation_tick_interval_ms) do
              :ok ->
                %{final_state | animation_ticker_ref: :unified_timer}
              {:error, :not_started} ->
                # Fallback to direct timer if UnifiedTimerManager not available
                timer_ref = Process.send_after(self(), :animation_tick, @animation_tick_interval_ms)
                %{final_state | animation_ticker_ref: timer_ref}
              error ->
                Raxol.Core.Runtime.Log.error("Failed to reschedule animation timer: #{inspect(error)}")
                %{final_state | animation_ticker_ref: nil}
            end

          _ ->
            Raxol.Core.Runtime.Log.debug(
              "Pipeline: Animation ticker stopping as no work was done or pending."
            )

            final_state
        end
        |> then(&{:noreply, &1})
    end
  end

  ## Private Helpers

  defp schedule_or_execute_render(diff_result, new_tree_for_reference, state) do
    require Logger

    Logger.debug(
      "[Pipeline] schedule_or_execute_render called with diff_result=#{inspect(diff_result)}, new_tree=#{inspect(new_tree_for_reference)}"
    )

    case diff_result do
      {:update, _path, _changes} ->
        handle_partial_update(state, diff_result, new_tree_for_reference)

      _ ->
        handle_full_render(state, diff_result, new_tree_for_reference)
    end
  end

  defp handle_partial_update(state, diff_result, new_tree_for_reference) do
    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Executing partial update immediately."
    )

    _ = cancel_timer_if_exists(state.render_timer_ref)

    render_result =
      execute_render_stages(
        diff_result,
        new_tree_for_reference,
        state.renderer,
        state.previous_composed_tree,
        state.previous_painted_output
      )

    painted_data = render_result
    composed_data = render_result.content

    # Commit the painted output to the renderer
    commit(
      painted_data,
      state.renderer,
      diff_result,
      new_tree_for_reference
    )

    %{
      state
      | last_render_time: System.monotonic_time(:millisecond),
        render_timer_ref: nil,
        render_scheduled_for_next_frame: false,
        previous_composed_tree: composed_data,
        previous_painted_output: painted_data
    }
  end

  defp handle_full_render(state, diff_result, new_tree_for_reference) do
    now = System.monotonic_time(:millisecond)

    time_since_last_render =
      calculate_time_since_last_render(state.last_render_time, now)

    choose_render_strategy(
      time_since_last_render,
      state,
      diff_result,
      new_tree_for_reference,
      now
    )
  end

  defp execute_immediate_render(state, diff_result, new_tree_for_reference, now) do
    Raxol.Core.Runtime.Log.debug("Pipeline: Executing render immediately.")

    _ = cancel_timer_if_exists(state.render_timer_ref)

    render_result =
      execute_render_stages(
        diff_result,
        new_tree_for_reference,
        state.renderer,
        state.previous_composed_tree,
        state.previous_painted_output
      )

    painted_data = render_result
    composed_data = render_result.content

    # Commit the painted output to the renderer
    commit(
      painted_data,
      state.renderer,
      diff_result,
      new_tree_for_reference
    )

    %{
      state
      | last_render_time: now,
        render_timer_ref: nil,
        render_scheduled_for_next_frame: false,
        previous_composed_tree: composed_data,
        previous_painted_output: painted_data
    }
  end

  defp schedule_deferred_render(
         state,
         diff_result,
         new_tree_for_reference,
         time_since_last_render
       ) do
    delay = @animation_tick_interval_ms - time_since_last_render

    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Debouncing render. Will render in #{delay}ms."
    )

    _ = cancel_timer_if_exists(state.render_timer_ref)

    # Use unified timer manager for debounce timer
    :ok = UnifiedTimerManager.start_debounce_timer(self(), delay)

    # Store deferred render data in state instead of timer message
    state_with_deferred = %{state |
      render_timer_ref: :unified_timer,
      deferred_render_data: {diff_result, new_tree_for_reference, System.unique_integer([:positive])}
    }

    state_with_deferred
  end

  defp calculate_time_since_last_render(last_render_time, now) do
    calculate_time_diff(last_render_time, now)
  end

  defp cancel_timer_if_exists(:unified_timer) do
    # Timer is managed by UnifiedTimerManager, stop debounce timer
    UnifiedTimerManager.stop_timer(:render_debounce)
  end

  defp cancel_timer_if_exists(timer_ref) do
    cancel_timer(timer_ref)
  end

  # Delegate stage execution to Stages module
  defdelegate execute_render_stages(
                diff_result,
                new_tree_for_reference,
                renderer_module,
                previous_composed_tree,
                previous_painted_output
              ),
              to: Stages

  defp ensure_animation_ticker_running(state) do
    case state.animation_ticker_ref do
      nil ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Animation ticker not running, starting it."
        )

        # Use unified timer manager instead of direct Process.send_after
        case UnifiedTimerManager.start_animation_timer(self(), @animation_tick_interval_ms) do
          :ok ->
            %{state | animation_ticker_ref: :unified_timer}
          {:error, :not_started} ->
            # Fallback to direct timer if UnifiedTimerManager not available
            timer_ref = Process.send_after(self(), :animation_tick, @animation_tick_interval_ms)
            %{state | animation_ticker_ref: timer_ref}
          error ->
            Raxol.Core.Runtime.Log.error("Failed to start animation timer: #{inspect(error)}")
            %{state | animation_ticker_ref: nil}
        end

      _ticker_ref ->
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Animation ticker already running."
        )

        state
    end
  end

  # Helper functions using pattern matching instead of if statements

  defp start_unified_timer_manager do
    # Start UnifiedTimerManager if not already running
    case GenServer.whereis(UnifiedTimerManager) do
      nil ->
        case UnifiedTimerManager.start_link([]) do
          {:ok, _pid} ->
            Raxol.Core.Runtime.Log.info("Pipeline: Started UnifiedTimerManager")

          {:error, {:already_started, _pid}} ->
            Raxol.Core.Runtime.Log.debug("Pipeline: UnifiedTimerManager already started")

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error("Pipeline: Failed to start UnifiedTimerManager: #{inspect(reason)}")
        end

      _pid ->
        Raxol.Core.Runtime.Log.debug("Pipeline: UnifiedTimerManager already running")
    end

    :ok
  end

  defp maybe_update_initial_tree(state, %{}), do: state

  defp maybe_update_initial_tree(state, initial_tree),
    do: State.update_tree(state, initial_tree)

  defp tree_changed?(current_tree, new_tree), do: current_tree != new_tree

  defp timer_matches?(timer_ref, timer_id), do: timer_ref == timer_id

  defp should_process_scheduled_render?(%{
         render_scheduled_for_next_frame: true,
         current_tree: tree
       })
       when not is_nil(tree),
       do: true

  defp should_process_scheduled_render?(_state), do: false

  defp should_continue_ticker?(%{
         animation_frame_requests: requests,
         render_scheduled_for_next_frame: scheduled
       }) do
    :queue.len(requests) > 0 or scheduled
  end

  defp choose_render_strategy(
         time_since_last_render,
         state,
         diff_result,
         new_tree_for_reference,
         now
       ) do
    case time_since_last_render >= @animation_tick_interval_ms do
      true ->
        execute_immediate_render(
          state,
          diff_result,
          new_tree_for_reference,
          now
        )

      false ->
        schedule_deferred_render(
          state,
          diff_result,
          new_tree_for_reference,
          time_since_last_render
        )
    end
  end

  defp calculate_time_diff(nil, _now), do: @animation_tick_interval_ms + 1
  defp calculate_time_diff(last_render_time, now), do: now - last_render_time

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer_ref), do: _ = Process.cancel_timer(timer_ref)

  defp prepare_render_state(nil, tree_to_render, state) do
    # No data provided - use current tree without changing state
    {
      {:replace, tree_to_render},
      state
    }
  end

  defp prepare_render_state(_data, tree_to_render, state) do
    # Data provided - treat as full replacement
    {
      {:replace, tree_to_render},
      %{
        state
        | previous_tree: state.current_tree,
          current_tree: tree_to_render
      }
    }
  end
end
