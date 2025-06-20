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

  ## TODO

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

  require Raxol.Core.Runtime.Log

  @default_renderer Raxol.Renderer
  # ~60fps for animation ticks
  @animation_tick_interval_ms 16

  defmodule State do
    @moduledoc false
    defstruct current_tree: nil,
              previous_tree: nil,
              previous_composed_tree: nil,
              previous_painted_output: nil,
              renderer_module: nil,
              animation_frame_requests: :queue.new(),
              render_scheduled_for_next_frame: false,
              last_render_time: nil,
              render_timer_ref: nil,
              animation_ticker_ref: nil
  end

  # Public API

  @doc """
  Starts the rendering pipeline GenServer. Registers under the module name by default.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      opts,
      Keyword.put_new(opts, :name, __MODULE__)
    )
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

  TODO: Support keyed children, reordering, and more granular diffs.
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
  @spec commit(painted_output :: list(map()), renderer :: module()) :: :ok
  # Updated default usage
  def commit(painted_output, renderer \\ @default_renderer) do
    # painted_output is now a list of paint operation maps from the paint/2 stage.
    Raxol.Core.Runtime.Log.debug(
      "Commit Stage: Sending #{Enum.count(painted_output)} paint operations to renderer #{inspect(renderer)}."
    )

    renderer.render(painted_output)
    # The renderer module is expected to handle this list of operations.
    :ok
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

  @impl true
  def init(opts) do
    initial_tree = Keyword.get(opts, :initial_tree, %{})
    renderer_module = Keyword.get(opts, :renderer, get_renderer())

    state = %State{
      current_tree: initial_tree,
      previous_tree: nil,
      renderer_module: renderer_module,
      animation_frame_requests: :queue.new(),
      # Ensure this is initialized
      animation_ticker_ref: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:update_tree, new_tree}, state) do
    if state.current_tree == new_tree do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: No change in tree, skipping render."
      )

      {:noreply, state}
    else
      # Delegate to TreeDiffer
      diff_result = TreeDiffer.diff_trees(state.previous_tree, new_tree)

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

  @impl true
  def handle_cast({:trigger_render, data}, state) do
    tree_to_render = data || state.current_tree

    if tree_to_render do
      Raxol.Core.Runtime.Log.debug("Pipeline: Triggering render for tree.")
      # Always treat trigger_render as a full replacement for now
      diff_result = {:replace, tree_to_render}

      updated_state = %{
        state
        | previous_tree: state.current_tree,
          current_tree: tree_to_render
      }

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

  @impl true
  def handle_cast({:request_animation_frame, pid, ref}, state) do
    Raxol.Core.Runtime.Log.debug(
      "Pipeline: Received request_animation_frame from #{inspect(pid)} with ref #{inspect(ref)}"
    )

    updated_requests = :queue.in({pid, ref}, state.animation_frame_requests)
    new_state = %{state | animation_frame_requests: updated_requests}
    final_state = ensure_animation_ticker_running(new_state)
    {:noreply, final_state}
  end

  @impl true
  def handle_cast({:schedule_render_on_next_frame, _data}, state) do
    # TODO: Ensure this is only processed on the next actual animation frame tick.
    #       Currently, if no debouncing is active, it might render immediately or schedule soon.
    if state.current_tree do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Scheduling render for next frame."
      )

      # The render itself will be triggered by :animation_tick if this flag is true
      new_state = %{state | render_scheduled_for_next_frame: true}
      final_state = ensure_animation_ticker_running(new_state)

      # old_state = schedule_or_execute_render({:replace, state.current_tree}, state.current_tree, state)
      # final_state = %{old_state | render_scheduled_for_next_frame: true} # Ensure flag is set even if rendered now
      {:noreply, final_state}
    else
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: schedule_render_on_next_frame called, but no current_tree to render."
      )

      {:noreply, state}
    end
  end

  @impl true
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

  @impl true
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

  @impl true
  def handle_info({:animation_tick, timer_id}, state) do
    if state.animation_ticker_ref == timer_id do
      # Process all queued animation frame requests
      responses = :queue.to_list(state.animation_frame_requests)
      remaining_requests_q = :queue.new()

      # Added 'from'
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

      # Reschedule the ticker if there were requests or a render was scheduled (even if not performed due to no tree)
      # Or if there are still pending requests (though current logic clears them all)
      if :queue.is_empty(state.animation_frame_requests) == false do
        new_timer_id = System.unique_integer([:positive])

        Process.send_after(
          self(),
          {:animation_tick, new_timer_id},
          @animation_tick_interval_ms
        )

        # Store timer_id in state if needed
        final_state
      else
        # No work was done, no new requests during this tick processing (unlikely), so ticker can stop.
        # It will be restarted by new requests or schedule_render_on_next_frame.
        Raxol.Core.Runtime.Log.debug(
          "Pipeline: Animation ticker stopping as no work was done or pending."
        )

        # animation_ticker_ref is already nil or will be set by ensure_animation_ticker_running if new requests come in
        final_state
      end
      |> then(&{:noreply, &1})
    else
      {:noreply, state}
    end
  end

  ## Private Helpers

  defp schedule_or_execute_render(diff_result, new_tree_for_reference, state) do
    now = System.monotonic_time(:millisecond)

    time_since_last_render =
      if state.last_render_time,
        do: now - state.last_render_time,
        else: @animation_tick_interval_ms + 1

    if time_since_last_render >= @animation_tick_interval_ms do
      Raxol.Core.Runtime.Log.debug("Pipeline: Executing render immediately.")

      if state.render_timer_ref,
        do: Process.cancel_timer(state.render_timer_ref)

      {painted_data, composed_data} =
        execute_render_stages(
          diff_result,
          new_tree_for_reference,
          state.renderer_module,
          state.previous_composed_tree,
          state.previous_painted_output
        )

      %{
        state
        | last_render_time: now,
          render_timer_ref: nil,
          render_scheduled_for_next_frame: false,
          previous_composed_tree: composed_data,
          previous_painted_output: painted_data
      }
    else
      delay = @animation_tick_interval_ms - time_since_last_render

      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Debouncing render. Will render in #{delay}ms."
      )

      # Cancel previous timer if it exists, to ensure only the latest update is rendered.
      if state.render_timer_ref,
        do: Process.cancel_timer(state.render_timer_ref)

      timer_id = System.unique_integer([:positive])

      Process.send_after(
        self(),
        {:deferred_render, diff_result, new_tree_for_reference, timer_id},
        delay
      )

      %{state | render_timer_ref: timer_id}
    end
  end

  defp execute_render_stages(
         diff_result,
         new_tree_for_reference,
         renderer_module,
         previous_composed_tree,
         previous_painted_output
       ) do
    if is_map(new_tree_for_reference) or diff_result == {:replace, nil} or
         (is_tuple(diff_result) and elem(diff_result, 0) == :replace) do
      layout_data = Layouter.layout_tree(diff_result, new_tree_for_reference)

      if is_map(layout_data) or
           (is_tuple(diff_result) and elem(diff_result, 0) == :replace and
              elem(diff_result, 1) == nil) do
        composed_data =
          Composer.compose_render_tree(
            layout_data,
            new_tree_for_reference,
            previous_composed_tree
          )

        if is_map(composed_data) or
             (is_map(layout_data) and map_size(layout_data) == 0) or
             layout_data == nil do
          painted_data =
            Painter.paint(
              composed_data,
              new_tree_for_reference,
              previous_composed_tree,
              previous_painted_output
            )

          commit(painted_data, renderer_module)
          {painted_data, composed_data}
        else
          Raxol.Core.Runtime.Log.debug(
            "Render Pipeline: Composition stage resulted in nil, skipping paint and commit."
          )

          # Reuse old paint if compose was nil, but save new composed
          {previous_painted_output, composed_data}
        end
      else
        Raxol.Core.Runtime.Log.debug(
          "Render Pipeline: Layout stage resulted in nil, skipping compose, paint and commit."
        )

        # Reuse old paint and compose
        {previous_painted_output, previous_composed_tree}
      end
    else
      Raxol.Core.Runtime.Log.debug(
        "Render Pipeline: No effective tree to process based on initial diff_result and new_tree_for_reference."
      )

      # Reuse old paint and compose
      {previous_painted_output, previous_composed_tree}
    end
  end

  defp ensure_animation_ticker_running(state) do
    if is_nil(state.animation_ticker_ref) do
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Animation ticker not running, starting it."
      )

      timer_id = System.unique_integer([:positive])

      Process.send_after(
        self(),
        {:animation_tick, timer_id},
        @animation_tick_interval_ms
      )

      %{state | animation_ticker_ref: timer_id}
    else
      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Animation ticker already running."
      )

      state
    end
  end
end
