defmodule Raxol.UI.State.Hooks do
  @moduledoc """
  Refactored UI State Hooks with GenServer-based state management.

  This module provides React-like hooks functionality but uses supervised
  state management instead of Process dictionary for component context.

  ## Migration Notes

  Component ID, render context, and component process tracking has been moved
  to the UI.State.Management.Server, eliminating Process dictionary usage.
  """

  alias Raxol.UI.State.Management.Server
  alias Raxol.Core.ErrorHandling
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

    if dependencies_changed?(prev_deps, dependencies) do
      # Run cleanup from previous effect if any
      cleanup_key = {hook_id, :cleanup}

      case Server.get_hook_state(component_id, cleanup_key) do
        cleanup_fn when is_function(cleanup_fn, 0) ->
          ErrorHandling.safe_call_with_logging(
            cleanup_fn,
            "Effect cleanup failed"
          )

        _ ->
          :ok
      end

      # Run new effect
      cleanup =
        case ErrorHandling.safe_call_with_logging(
               effect_fn,
               "Effect failed"
             ) do
          {:ok, result} -> result
          {:error, _} -> nil
        end

      # Store new dependencies and cleanup
      Server.set_hook_state(component_id, deps_key, dependencies)
      Server.set_hook_state(component_id, cleanup_key, cleanup)
    end

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

    if dependencies_changed?(prev_deps, dependencies) do
      # Recompute value
      new_value =
        case ErrorHandling.safe_call_with_logging(
               compute_fn,
               "Memo computation failed"
             ) do
          {:ok, result} -> result
          {:error, _} -> nil
        end

      Server.set_hook_state(component_id, deps_key, dependencies)
      Server.set_hook_state(component_id, value_key, new_value)
      new_value
    else
      # Return cached value
      Server.get_hook_state(component_id, value_key)
    end
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

    if dependencies_changed?(prev_deps, dependencies) do
      Server.set_hook_state(component_id, deps_key, dependencies)
      Server.set_hook_state(component_id, callback_key, callback_fn)
      callback_fn
    else
      case Server.get_hook_state(component_id, callback_key) do
        nil -> callback_fn
        cached_fn -> cached_fn
      end
    end
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
      new_state =
        case ErrorHandling.safe_call_with_logging(
               fn -> reducer_fn.(current_state, action) end,
               "Reducer failed"
             ) do
          {:ok, result} -> result
          {:error, _} -> current_state
        end

      Server.set_hook_state(component_id, hook_id, new_state)
      request_component_update(component_id)
    end

    {current_state, dispatch}
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

  defp get_current_render_context do
    Server.get_render_context()
  end

  defp dependencies_changed?(nil, _new_deps), do: true

  defp dependencies_changed?(prev_deps, new_deps) do
    prev_deps != new_deps
  end

  defp request_component_update(component_id) do
    # Send update message to component process if available
    case Server.get_component_process() do
      nil ->
        # No component process, log for debugging
        Logger.debug(
          "Component update requested for #{component_id} but no process registered"
        )

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          send(pid, {:component_update, component_id})
        end

      _ ->
        :ok
    end
  end

  # Context management functions for compatibility

  def set_component_context(component_id, process_pid \\ nil) do
    ensure_server_started()
    Server.set_component_id(component_id)
    if process_pid, do: Server.set_component_process(process_pid)
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

    # Use ensure_cleanup to guarantee context restoration
    ErrorHandling.ensure_cleanup(
      fn ->
        Server.set_component_id(component_id)
        Server.set_render_context(%{hook_index: 0})
        fun.()
      end,
      fn ->
        Server.set_component_id(prev_id)
        Server.set_render_context(prev_context)
      end
    )
    |> ErrorHandling.unwrap_or(nil)
  end
end
