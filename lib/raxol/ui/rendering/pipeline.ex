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

  use GenServer

  alias Raxol.UI.Rendering.Renderer
  alias Raxol.UI.Rendering.TreeDiffer
  alias Raxol.UI.Rendering.Layouter
  alias Raxol.UI.Rendering.Composer
  alias Raxol.UI.Rendering.Painter

  # New pipeline modules
  alias Raxol.UI.Rendering.Pipeline.{State, Stages, Animation, Scheduler}

  require Raxol.Core.Runtime.Log
  require Logger

  @default_renderer Raxol.UI.Rendering.Renderer

  # Public API

  @doc """
  Starts the rendering pipeline GenServer. Registers under the module name by default.
  """
  def start_link(opts \\ []) do
    name =
      if Mix.env() == :test do
        Raxol.Test.ProcessNaming.unique_name(__MODULE__, opts)
      else
        Keyword.get(opts, :name, __MODULE__)
      end

    GenServer.start_link(__MODULE__, opts, name: name)
  end

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
    * {:replace, new_tree} if the root node differs
    * {:update, path, changes} for subtree updates (path is a list of indices)

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

  # GenServer Implementation

  @impl GenServer
  def init(opts) do
    initial_tree = Keyword.get(opts, :initial_tree, %{})
    opts_with_renderer = Keyword.put(opts, :renderer, get_renderer())
    
    state = State.new(opts_with_renderer)
    state_with_tree = if initial_tree != %{} do
      State.update_tree(state, initial_tree)
    else
      state
    end

    {:ok, state_with_tree}
  end

  @impl GenServer
  def handle_cast({:update_tree, new_tree}, state) do
    if state.current_tree == new_tree do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: No change in tree, skipping render."
      )

      {:noreply, state}
    else
      # Delegate to TreeDiffer - use current_tree as the old tree for comparison
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Calling TreeDiffer with current_tree: #{inspect(state.current_tree)}, new_tree: #{inspect(new_tree)}"
      )

      diff_result = TreeDiffer.diff_trees(state.current_tree, new_tree)

      Raxol.Core.Runtime.Log.debug(
        "Pipeline: TreeDiffer returned: #{inspect(diff_result)}"
      )

      if diff_result == :no_change do
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Diff result is :no_change, skipping render."
        )

        new_state_after_diff = %{
          state
          | previous_tree: state.current_tree,
            current_tree: new_tree
        }

        {:noreply, new_state_after_diff}
      else
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

  @impl GenServer
  def handle_cast({:trigger_render, data}, state) do
    tree_to_render = data || state.current_tree

    if tree_to_render do
      Raxol.Core.Runtime.Log.debug("Pipeline: Triggering render for tree.")

      # If data is provided, use it as the new tree
      # If data is nil, use the current tree without changing it
      {diff_result, updated_state} =
        if data do
          # Data provided - treat as full replacement
          {
            {:replace, tree_to_render},
            %{
              state
              | previous_tree: state.current_tree,
                current_tree: tree_to_render
            }
          }
        else
          # No data provided - use current tree without changing state
          {
            {:replace, tree_to_render},
            state
          }
        end

      final_state =
        schedule_or_execute_render(diff_result, tree_to_render, updated_state)

      {:noreply, final_state}
    else
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Triggering render, but no tree available."
      )

      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:request_animation_frame, pid, ref}, state) do
    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Received request_animation_frame from #{inspect(pid)} with ref #{inspect(ref)}"
    )

    updated_requests = :queue.in({pid, ref}, state.animation_frame_requests)
    new_state = %{state | animation_frame_requests: updated_requests}
    final_state = ensure_animation_ticker_running(new_state)
    {:noreply, final_state}
  end

  @impl GenServer
  def handle_cast(:schedule_render_on_next_frame, state) do
    if state.current_tree do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Scheduling render for next frame."
      )

      new_state = %{state | render_scheduled_for_next_frame: true}
      final_state = ensure_animation_ticker_running(new_state)
      {:noreply, final_state}
    else
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: schedule_render_on_next_frame called, but no current_tree to render."
      )

      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_call({:request_animation_frame, pid, ref}, from, state) do
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

  @impl GenServer
  def handle_info(
        {:deferred_render, diff_result, new_tree_for_reference, timer_id},
        state
      ) do
    if state.render_timer_ref == timer_id do
      {painted_data, composed_data} =
        execute_render_stages(
          diff_result,
          new_tree_for_reference,
          state.renderer_module,
          state.previous_composed_tree,
          state.previous_painted_output
        )

      # Commit the painted output to the renderer
      commit(
        painted_data,
        state.renderer_module,
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
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:animation_tick, :timer_ref}, state) do
    if state.animation_ticker_ref do
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
        if current_state.render_scheduled_for_next_frame and
             current_state.current_tree do
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
        else
          current_state
        end

      # Always reschedule the ticker if there are pending requests or if a render was scheduled
      # This ensures the ticker continues running for future requests
      if :queue.len(final_state.animation_frame_requests) > 0 or
           final_state.render_scheduled_for_next_frame do
        # Use the actual timer reference returned by Process.send_after
        timer_ref =
          Process.send_after(
            self(),
            {:animation_tick, :timer_ref},
            @animation_tick_interval_ms
          )

        %{final_state | animation_ticker_ref: timer_ref}
      else
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Animation ticker stopping as no work was done or pending."
        )

        final_state
      end
      |> then(&{:noreply, &1})
    else
      {:noreply, state}
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

    cancel_timer_if_exists(state.render_timer_ref)

    {painted_data, composed_data} =
      execute_render_stages(
        diff_result,
        new_tree_for_reference,
        state.renderer_module,
        state.previous_composed_tree,
        state.previous_painted_output
      )

    # Commit the painted output to the renderer
    commit(
      painted_data,
      state.renderer_module,
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

    if time_since_last_render >= @animation_tick_interval_ms do
      execute_immediate_render(state, diff_result, new_tree_for_reference, now)
    else
      schedule_deferred_render(
        state,
        diff_result,
        new_tree_for_reference,
        time_since_last_render
      )
    end
  end

  defp execute_immediate_render(state, diff_result, new_tree_for_reference, now) do
    Raxol.Core.Runtime.Log.debug("Pipeline: Executing render immediately.")

    cancel_timer_if_exists(state.render_timer_ref)

    {painted_data, composed_data} =
      execute_render_stages(
        diff_result,
        new_tree_for_reference,
        state.renderer_module,
        state.previous_composed_tree,
        state.previous_painted_output
      )

    # Commit the painted output to the renderer
    commit(
      painted_data,
      state.renderer_module,
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

    cancel_timer_if_exists(state.render_timer_ref)

    timer_ref =
      Process.send_after(
        self(),
        {:deferred_render, diff_result, new_tree_for_reference,
         System.unique_integer([:positive])},
        delay
      )

    %{state | render_timer_ref: timer_ref}
  end

  defp calculate_time_since_last_render(last_render_time, now) do
    if last_render_time,
      do: now - last_render_time,
      else: @animation_tick_interval_ms + 1
  end

  defp cancel_timer_if_exists(timer_ref) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
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
    if is_nil(state.animation_ticker_ref) do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Animation ticker not running, starting it."
      )

      # Use the actual timer reference returned by Process.send_after
      timer_ref =
        Process.send_after(
          self(),
          {:animation_tick, :timer_ref},
          @animation_tick_interval_ms
        )

      %{state | animation_ticker_ref: timer_ref}
    else
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Animation ticker already running."
      )

      state
    end
  end
end
