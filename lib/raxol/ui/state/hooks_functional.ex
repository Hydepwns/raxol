defmodule Raxol.UI.State.HooksFunctional do
  @moduledoc """
  Fully functional UI State Hooks with GenServer-based state management.

  This module provides React-like hooks functionality using pure functional
  patterns without any try/catch blocks.

  REFACTORED: All try/catch blocks replaced with Task-based safe execution.
  """

  alias Raxol.UI.State.Management.StateManagementServer, as: Server
  require Logger

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

  # Pattern matching helper functions for if statement elimination

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

  defp send_update_to_alive_process(pid, component_id) when is_pid(pid) do
    send_message_to_living_process(pid, component_id, Process.alive?(pid))
  end

  defp send_message_to_living_process(pid, component_id, true) do
    send(pid, {:component_update, component_id})
  end

  defp send_message_to_living_process(_pid, _component_id, false), do: :ok

  defp set_component_process_if_provided(nil), do: :ok

  defp set_component_process_if_provided(process_pid) do
    Server.set_component_process(process_pid)
  end

  # Private helper functions

  defp get_current_component_id do
    Server.get_component_id()
  end

  defp get_next_hook_id do
    # Simple hook ID generation based on call order
    context = Server.get_render_context()
    current_hook_index = Map.get(context, :hook_index, 0)
    next_index = current_hook_index + 1

    # Update context with next hook index
    updated_context = Map.put(context, :hook_index, next_index)
    Server.set_render_context(updated_context)

    current_hook_index
  end

  # Removed unused function: get_current_render_context/0

  # Removed unused functions: dependencies_changed?/2

  defp request_component_update(component_id) do
    # Send update message to component process if available
    case Server.get_component_process() do
      nil ->
        # No component process, log for debugging
        Logger.debug(
          "Component update requested for #{component_id} but no process registered"
        )

      pid when is_pid(pid) ->
        send_update_to_alive_process(pid, component_id)

      _ ->
        :ok
    end
  end

  # Safe execution functions using Task

  defp safe_execute_cleanup(cleanup_fn) do
    task = Task.async(fn -> cleanup_fn.() end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, _} ->
        :ok

      nil ->
        Logger.warning("Effect cleanup timeout")
        :ok

      {:exit, reason} ->
        Logger.warning("Effect cleanup failed: #{inspect(reason)}")
        :ok
    end
  end

  defp safe_execute_effect(effect_fn) do
    task = Task.async(fn -> effect_fn.() end)

    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Effect timeout")
        nil

      {:exit, reason} ->
        Logger.error("Effect failed: #{inspect(reason)}")
        nil
    end
  end

  defp safe_compute_memo(compute_fn) do
    task = Task.async(fn -> compute_fn.() end)

    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Memo computation timeout")
        nil

      {:exit, reason} ->
        Logger.error("Memo computation failed: #{inspect(reason)}")
        nil
    end
  end

  defp safe_execute_reducer(reducer_fn, current_state, action) do
    task = Task.async(fn -> reducer_fn.(current_state, action) end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, new_state} ->
        new_state

      nil ->
        Logger.error("Reducer timeout")
        current_state

      {:exit, reason} ->
        Logger.error("Reducer failed: #{inspect(reason)}")
        current_state
    end
  end

  # Context management functions for compatibility

  def set_component_context(component_id, process_pid \\ nil) do
    ensure_server_started()
    Server.set_component_id(component_id)
    set_component_process_if_provided(process_pid)
    :ok
  end

  def clear_component_context do
    ensure_server_started()
    Server.set_render_context(%{})
    :ok
  end

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

  defp safe_execute_with_context(fun, component_id) do
    Server.set_component_id(component_id)
    Server.set_render_context(%{hook_index: 0})

    task = Task.async(fn -> fun.() end)

    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Context execution timeout")
        {:error, :timeout}

      {:exit, reason} ->
        Logger.error("Context execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
