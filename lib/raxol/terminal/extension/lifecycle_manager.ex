defmodule Raxol.Terminal.Extension.LifecycleManager do
  @moduledoc """
  Handles extension lifecycle operations including loading, unloading, activating, and deactivating extensions.
  """

  require Logger

  @doc """
  Loads an extension from a file or directory.
  """
  def load_extension(path, type, opts, state) do
    Logger.info("Loading extension from path: #{path}, type: #{type}")

    extension_id = generate_extension_id()

    extension_state =
      Raxol.Terminal.Extension.StateManager.load_extension_state(
        path,
        type,
        opts
      )

    case extension_state.module do
      {:error, reason} ->
        {:error, {:module_load_failed, reason}}

      _ ->
        case Raxol.Terminal.Extension.Validator.validate_extension(
               extension_state
             ) do
          :ok ->
            new_state = put_in(state.extensions[extension_id], extension_state)
            {:ok, extension_id, new_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Unloads an extension by its ID.
  """
  def unload_extension(extension_id, state) do
    Logger.info("Unloading extension: #{extension_id}")

    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        # Clean up extension resources
        cleanup_extension(extension)
        new_state = update_in(state.extensions, &Map.delete(&1, extension_id))
        {:ok, new_state}
    end
  end

  @doc """
  Activates an extension.
  """
  def activate_extension(extension_id, state) do
    Logger.info("Activating extension: #{extension_id}")

    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        handle_extension_activation(extension, extension_id, state)
    end
  end

  @doc """
  Deactivates an extension.
  """
  def deactivate_extension(extension_id, state) do
    Logger.info("Deactivating extension: #{extension_id}")

    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        handle_extension_deactivation(extension, extension_id, state)
    end
  end

  # Private functions

  defp generate_extension_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> binary_part(0, 8)
  end

  defp handle_extension_activation(extension, extension_id, state) do
    if extension.status == :idle do
      case initialize_extension(extension) do
        {:ok, initialized_extension} ->
          new_extension = %{initialized_extension | status: :active}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:ok, new_state}

        {:error, reason} ->
          new_extension = %{extension | status: :error, error: reason}
          _new_state = put_in(state.extensions[extension_id], new_extension)
          {:error, reason}
      end
    else
      {:error, :invalid_extension_state}
    end
  end

  defp handle_extension_deactivation(extension, extension_id, state) do
    if extension.status == :active do
      case deinitialize_extension(extension) do
        {:ok, deinitialized_extension} ->
          new_extension = %{deinitialized_extension | status: :idle}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:ok, new_state}

        {:error, reason} ->
          new_extension = %{extension | status: :error, error: reason}
          _new_state = put_in(state.extensions[extension_id], new_extension)
          {:error, reason}
      end
    else
      {:error, :invalid_extension_state}
    end
  end

  defp initialize_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :init, 0) do
            module.init()
          end

          {:ok, extension}
        rescue
          e ->
            Logger.error("Extension initialization failed: #{inspect(e)}")
            {:error, :initialization_failed}
        end

      _ ->
        {:ok, extension}
    end
  end

  defp deinitialize_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :cleanup, 0) do
            module.cleanup()
          end

          {:ok, extension}
        rescue
          e ->
            Logger.error("Extension cleanup failed: #{inspect(e)}")
            {:error, :cleanup_failed}
        end

      _ ->
        {:ok, extension}
    end
  end

  defp cleanup_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :cleanup, 0) do
            module.cleanup()
          end
        rescue
          e ->
            Logger.error("Extension cleanup failed: #{inspect(e)}")
        end

      _ ->
        :ok
    end
  end
end
