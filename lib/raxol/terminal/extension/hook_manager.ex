defmodule Raxol.Terminal.Extension.HookManager do
  @moduledoc """
  Handles extension hook management operations including registering, unregistering, and triggering hooks.
  """

  require Logger

  @doc """
  Registers a hook for an extension.
  """
  def register_hook(extension_id, hook_name, callback, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        handle_hook_registration(extension, extension_id, hook_name, callback, state)
    end
  end

  @doc """
  Unregisters a hook for an extension.
  """
  def unregister_hook(extension_id, hook_name, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        handle_hook_unregistration(extension, extension_id, hook_name, state)
    end
  end

  @doc """
  Triggers a hook for all registered extensions.
  """
  def trigger_hook(hook_name, args, state) do
    case Map.get(state.hooks, hook_name) do
      nil ->
        {:ok, []}

      callbacks ->
        results = execute_hook_callbacks(callbacks, args)
        {:ok, results}
    end
  end

  # Private functions

  defp handle_hook_registration(extension, extension_id, hook_name, callback, state) do
    if hook_name in extension.hooks do
      callback_map = build_callback_map(callback, extension_id)

      new_hooks =
        Map.update(
          state.hooks,
          hook_name,
          [callback_map],
          &[callback_map | &1]
        )

      new_state = %{state | hooks: new_hooks}
      {:ok, new_state}
    else
      {:error, :hook_not_found}
    end
  end

  defp handle_hook_unregistration(extension, extension_id, hook_name, state) do
    if hook_name in extension.hooks do
      new_hooks = remove_hook_callback(state.hooks, hook_name, extension_id)
      new_state = %{state | hooks: new_hooks}
      {:ok, new_state}
    else
      {:error, :hook_not_found}
    end
  end

  defp build_callback_map(callback, extension_id) do
    case callback do
      %{fun: _} -> callback
      fun when is_function(fun) -> %{fun: fun, extension_id: extension_id}
      _ -> %{fun: callback, extension_id: extension_id}
    end
  end

  defp remove_hook_callback(hooks, hook_name, extension_id) do
    Map.update(
      hooks,
      hook_name,
      [],
      &Enum.reject(&1, fn callback ->
        callback.extension_id == extension_id
      end)
    )
  end

  defp execute_hook_callbacks(callbacks, args) do
    Enum.map(callbacks, fn callback ->
      Task.async(fn ->
        try do
          callback.fun.(args)
        rescue
          e ->
            Logger.error("Hook execution failed: #{inspect(e)}")
            {:error, :hook_execution_failed}
        end
      end)
    end)
    |> Enum.map(&Task.await(&1, 5000))
  end
end
