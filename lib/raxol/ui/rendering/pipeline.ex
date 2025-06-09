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
    # Default to ~60fps for throttling
    @min_render_interval_ms 16
    defstruct current_tree: nil,
              previous_tree: nil,
              previous_composed_tree: nil,
              previous_painted_output: nil,
              renderer_module: nil,
              min_render_interval_ms: @min_render_interval_ms,
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
    ref = make_ref()
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

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    initial_tree = Keyword.get(opts, :initial_tree, %{})

    renderer_module =
      Keyword.get(opts, :renderer_module, @default_renderer)

    state = %State{
      current_tree: initial_tree,
      previous_tree: nil,
      renderer_module: renderer_module,
      min_render_interval_ms:
        Keyword.get(
          opts,
          :min_render_interval_ms,
          State.__struct__().min_render_interval_ms
        ),
      animation_frame_requests: :queue.new(),
      # Ensure this is initialized
      animation_ticker_ref: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:request_animation_frame, pid, ref}, _from, state) do
    # Add request to queue
    new_queue = :queue.in({pid, ref}, state.animation_frame_requests)

    # Ensure animation ticker is running to process the queue
    new_state =
      %{state | animation_frame_requests: new_queue}
      |> ensure_animation_ticker_running()

    {:noreply, new_state}
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

  @impl true
  def handle_info(:render, state) do
    Raxol.Core.Runtime.Log.debug("Pipeline: Handling scheduled :render.")

    # Always render the most current tree
    diff_result = {:replace, state.current_tree}
    new_state = do_render(diff_result, state.current_tree, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:animation_tick, state) do
    # 1. Process animation frame requests
    {{:value, requests_to_process}, remaining_queue} =
      :queue.split(
        :queue.len(state.animation_frame_requests),
        state.animation_frame_requests
      )

    Enum.each(requests_to_process, fn {pid, ref} ->
      send(pid, {:animation_frame, ref})
    end)

    # 2. Check if a render was scheduled for this frame
    render_now = state.render_scheduled_for_next_frame && state.current_tree

    # 3. Schedule next tick if needed
    # Keep ticker if more renders might be scheduled (e.g. via animations)
    # This part is tricky. For now, we'll assume if there's a tree, we might animate.
    ticker_still_needed =
      not :queue.is_empty(remaining_queue) or
        not is_nil(state.current_tree)

    # Update state after processing requests
    state_after_requests = %{
      state
      | animation_frame_requests: remaining_queue,
        render_scheduled_for_next_frame: false
    }

    # Perform the render if scheduled
    state_after_render =
      if render_now do
        Raxol.Core.Runtime.Log.debug("Pipeline: Rendering on animation_tick.")
        diff = {:replace, state_after_requests.current_tree}
        do_render(diff, state_after_requests.current_tree, state_after_requests)
      else
        state_after_requests
      end

    # Finally, manage the ticker for the next frame
    final_state =
      if ticker_still_needed do
        # Reschedule for the next frame
        new_ticker_ref =
          Process.send_after(
            self(),
            :animation_tick,
            @animation_tick_interval_ms
          )

        %{state_after_render | animation_ticker_ref: new_ticker_ref}
      else
        # Stop the ticker
        %{state_after_render | animation_ticker_ref: nil}
      end

    {:noreply, final_state}
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
    # The actual rendering to the screen is asynchronous from this point.
    :ok
  end

  # --- Private Helpers ---

  # Decides whether to render immediately or debounce.
  defp schedule_or_execute_render(diff_result, tree, state) do
    # Cancel any previously scheduled render
    cancel_render_timer(state.render_timer_ref)

    time_since_last_render =
      if state.last_render_time,
        do: System.monotonic_time(:millisecond) - state.last_render_time,
        # Render immediately first time
        else: state.min_render_interval_ms + 1

    if time_since_last_render >= state.min_render_interval_ms do
      Raxol.Core.Runtime.Log.debug("Pipeline: Executing render immediately.")
      # Render immediately
      do_render(diff_result, tree, state)
    else
      # Debounce: schedule render for later
      delay = state.min_render_interval_ms - time_since_last_render

      Raxol.Core.Runtime.Log.debug(
        "Pipeline: Debouncing render. Will render in #{delay}ms."
      )

      timer_ref = Process.send_after(self(), :render, delay)
      %{state | render_timer_ref: timer_ref}
    end
  end

  # The core rendering logic
  defp do_render(diff_result, tree, state) do
    start_time = System.monotonic_time(:nanosecond)
    Raxol.Core.Runtime.Log.debug("Pipeline: Beginning full render process.")

    # --- 1. Layout Stage ---
    {layout_result, new_composed_tree} =
      if diff_result == :no_change and state.previous_composed_tree do
        Raxol.Core.Runtime.Log.debug("Layout Stage: Skipping, no change.")
        {:no_change, state.previous_composed_tree}
      else
        Raxol.Core.Runtime.Log.debug("Layout Stage: Calculating layout.")
        layouter_output = Layouter.layout_tree(diff_result, tree)
        {:ok, layouter_output}
      end

    layout_time = System.monotonic_time(:nanosecond)

    # --- 2. Composition Stage ---
    # `new_composed_tree` is the output from the layout stage
    {compose_result, new_painted_output} =
      if layout_result == :no_change and state.previous_painted_output do
        Raxol.Core.Runtime.Log.debug("Compose Stage: Skipping, no change.")
        {:no_change, state.previous_painted_output}
      else
        Raxol.Core.Runtime.Log.debug("Compose Stage: Composing render tree.")

        composer_output =
          Composer.compose_render_tree(
            new_composed_tree,
            tree,
            state.previous_composed_tree
          )

        {:ok, composer_output}
      end

    compose_time = System.monotonic_time(:nanosecond)

    # --- 3. Paint Stage ---
    # `new_painted_output` is the output from the composition stage
    paint_result =
      if compose_result == :no_change do
        Raxol.Core.Runtime.Log.debug("Paint Stage: Skipping, no change.")
        :no_change
      else
        Raxol.Core.Runtime.Log.debug("Paint Stage: Painting to draw commands.")

        Painter.paint(
          new_painted_output,
          tree,
          state.previous_composed_tree,
          state.previous_painted_output
        )
      end

    paint_time = System.monotonic_time(:nanosecond)

    # --- 4. Commit Stage ---
    if paint_result == :no_change do
      Raxol.Core.Runtime.Log.debug("Commit Stage: Skipping, no change.")
    else
      Raxol.Core.Runtime.Log.debug("Commit Stage: Committing to renderer.")
      commit(paint_result, state.renderer_module)
    end

    end_time = System.monotonic_time(:nanosecond)
    total_duration_ms = (end_time - start_time) / 1_000_000
    layout_duration_ms = (layout_time - start_time) / 1_000_000
    compose_duration_ms = (compose_time - layout_time) / 1_000_000
    paint_duration_ms = (paint_time - compose_time) / 1_000_000
    commit_duration_ms = (end_time - paint_time) / 1_000_000

    Raxol.Core.Runtime.Log.debug(
      "Render pipeline finished in #{:erlang.float_to_binary(total_duration_ms, decimals: 3)}ms " <>
        "(Layout: #{:erlang.float_to_binary(layout_duration_ms, decimals: 3)}ms, " <>
        "Compose: #{:erlang.float_to_binary(compose_duration_ms, decimals: 3)}ms, " <>
        "Paint: #{:erlang.float_to_binary(paint_duration_ms, decimals: 3)}ms, " <>
        "Commit: #{:erlang.float_to_binary(commit_duration_ms, decimals: 3)}ms)"
    )

    # Update state with the results of this render pass
    %{
      state
      | previous_composed_tree: new_composed_tree,
        previous_painted_output: new_painted_output,
        last_render_time: System.monotonic_time(:millisecond),
        # Clear the timer ref after it has fired or been used
        render_timer_ref: nil
    }
  end

  defp cancel_render_timer(nil), do: :ok
  defp cancel_render_timer(ref), do: Process.cancel_timer(ref)

  # Starts the ticker only if it's not already running and there's work to do.
  defp ensure_animation_ticker_running(state) do
    # Ticker is needed if there are pending frame requests
    ticker_needed = not :queue.is_empty(state.animation_frame_requests)

    if ticker_needed and is_nil(state.animation_ticker_ref) do
      Raxol.Core.Runtime.Log.debug("Starting animation ticker.")

      new_ticker_ref =
        Process.send_after(self(), :animation_tick, @animation_tick_interval_ms)

      %{state | animation_ticker_ref: new_ticker_ref}
    else
      state
    end
  end
end
