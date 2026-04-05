defmodule Raxol.MCP.ToolSynchronizer do
  @moduledoc """
  Per-session GenServer that bridges the render pipeline to the MCP Registry.

  Listens for `[:raxol, :runtime, :view_tree_updated]` telemetry events,
  derives tools from the view tree via `TreeWalker`, diffs against the
  previously registered set, and updates the Registry. Debounces rapid
  renders (50ms) to avoid thrashing.

  Started by `Raxol.Headless` when creating a session. Linked to the
  session lifecycle -- dies when the session dies, cleaning up its tools.

  ## Usage

      {:ok, pid} = ToolSynchronizer.start_link(
        registry: Raxol.MCP.Registry,
        dispatcher_pid: dispatcher_pid,
        session_id: :my_session
      )
  """

  use GenServer

  alias Raxol.MCP.{FocusLens, Registry, TreeWalker}

  @debounce_ms 50

  defstruct [
    :registry,
    :dispatcher_pid,
    :session_id,
    :telemetry_handler_id,
    :debounce_ref,
    current_tool_names: MapSet.new(),
    pending_view_tree: nil
  ]

  @doc "Start a ToolSynchronizer linked to the calling process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Force an immediate tool sync from the current view tree."
  @spec sync(GenServer.server(), map()) :: :ok
  def sync(synchronizer, view_tree) do
    GenServer.cast(synchronizer, {:sync_now, view_tree})
  end

  # -- GenServer callbacks --

  @impl true
  def init(opts) do
    registry = Keyword.fetch!(opts, :registry)
    dispatcher_pid = Keyword.fetch!(opts, :dispatcher_pid)
    session_id = Keyword.fetch!(opts, :session_id)

    handler_id = "tool_sync_#{session_id}_#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:raxol, :runtime, :view_tree_updated],
      &__MODULE__.handle_telemetry_event/4,
      %{synchronizer: self(), dispatcher_pid: dispatcher_pid}
    )

    # Register the discover_tools meta-tool
    discover_tool = FocusLens.discover_tools_spec(registry)
    Registry.register_tools(registry, [discover_tool])

    state = %__MODULE__{
      registry: registry,
      dispatcher_pid: dispatcher_pid,
      session_id: session_id,
      telemetry_handler_id: handler_id,
      current_tool_names: MapSet.new(["discover_tools"])
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:view_tree_updated, view_tree}, state) do
    # Debounce: cancel previous timer, start new one
    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)

    ref = Process.send_after(self(), :debounce_fire, @debounce_ms)
    {:noreply, %{state | pending_view_tree: view_tree, debounce_ref: ref}}
  end

  def handle_cast({:sync_now, view_tree}, state) do
    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
    new_state = do_sync(view_tree, state)
    {:noreply, %{new_state | debounce_ref: nil, pending_view_tree: nil}}
  end

  @impl true
  def handle_info(:debounce_fire, %{pending_view_tree: nil} = state) do
    {:noreply, %{state | debounce_ref: nil}}
  end

  def handle_info(:debounce_fire, state) do
    new_state = do_sync(state.pending_view_tree, state)
    {:noreply, %{new_state | debounce_ref: nil, pending_view_tree: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    :telemetry.detach(state.telemetry_handler_id)

    # Clean up all tools registered by this session
    names = MapSet.to_list(state.current_tool_names)

    if names != [] do
      try do
        Registry.unregister_tools(state.registry, names)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  # -- Telemetry handler (called in the emitting process) --

  @doc false
  def handle_telemetry_event(
        _event_name,
        _measurements,
        %{view_tree: view_tree, dispatcher_pid: dispatcher_pid},
        %{synchronizer: synchronizer, dispatcher_pid: expected_pid}
      ) do
    # Only handle events from our session's dispatcher
    if dispatcher_pid == expected_pid do
      GenServer.cast(synchronizer, {:view_tree_updated, view_tree})
    end
  end

  def handle_telemetry_event(_event_name, _measurements, _metadata, _config), do: :ok

  # -- Private --

  defp do_sync(view_tree, state) do
    context = %{
      dispatcher_pid: state.dispatcher_pid,
      session_id: state.session_id
    }

    new_tools = TreeWalker.derive_tools(view_tree, context)
    new_tool_names = MapSet.new(Enum.map(new_tools, & &1.name))

    # Always keep discover_tools
    new_tool_names = MapSet.put(new_tool_names, "discover_tools")

    removed = MapSet.difference(state.current_tool_names, new_tool_names)
    added_tools = Enum.filter(new_tools, &(not MapSet.member?(state.current_tool_names, &1.name)))

    if MapSet.size(removed) > 0 do
      Registry.unregister_tools(state.registry, MapSet.to_list(removed))
    end

    if added_tools != [] do
      Registry.register_tools(state.registry, added_tools)
    end

    %{state | current_tool_names: new_tool_names}
  end
end
