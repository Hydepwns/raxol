defmodule Raxol.Core.Preferences.Persistence do
  @moduledoc """
  Handles persistence (loading/saving) of user preferences to a file.
  """
  require Raxol.Core.Runtime.Log

  @default_filename "user_preferences.bin"

  @doc """
  Returns the full path to the user preferences file.
  Uses an application-specific directory.
  """
  def preferences_path do
    # Using :user_config dir for user-specific, potentially hidden config
    config_dir = :filename.basedir(:user_config, "raxol")
    # Ensure the directory exists
    File.mkdir_p!(config_dir)
    Path.join(config_dir, @default_filename)
  end

  @doc """
  Loads user preferences from the designated file.

  Returns:
    - `{:ok, preferences_map}` if successful.
    - `{:error, :file_not_found}` if the file doesn't exist.
    - `{:error, reason}` for other file or decoding errors.
  """
  def load do
    path = preferences_path()

    case File.read(path) do
      {:ok, binary_data} ->
        try do
          preferences = :erlang.binary_to_term(binary_data, [:safe])

          if is_map(preferences) do
            {:ok, preferences}
          else
            Raxol.Core.Runtime.Log.error(
              "Preferences file content is not a map: #{path}"
            )

            {:error, :invalid_format}
          end
        rescue
          # Catches errors during binary_to_term (e.g., corrupt data)
          error ->
            Raxol.Core.Runtime.Log.error(
              "Failed to decode preferences file #{path}: #{inspect(error)}"
            )

            {:error, :decoding_failed}
        end

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to read preferences file #{path}: #{reason}"
        )

        {:error, reason}
    end
  end

  @doc """
  Saves the given preferences map to the designated file.

  Serializes the map using `:erlang.term_to_binary`.

  Returns:
    - `:ok` on success.
    - `{:error, reason}` on failure.
  """
  def save(preferences) when is_map(preferences) do
    path = preferences_path()

    try do
      binary_data = :erlang.term_to_binary(preferences)
      File.write(path, binary_data)
    rescue
      error ->
        Raxol.Core.Runtime.Log.error(
          "Failed to encode preferences for saving: #{inspect(error)}"
        )

        {:error, :encoding_failed}
    catch
      :exit, reason ->
        Raxol.Core.Runtime.Log.error(
          "Failed to write preferences file #{path}: #{inspect(reason)}"
        )

        {:error, :write_failed}
    end
  end
end
