defmodule Raxol.Style.Colors.Persistence do
  @moduledoc """
  Handles persistence of color themes and user preferences.

  This module provides functionality for:
  - Saving and loading themes
  - Managing user preferences
  - Handling theme file storage
  """

  alias Raxol.Style.Colors.Theme

  @themes_dir "themes"
  @preferences_file "preferences.json"

  @doc """
  Saves a theme to a file.

  ## Parameters

  - `theme` - The theme to save

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def save_theme(theme) do
    # Ensure themes directory exists
    File.mkdir_p!(@themes_dir)

    # Convert theme to JSON
    theme_json = Jason.encode!(theme, pretty: true)

    # Save theme to file
    theme_path = Path.join(@themes_dir, "#{theme.name}.json")
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
    theme_path = Path.join(@themes_dir, "#{theme_name}.json")

    case File.read(theme_path) do
      {:ok, theme_json} ->
        case Jason.decode(theme_json) do
          {:ok, theme_data} ->
            {:ok, struct(Theme, theme_data)}

          error ->
            error
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
    case File.read(@preferences_file) do
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
    case Jason.encode(preferences, pretty: true) do
      {:ok, json} -> File.write(@preferences_file, json)
      error -> error
    end
  end

  @doc """
  Lists all available themes.

  ## Returns

  - A list of theme names
  """
  def list_themes do
    # Ensure themes directory exists
    File.mkdir_p!(@themes_dir)

    # List all theme files
    @themes_dir
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
    theme_path = Path.join(@themes_dir, "#{theme_name}.json")
    File.rm(theme_path)
  end
end
