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
        # Decode with default string keys
        case Jason.decode(theme_json) do
          {:ok, theme_data_map} ->
            # Process palette: Keep string keys, convert values to Color structs (handling hex)
            processed_palette =
              case Map.get(theme_data_map, "palette") do
                nil ->
                  %{}

                palette_map when is_map(palette_map) ->
                  Enum.into(palette_map, %{}, fn {key_str, color_value} ->
                    # Keep key as string
                    color_struct =
                      case color_value do
                        map when is_map(map) ->
                          # Convert inner map keys for struct! call if needed, but key_str remains outer key
                          atom_keyed_color_map =
                            Enum.into(map, %{}, fn {k, v} ->
                              {String.to_atom(k), v}
                            end)

                          struct!(Color, atom_keyed_color_map)

                        hex when is_binary(hex) ->
                          Color.from_hex(hex)

                        _ ->
                          nil
                      end

                    # Use string key
                    {key_str, color_struct}
                  end)
                  |> Enum.reject(fn {_k, v} -> is_nil(v) end)
                  |> Map.new()

                # Handle unexpected palette type
                _ ->
                  %{}
              end

            # Convert top-level string keys to atoms
            theme_data_atoms =
              Enum.into(theme_data_map, %{}, fn {k, v} ->
                {String.to_atom(k), v}
              end)

            # Get ui_mappings (should have atom keys from theme_data_atoms conversion, keep string values)
            processed_ui_mappings = Map.get(theme_data_atoms, :ui_mappings, %{})

            # Create final theme struct data, ensuring correct map structures
            final_theme_data =
              theme_data_atoms
              |> Map.put(:palette, processed_palette)
              |> Map.put(:ui_mappings, processed_ui_mappings)

            {:ok, struct!(Theme, final_theme_data)}

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
        # Decode with default string keys
        case Jason.decode(json) do
          {:ok, preferences} -> {:ok, preferences}
          # Propagate decoding errors
          error -> error
        end

      {:error, :enoent} ->
        # File doesn't exist, return default preferences (use string key)
        {:ok, %{"theme" => "Default"}}

      error ->
        # Propagate other file read errors
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
