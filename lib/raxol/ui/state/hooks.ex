defmodule Raxol.UI.State.Hooks do
  @moduledoc """
  Unified UI State Hooks with comprehensive functionality.

  This module consolidates the best features from multiple hook implementations:
  - Task-based safe execution from HooksFunctional
  - Comprehensive error handling and Result types from HooksRefactored
  - Complete context management from the base Hooks module

  Provides React-like hooks functionality using pure functional patterns
  with robust error handling and timeout controls.

  ## Features

  - `use_state/1` - Component state management
  - `use_effect/2` - Side effects with cleanup
  - `use_memo/2` - Expensive computation memoization
  - `use_callback/2` - Stable callback references
  - `use_ref/1` - Mutable references
  - `use_reducer/2` - Reducer-based state management
  - `use_context/1` - Context access (implemented)
  - `use_async/2` - Async operations (implemented)

  ## Safety Features

  - Task-based execution with configurable timeouts
  - Comprehensive error logging and recovery
  - Zero try/catch blocks (pure functional patterns)
  - Automatic cleanup and context restoration

  ## Migration Notes

  This module replaces:
  - `Raxol.UI.State.Hooks` (basic implementation)
  - `Raxol.UI.State.HooksRefactored` (Result-type implementation)
  - `Raxol.UI.State.HooksFunctional` (Task-based implementation)
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.UI.State.Management.StateManagementServer, as: Server
  # Result type for safe operations (from HooksRefactored)
  defmodule Result do
    @moduledoc """
    Result type for safe hook operations.
    """
    @type t(ok, error) :: {:ok, ok} | {:error, error}
  end

  # Configuration for timeouts (tunable)
  @cleanup_timeout 1000
  @effect_timeout 5000
  @memo_timeout 5000
  @reducer_timeout 1000
  @context_timeout 5000

  # =============================================================================
  # SERVER MANAGEMENT
  # =============================================================================

  # Ensure server is started
  defp ensure_server_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  # =============================================================================
  # CORE HOOKS IMPLEMENTATION
  # =============================================================================

  @doc """
  Hook for managing component state.

  ## Examples

      {count, set_count} = use_state(0)
      {user, set_user} = use_state(%{name: "John"})
  """
  def use_state(initial_value) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Get or initialize state
    current_value =
      case Server.get_hook_state(component_id, hook_id) do
        nil ->
          Server.set_hook_state(component_id, hook_id, initial_value)
          initial_value

        value ->
          value
      end

    # Return state and setter function
    setter = fn new_value ->
      Server.set_hook_state(component_id, hook_id, new_value)
      request_component_update(component_id)
    end

    {current_value, setter}
  end

  @doc """
  Hook for performing side effects.

  ## Examples

      use_effect(fn ->
        # Effect code
        fn -> # Cleanup
          # Cleanup code
        end
      end, [dependency])
  """
  def use_effect(effect_fn, dependencies \\ []) when is_function(effect_fn) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Check if dependencies changed
    deps_key = {hook_id, :dependencies}
    prev_deps = Server.get_hook_state(component_id, deps_key)

    execute_effect_if_dependencies_changed(
      prev_deps,
      dependencies,
      component_id,
      hook_id,
      deps_key,
      effect_fn
    )

    :ok
  end

  @doc """
  Hook for memoizing expensive computations.

  ## Examples

      expensive_value = use_memo(fn ->
        expensive_computation(data)
      end, [data])
  """
  def use_memo(compute_fn, dependencies) when is_function(compute_fn, 0) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Check if dependencies changed
    deps_key = {hook_id, :dependencies}
    value_key = {hook_id, :value}

    prev_deps = Server.get_hook_state(component_id, deps_key)

    handle_memo_computation(
      prev_deps,
      dependencies,
      component_id,
      deps_key,
      value_key,
      compute_fn
    )
  end

  @doc """
  Hook for creating stable callback references.

  ## Examples

      handle_click = use_callback(fn ->
        set_count.(count + 1)
      end, [count])
  """
  def use_callback(callback_fn, dependencies) when is_function(callback_fn) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Check if dependencies changed
    deps_key = {hook_id, :dependencies}
    callback_key = {hook_id, :callback}

    prev_deps = Server.get_hook_state(component_id, deps_key)

    handle_callback_update(
      prev_deps,
      dependencies,
      component_id,
      deps_key,
      callback_key,
      callback_fn
    )
  end

  @doc """
  Hook for creating mutable references.

  ## Examples

      ref = use_ref(nil)
      ref.current = "new value"
  """
  def use_ref(initial_value) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Create or get existing ref
    case Server.get_hook_state(component_id, hook_id) do
      nil ->
        ref = %{current: initial_value}
        Server.set_hook_state(component_id, hook_id, ref)
        ref

      ref ->
        ref
    end
  end

  @doc """
  Hook for managing reducer-based state.

  ## Examples

      {state, dispatch} = use_reducer(reducer_fn, initial_state)
  """
  def use_reducer(reducer_fn, initial_state) when is_function(reducer_fn, 2) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Get or initialize state
    current_state =
      case Server.get_hook_state(component_id, hook_id) do
        nil ->
          Server.set_hook_state(component_id, hook_id, initial_state)
          initial_state

        state ->
          state
      end

    # Return state and dispatch function
    dispatch = fn action ->
      new_state = safe_execute_reducer(reducer_fn, current_state, action)
      Server.set_hook_state(component_id, hook_id, new_state)
      request_component_update(component_id)
    end

    {current_state, dispatch}
  end

  @doc """
  Hook for accessing context values.

  ## Examples

      theme = use_context(:theme)
      user = use_context(:current_user)
  """
  def use_context(context_key) do
    ensure_server_started()
    component_id = get_current_component_id()

    # Get context from server or return nil
    case Server.get_context(context_key) do
      nil ->
        Log.debug(
          "Context #{inspect(context_key)} not found for component #{component_id}"
        )

        nil

      value ->
        value
    end
  end

  @doc """
  Hook for async operations.

  Returns {data, loading, error, refetch_fn}.

  ## Examples

      {user_data, loading, error, refetch} = use_async(fn ->
        fetch_user(user_id)
      end, [user_id])
  """
  def use_async(fetch_fn, dependencies \\ []) when is_function(fetch_fn, 0) do
    ensure_server_started()
    component_id = get_current_component_id()
    hook_id = get_next_hook_id()

    # Check if dependencies changed
    deps_key = {hook_id, :dependencies}
    state_key = {hook_id, :async_state}
    prev_deps = Server.get_hook_state(component_id, deps_key)

    # Get current async state
    current_state =
      Server.get_hook_state(component_id, state_key) ||
        %{data: nil, loading: false, error: nil}

    # Handle dependency changes and refetch
    handle_async_dependencies(
      prev_deps,
      dependencies,
      component_id,
      hook_id,
      deps_key,
      state_key,
      fetch_fn,
      current_state
    )
  end

  # =============================================================================
  # PATTERN MATCHING HELPERS (from HooksFunctional)
  # =============================================================================

  defp execute_effect_if_dependencies_changed(
         prev_deps,
         dependencies,
         component_id,
         hook_id,
         deps_key,
         effect_fn
       )
       when prev_deps != dependencies do
    # Run cleanup from previous effect if any
    cleanup_key = {hook_id, :cleanup}

    case Server.get_hook_state(component_id, cleanup_key) do
      cleanup_fn when is_function(cleanup_fn, 0) ->
        safe_execute_cleanup(cleanup_fn)

      _ ->
        :ok
    end

    # Run new effect
    cleanup = safe_execute_effect(effect_fn)

    # Store new dependencies and cleanup
    Server.set_hook_state(component_id, deps_key, dependencies)
    Server.set_hook_state(component_id, cleanup_key, cleanup)
  end

  defp execute_effect_if_dependencies_changed(
         _prev_deps,
         _dependencies,
         _component_id,
         _hook_id,
         _deps_key,
         _effect_fn
       ),
       do: :ok

  defp handle_memo_computation(
         prev_deps,
         dependencies,
         component_id,
         deps_key,
         value_key,
         compute_fn
       )
       when prev_deps != dependencies do
    # Recompute value
    new_value = safe_compute_memo(compute_fn)

    Server.set_hook_state(component_id, deps_key, dependencies)
    Server.set_hook_state(component_id, value_key, new_value)
    new_value
  end

  defp handle_memo_computation(
         _prev_deps,
         _dependencies,
         component_id,
         _deps_key,
         value_key,
         _compute_fn
       ) do
    # Return cached value
    Server.get_hook_state(component_id, value_key)
  end

  defp handle_callback_update(
         prev_deps,
         dependencies,
         component_id,
         deps_key,
         callback_key,
         callback_fn
       )
       when prev_deps != dependencies do
    Server.set_hook_state(component_id, deps_key, dependencies)
    Server.set_hook_state(component_id, callback_key, callback_fn)
    callback_fn
  end

  defp handle_callback_update(
         _prev_deps,
         _dependencies,
         component_id,
         _deps_key,
         callback_key,
         callback_fn
       ) do
    case Server.get_hook_state(component_id, callback_key) do
      nil -> callback_fn
      cached_fn -> cached_fn
    end
  end

  defp handle_async_dependencies(
         prev_deps,
         dependencies,
         component_id,
         hook_id,
         deps_key,
         state_key,
         fetch_fn,
         _current_state
       )
       when prev_deps != dependencies do
    # Dependencies changed - start new fetch
    start_async_fetch(
      component_id,
      hook_id,
      deps_key,
      state_key,
      fetch_fn,
      dependencies
    )
  end

  defp handle_async_dependencies(
         _prev_deps,
         _dependencies,
         component_id,
         _hook_id,
         _deps_key,
         state_key,
         fetch_fn,
         _current_state
       ) do
    # Dependencies unchanged - return current state with refetch function
    refetch_fn = fn ->
      start_async_fetch(
        component_id,
        get_next_hook_id(),
        nil,
        state_key,
        fetch_fn,
        []
      )
    end

    # Get current state from server
    current_state =
      Server.get_hook_state(component_id, state_key) ||
        %{data: nil, loading: false, error: nil}

    {current_state.data, current_state.loading, current_state.error, refetch_fn}
  end

  defp start_async_fetch(
         component_id,
         hook_id,
         deps_key,
         state_key,
         fetch_fn,
         dependencies
       ) do
    # Set loading state
    loading_state = %{data: nil, loading: true, error: nil}
    Server.set_hook_state(component_id, state_key, loading_state)

    if deps_key, do: Server.set_hook_state(component_id, deps_key, dependencies)

    # Start async fetch
    _task_pid =
      spawn(fn ->
        result = safe_execute_async(fetch_fn)

        final_state =
          case result do
            {:ok, data} ->
              %{data: data, loading: false, error: nil}

            {:error, error} ->
              %{data: nil, loading: false, error: error}
          end

        Server.set_hook_state(component_id, state_key, final_state)
        request_component_update(component_id)
      end)

    refetch_fn = fn ->
      start_async_fetch(
        component_id,
        hook_id,
        deps_key,
        state_key,
        fetch_fn,
        dependencies
      )
    end

    {loading_state.data, loading_state.loading, loading_state.error, refetch_fn}
  end

  # =============================================================================
  # TASK-BASED SAFE EXECUTION (from HooksFunctional)
  # =============================================================================

  defp safe_execute_cleanup(cleanup_fn) do
    task = Task.async(fn -> cleanup_fn.() end)

    case Task.yield(task, @cleanup_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, _} ->
        :ok

      nil ->
        Log.warning("Effect cleanup timeout")
        :ok

      {:exit, reason} ->
        Log.warning("Effect cleanup failed: #{inspect(reason)}")
        :ok
    end
  end

  defp safe_execute_effect(effect_fn) do
    task = Task.async(fn -> effect_fn.() end)

    case Task.yield(task, @effect_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Log.error("Effect timeout")
        nil

      {:exit, reason} ->
        Log.error("Effect failed: #{inspect(reason)}")
        nil
    end
  end

  defp safe_compute_memo(compute_fn) do
    task = Task.async(fn -> compute_fn.() end)

    case Task.yield(task, @memo_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Log.error("Memo computation timeout")
        nil

      {:exit, reason} ->
        Log.error("Memo computation failed: #{inspect(reason)}")
        nil
    end
  end

  defp safe_execute_reducer(reducer_fn, current_state, action) do
    task = Task.async(fn -> reducer_fn.(current_state, action) end)

    case Task.yield(task, @reducer_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, new_state} ->
        new_state

      nil ->
        Log.error("Reducer timeout")
        current_state

      {:exit, reason} ->
        Log.error("Reducer failed: #{inspect(reason)}")
        current_state
    end
  end

  defp safe_execute_async(fetch_fn) do
    task = Task.async(fn -> fetch_fn.() end)

    case Task.yield(task, @effect_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        {:ok, result}

      nil ->
        Log.error("Async fetch timeout")
        {:error, :timeout}

      {:exit, reason} ->
        Log.error("Async fetch failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # =============================================================================
  # CONTEXT MANAGEMENT (comprehensive from all modules)
  # =============================================================================

  @doc """
  Sets the component context for hook calls.
  """
  def set_component_context(component_id, process_pid \\ nil) do
    ensure_server_started()
    Server.set_component_id(component_id)
    set_component_process_if_provided(process_pid)
    :ok
  end

  @doc """
  Clears the component context.
  """
  def clear_component_context do
    ensure_server_started()
    Server.set_render_context(%{})
    :ok
  end

  @doc """
  Executes a function within the context of a specific component.
  Provides comprehensive context restoration and error handling.
  """
  def with_component_context(component_id, fun) when is_function(fun, 0) do
    ensure_server_started()
    prev_id = Server.get_component_id()
    prev_context = Server.get_render_context()

    # Use safe execution for the context function
    result = safe_execute_with_context(fun, component_id)

    # Always restore previous context
    Server.set_component_id(prev_id)
    Server.set_render_context(prev_context)

    result
  end

  @doc """
  Clears all hooks for a component safely (from HooksRefactored).
  """
  def clear_component_hooks(component_id) do
    ensure_server_started()

    # Get all cleanup functions before clearing
    hooks = Server.get_all_hook_state(component_id)

    # Run all cleanup functions safely
    Enum.each(hooks, fn
      {{_hook_id, :cleanup}, cleanup_fn} when is_function(cleanup_fn, 0) ->
        safe_execute_cleanup(cleanup_fn)

      _ ->
        :ok
    end)

    # Clear all hook state
    Server.clear_hook_state(component_id)
    :ok
  end

  # =============================================================================
  # PRIVATE HELPER FUNCTIONS
  # =============================================================================

  defp get_current_component_id do
    Server.get_component_id()
  end

  defp get_next_hook_id do
    # Simple hook ID generation based on call order
    context = Server.get_render_context() || %{hook_index: 0}
    current_hook_index = Map.get(context, :hook_index, 0)
    next_index = current_hook_index + 1

    # Update context with next hook index
    updated_context = Map.put(context, :hook_index, next_index)
    Server.set_render_context(updated_context)

    current_hook_index
  end

  defp request_component_update(component_id) do
    # Send update message to component process if available
    case Server.get_component_process() do
      nil ->
        Log.debug(
          "Component update requested for #{component_id} but no process registered"
        )

      pid when is_pid(pid) ->
        send_update_to_alive_process(pid, component_id)

      _ ->
        :ok
    end
  end

  defp send_update_to_alive_process(pid, component_id) when is_pid(pid) do
    send_message_to_living_process(pid, component_id, Process.alive?(pid))
  end

  defp send_message_to_living_process(pid, component_id, true) do
    _ = send(pid, {:component_update, component_id})
    :ok
  end

  defp send_message_to_living_process(_pid, _component_id, false), do: :ok

  defp set_component_process_if_provided(nil), do: :ok

  defp set_component_process_if_provided(process_pid) do
    Server.set_component_process(process_pid)
  end

  defp safe_execute_with_context(fun, component_id) do
    Server.set_component_id(component_id)
    Server.set_render_context(%{hook_index: 0})

    task = Task.async(fn -> fun.() end)

    case Task.yield(task, @context_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Log.error("Context execution timeout")
        {:error, :timeout}

      {:exit, reason} ->
        Log.error("Context execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
