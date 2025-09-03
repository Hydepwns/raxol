defmodule Raxol.UI.State.HooksRefactored do
  @moduledoc """
  Refactored UI State Hooks with functional error handling.

  Replaces try/catch blocks with safe execution functions and Result types.
  This provides better composability and explicit error handling.
  """

  alias Raxol.UI.State.Management.Server
  require Logger

  # Result type for safe operations
  defmodule Result do
    @type t(ok, error) :: {:ok, ok} | {:error, error}
  end

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
  Safely execute a function and return a Result type.
  """
  @spec safe_execute((-> any()), any()) :: Result.t(any(), any())
  defp safe_execute(fun, default \\ nil) when is_function(fun, 0) do
    case Raxol.Core.ErrorHandling.safe_call(fun) do
      {:ok, result} -> {:ok, result}
      {:error, {error, _stacktrace}} -> {:error, {error, default}}
    end
  end

  @doc """
  Execute a function with logging on error.
  """
  @spec execute_with_logging((-> any()), String.t(), any()) :: any()
  defp execute_with_logging(fun, context, default \\ nil) do
    case safe_execute(fun, default) do
      {:ok, result} ->
        result

      {:error, {error, default_value}} ->
        Logger.warning("#{context} failed: #{inspect(error)}")
        default_value
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
  Hook for performing side effects with safe cleanup.

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
      run_cleanup(component_id, cleanup_key)

      # Run new effect safely
      cleanup = execute_with_logging(effect_fn, "Effect execution", nil)

      # Store new dependencies and cleanup
      Server.set_hook_state(component_id, deps_key, dependencies)
      Server.set_hook_state(component_id, cleanup_key, cleanup)
    end

    :ok
  end

  defp run_cleanup(component_id, cleanup_key) do
    case Server.get_hook_state(component_id, cleanup_key) do
      cleanup_fn when is_function(cleanup_fn, 0) ->
        execute_with_logging(cleanup_fn, "Effect cleanup")

      _ ->
        :ok
    end
  end

  @doc """
  Hook for memoizing expensive computations with safe execution.

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
      # Recompute value safely
      new_value = execute_with_logging(compute_fn, "Memo computation", nil)

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
  Hook for managing state with a reducer function using safe execution.

  ## Examples

      {state, dispatch} = use_reducer(reducer, %{count: 0})
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
      new_state = safe_reduce(reducer_fn, current_state, action)
      Server.set_hook_state(component_id, hook_id, new_state)
      request_component_update(component_id)
    end

    {current_state, dispatch}
  end

  defp safe_reduce(reducer_fn, current_state, action) do
    case safe_execute(
           fn -> reducer_fn.(current_state, action) end,
           current_state
         ) do
      {:ok, new_state} ->
        new_state

      {:error, {error, fallback}} ->
        Logger.error(
          "Reducer failed: #{inspect(error)}, action: #{inspect(action)}"
        )

        fallback
    end
  end

  @doc """
  Executes a function within the context of a specific component.
  """
  def with_component_context(component_id, fun) when is_function(fun, 0) do
    ensure_server_started()

    case safe_execute(
           fn ->
             Server.set_component_id(component_id)
             Server.set_render_context(%{hook_index: 0})
             result = fun.()
             Server.clear_component_context(component_id)
             result
           end,
           nil
         ) do
      {:ok, result} ->
        result

      {:error, {error, _}} ->
        Server.clear_component_context(component_id)
        raise error
    end
  end

  @doc """
  Clears all hooks for a component safely.
  """
  def clear_component_hooks(component_id) do
    ensure_server_started()

    # Get all cleanup functions before clearing
    hooks = Server.get_all_hook_state(component_id)

    # Run all cleanup functions safely
    Enum.each(hooks, fn
      {{_hook_id, :cleanup}, cleanup_fn} when is_function(cleanup_fn, 0) ->
        execute_with_logging(cleanup_fn, "Component cleanup")

      _ ->
        :ok
    end)

    # Clear all hook state
    Server.clear_hook_state(component_id)
    :ok
  end

  # Private helper functions

  defp get_current_component_id do
    Server.get_component_id()
  end

  defp get_next_hook_id do
    context = Server.get_render_context() || %{hook_index: 0}
    hook_id = context.hook_index
    Server.set_render_context(%{context | hook_index: hook_id + 1})
    hook_id
  end

  defp request_component_update(component_id) do
    # Trigger re-render for the component
    Server.schedule_update(component_id)
  end

  defp dependencies_changed?(nil, _), do: true
  defp dependencies_changed?(prev, current) when prev == current, do: false
  defp dependencies_changed?(_, _), do: true
end
