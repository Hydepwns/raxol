defmodule Raxol.Style.Colors.Persistence do
  @moduledoc """
  Handles persistence of color themes and user preferences.

  This module provides functionality for:
  - Saving and loading themes
  - Managing user preferences
  - Handling theme file storage
  """

  alias Raxol.Style.Colors.Theme, as: Theme
  alias Raxol.Style.Colors.Color

  @themes_dir "themes"
  @preferences_file "preferences.json"

  # Helper to get the configured base directory
  defp config_dir do
    # Default to current dir
    Application.get_env(:raxol, :config_dir, ".")
  end

  @doc """
  Saves a theme to a file.

  ## Parameters

  - `theme` - The theme to save

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def save_theme(theme) do
    # Construct full path using config_dir
    full_themes_dir = Path.join(config_dir(), @themes_dir)
    # Ensure themes directory exists
    File.mkdir_p!(full_themes_dir)

    # Convert theme to JSON
    theme_json = Jason.encode!(theme, pretty: true)

    # Save theme to file
    theme_path = Path.join(full_themes_dir, "#{theme.name}.json")
    File.write(theme_path, theme_json)
  end

  @doc """
  Loads a theme from a file.

  ## Parameters

  - `theme_name` - The name of the theme to load

  ## Returns

  - `{:ok, theme}` on success
  - `{:error, reason}` on failure
  """
  def load_theme(theme_name) do
    theme_path =
      Path.join(Path.join(config_dir(), @themes_dir), "#{theme_name}.json")

    case File.read(theme_path) do
      {:ok, theme_json} ->
        # Decode with atom keys first
        case Jason.decode(theme_json, keys: :atoms!) do
          {:ok, theme_data} ->
            # Manually convert palette maps back to Color structs
            palette_structs =
              Enum.into(theme_data.palette, %{}, fn {key, color_map} ->
                # Assume color_map is %{r: ..., g: ..., b: ..., a: ...}
                {key, struct!(Color, color_map)}
              end)

            # Create final theme struct with processed palette
            {:ok, %{theme_data | palette: palette_structs}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Loads the current theme from user preferences.

  ## Returns

  - `{:ok, theme}` on success
  - `{:error, reason}` on failure
  """
  def load_current_theme do
    case load_user_preferences() do
      {:ok, preferences} ->
        case Map.get(preferences, "theme") do
          nil ->
            {:ok, Theme.standard_theme()}

          theme_name ->
            load_theme(theme_name)
        end

      error ->
        error
    end
  end

  @doc """
  Loads user preferences from file.

  ## Returns

  - `{:ok, preferences}` on success
  - `{:error, reason}` on failure
  """
  def load_user_preferences do
    prefs_path = Path.join(config_dir(), @preferences_file)

    case File.read(prefs_path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, preferences} -> {:ok, preferences}
          error -> error
        end

      {:error, :enoent} ->
        # File doesn't exist, return default preferences
        {:ok, %{"theme" => "Default"}}

      error ->
        error
    end
  end

  @doc """
  Saves user preferences to file.

  ## Parameters

  - `preferences` - The preferences to save

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def save_user_preferences(preferences) do
    prefs_path = Path.join(config_dir(), @preferences_file)

    case Jason.encode(preferences, pretty: true) do
      {:ok, json} -> File.write(prefs_path, json)
      error -> error
    end
  end

  @doc """
  Lists all available themes.

  ## Returns

  - A list of theme names
  """
  def list_themes do
    full_themes_dir = Path.join(config_dir(), @themes_dir)
    # Ensure themes directory exists
    File.mkdir_p!(full_themes_dir)

    # List all theme files
    full_themes_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(&String.replace(&1, ".json", ""))
  end

  @doc """
  Deletes a theme.

  ## Parameters

  - `theme_name` - The name of the theme to delete

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def delete_theme(theme_name) do
    theme_path =
      Path.join(Path.join(config_dir(), @themes_dir), "#{theme_name}.json")

    File.rm(theme_path)
  end
end
