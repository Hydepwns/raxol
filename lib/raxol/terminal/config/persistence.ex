defmodule Raxol.Terminal.Config.Persistence do
  @moduledoc '''
  Handles persistence and migration of terminal configurations.
  '''

  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.Validator

  @doc '''
  Saves a configuration to persistent storage.
  '''
  @spec save_config(Config.t(), String.t()) :: :ok | {:error, term()}
  def save_config(config, name) do
    with :ok <- Validator.validate_config(config) do
      storage_path = get_storage_path(name)

      case File.write(storage_path, :erlang.term_to_binary(config)) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc '''
  Loads a configuration from persistent storage.
  '''
  @spec load_config(String.t()) :: {:ok, Config.t()} | {:error, term()}
  def load_config(name) do
    storage_path = get_storage_path(name)

    case File.read(storage_path) do
      {:ok, binary} ->
        try do
          config = :erlang.binary_to_term(binary)

          with :ok <- Validator.validate_config(config) do
            {:ok, config}
          end
        rescue
          _ -> {:error, :invalid_config_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc '''
  Lists all saved configurations.
  '''
  @spec list_configs() :: {:ok, [String.t()]} | {:error, term()}
  def list_configs do
    storage_dir = get_storage_dir()

    case File.ls(storage_dir) do
      {:ok, files} ->
        configs =
          files
          |> Enum.filter(&String.ends_with?(&1, ".config"))
          |> Enum.map(&String.replace(&1, ".config", ""))

        {:ok, configs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc '''
  Migrates a configuration to the latest version.
  '''
  @spec migrate_config(Config.t()) :: {:ok, Config.t()} | {:error, term()}
  def migrate_config(config) do
    # Get current version
    current_version = get_config_version(config)

    # Apply migrations if needed
    with :ok <- validate_version(current_version),
         {:ok, migrated_config} <- apply_migrations(config, current_version) do
      {:ok, migrated_config}
    end
  end

  # Private functions

  defp get_storage_dir do
    base_dir = Application.get_env(:raxol, :config_storage_dir, "tmp/configs")
    File.mkdir_p!(base_dir)
    base_dir
  end

  defp get_storage_path(name) do
    Path.join(get_storage_dir(), "#{name}.config")
  end

  defp get_config_version(%Config{} = config) do
    Map.get(config, :version, 1)
  end

  defp validate_version(version) when is_integer(version) and version > 0,
    do: :ok

  defp validate_version(_), do: {:error, :invalid_version}

  defp apply_migrations(config, current_version) do
    latest_version = Application.get_env(:raxol, :config_version, 1)

    if current_version < latest_version do
      # Apply migrations in sequence
      Enum.reduce_while(
        current_version..(latest_version - 1),
        {:ok, config},
        fn version, {:ok, current_config} ->
          case apply_migration(current_config, version) do
            {:ok, migrated_config} -> {:cont, {:ok, migrated_config}}
            error -> {:halt, error}
          end
        end
      )
    else
      {:ok, config}
    end
  end

  defp apply_migration(config, version) do
    # Apply specific migration based on version
    case version do
      1 -> migrate_v1_to_v2(config)
      2 -> migrate_v2_to_v3(config)
      _ -> {:error, :unsupported_migration}
    end
  end

  # Migration functions
  defp migrate_v1_to_v2(config) do
    # Example migration: Add new fields with default values
    migrated_config = %{
      config
      | version: 2,
        performance: Map.put_new(config.performance, :render_buffer_size, 1024)
    }

    {:ok, migrated_config}
  end

  defp migrate_v2_to_v3(config) do
    # Example migration: Restructure existing fields
    migrated_config = %{
      config
      | version: 3,
        input: Map.put_new(config.input, :keyboard_layout, :us)
    }

    {:ok, migrated_config}
  end
end
