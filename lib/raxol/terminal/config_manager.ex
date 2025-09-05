defmodule Raxol.Terminal.ConfigManager do
  @moduledoc """
  Manages terminal configuration including behavior settings, memory limits, and rendering options.
  This module is responsible for loading, validating, and applying configuration changes.
  """

  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log

  @doc """
  Gets a specific configuration value.
  Returns the configuration value or nil if not found.
  """
  @spec get_config_value(Emulator.t(), list()) :: any()
  def get_config_value(emulator, path) do
    get_in(emulator.config, path)
  end

  @doc """
  Sets a specific configuration value.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_config_value(Emulator.t(), list(), any()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_config_value(emulator, path, value) do
    updated_config = put_in(emulator.config, path, value)

    case validate_config(updated_config) do
      :ok ->
        emulator = apply_config_changes(emulator, updated_config)
        {:ok, emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates the buffer manager configuration.
  Returns the updated emulator.
  """
  @spec update_buffer_config(Emulator.t(), map()) :: Emulator.t()
  def update_buffer_config(emulator, config) do
    %{
      emulator
      | scrollback_limit: config.behavior.scrollback_limit,
        memory_limit: config.memory_limit
    }
  end

  @doc """
  Updates the renderer configuration.
  Returns the updated emulator.
  """
  @spec update_renderer_config(Emulator.t(), map()) :: Emulator.t()
  def update_renderer_config(emulator, config) do
    %{emulator | renderer_config: config.rendering}
  end

  @doc """
  Validates the configuration.
  Returns :ok or {:error, reason}.
  """
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    with :ok <- validate_behavior(config.behavior),
         :ok <- validate_memory_limit(config.memory_limit),
         :ok <- validate_rendering(config.rendering) do
      :ok
    end
  end

  @doc """
  Applies configuration changes to the terminal state.
  Returns the updated emulator.
  """
  @spec apply_config_changes(Emulator.t(), map()) :: Emulator.t()
  def apply_config_changes(emulator, changes) do
    emulator
    |> update_buffer_config(changes)
    |> update_renderer_config(changes)
    |> Map.merge(changes)
  end

  @doc """
  Gets the emulator configuration.
  Returns the emulator configuration map.
  """
  @spec get_emulator_config(Emulator.t()) :: map()
  def get_emulator_config(emulator) do
    Raxol.Terminal.Emulator.get_config_struct(emulator)
  end

  # Private Functions

  defp validate_behavior(behavior) when not is_map(behavior) do
    {:error, "Behavior must be a map"}
  end

  defp validate_behavior(%{scrollback_limit: limit})
       when not is_integer(limit) or limit < 0 do
    {:error, "Invalid scrollback limit"}
  end

  defp validate_behavior(_behavior), do: :ok

  defp validate_memory_limit(limit) do
    if is_integer(limit) and limit >= 0 do
      :ok
    else
      {:error, "Invalid memory limit"}
    end
  end

  defp validate_rendering(rendering) when not is_map(rendering) do
    {:error, "Rendering must be a map"}
  end

  defp validate_rendering(%{antialiasing: antialiasing})
       when not is_boolean(antialiasing) do
    {:error, "Antialiasing must be a boolean"}
  end

  defp validate_rendering(%{font_size: font_size})
       when not is_integer(font_size) or font_size < 1 do
    {:error, "Invalid font size"}
  end

  defp validate_rendering(_rendering), do: :ok
end
