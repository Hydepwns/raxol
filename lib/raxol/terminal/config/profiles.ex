defmodule Raxol.Terminal.Config.Profiles do
  @moduledoc """
  Terminal configuration profile management.

  Allows users to define, save, load, and switch between different
  terminal configuration profiles.
  """

  alias Raxol.Terminal.Config.{Persistence, Validation, Defaults}

  @profiles_dir "priv/config/profiles"
  @profile_ext ".json"

  @doc """
  Lists all available terminal configuration profiles.

  ## Returns

  A list of profile names.
  """
  def list_profiles do
    # Create profiles directory if it doesn't exist
    File.mkdir_p(@profiles_dir)

    # Find all JSON files in the profiles directory
    @profiles_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, @profile_ext))
    |> Enum.map(&String.replace(&1, @profile_ext, ""))
  end

  @doc """
  Loads a specific terminal configuration profile.

  ## Parameters

  * `name` - The name of the profile to load

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def load_profile(name) do
    path = profile_path(name)

    case File.exists?(path) do
      true -> Persistence.load_config(path)
      false -> {:error, "Profile #{name} not found"}
    end
  end

  @doc """
  Saves the current configuration as a profile.

  ## Parameters

  * `name` - The name of the profile to save
  * `config` - The configuration to save

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def save_profile(name, config) do
    # Create profiles directory if it doesn't exist
    File.mkdir_p(@profiles_dir)

    # Validate profile name
    case validate_profile_name(name) do
      :ok ->
        # Save the config to the profile file
        path = profile_path(name)
        Persistence.save_config(config, path)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a terminal configuration profile.

  ## Parameters

  * `name` - The name of the profile to delete

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def delete_profile(name) do
    path = profile_path(name)

    case File.exists?(path) do
      true -> File.rm(path)
      false -> {:error, "Profile #{name} not found"}
    end
  end

  @doc """
  Creates a new profile with default settings.

  ## Parameters

  * `name` - The name of the new profile

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def create_default_profile(name) do
    config = Defaults.generate_default_config()

    case save_profile(name, config) do
      :ok -> {:ok, config}
      error -> error
    end
  end

  @doc """
  Updates an existing profile with new settings.

  ## Parameters

  * `name` - The name of the profile to update
  * `config` - The new configuration

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def update_profile(name, config) do
    path = profile_path(name)

    case File.exists?(path) do
      true ->
        case Validation.validate_config(config) do
          {:ok, validated_config} -> save_profile(name, validated_config)
          error -> error
        end

      false ->
        {:error, "Profile #{name} not found"}
    end
  end

  @doc """
  Duplicates an existing profile with a new name.

  ## Parameters

  * `source_name` - The name of the profile to duplicate
  * `target_name` - The name for the new profile

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def duplicate_profile(source_name, target_name) do
    case load_profile(source_name) do
      {:ok, config} ->
        case save_profile(target_name, config) do
          :ok -> {:ok, config}
          error -> error
        end

      error ->
        error
    end
  end

  # Private functions

  defp profile_path(name) do
    Path.join(@profiles_dir, "#{name}#{@profile_ext}")
  end

  defp validate_profile_name(name)
       when is_binary(name) and byte_size(name) < 1 do
    {:error, "Profile name can't be empty"}
  end

  defp validate_profile_name(name)
       when is_binary(name) and byte_size(name) > 64 do
    {:error, "Profile name too long (maximum 64 characters)"}
  end

  defp validate_profile_name(name) when is_binary(name) do
    case String.match?(name, ~r/^[a-zA-Z0-9_\-. ]+$/) do
      true ->
        :ok

      false ->
        {:error,
         "Profile name contains invalid characters (allowed: letters, numbers, spaces, underscores, hyphens, periods)"}
    end
  end

  defp validate_profile_name(_) do
    {:error, "Profile name must be a string"}
  end

  # Define types locally or import/alias if needed
  # Example types (adjust based on actual usage):
  @type terminal_type ::
          :iterm2
          | :windows_terminal
          | :xterm
          | :screen
          | :kitty
          | :alacritty
          | :konsole
          | :gnome_terminal
          | :vscode
          | :unknown
  @type color_mode :: :basic | :true_color | :palette
  @type theme_map :: %{atom() => String.t()}
  @type background_type :: :solid | :transparent | :image | :animated
  @type animation_type :: :gif | :video | :shader | :particle
  # Assuming a generic map for now
  @type config :: map()
end
