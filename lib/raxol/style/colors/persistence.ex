defmodule Raxol.Style.Colors.Persistence do
  @moduledoc """
  Handles persistence of color themes and user preferences.

  This module provides functionality for:
  - Saving and loading themes
  - Managing user preferences
  - Handling theme file storage
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.UI.Theming.Theme

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
    # Pre-process theme to convert tuple values to lists for JSON encoding
    theme = deep_convert_tuples_to_lists(theme)
    # Construct full path using config_dir
    full_themes_dir = Path.join(config_dir(), @themes_dir)
    # Ensure themes directory exists
    File.mkdir_p!(full_themes_dir)

    # Convert theme to JSON
    theme_json = Jason.encode!(theme, pretty: true)

    # Robustly get the theme name (prefer id over name for filename)
    theme_name =
      cond do
        is_map(theme) and Map.has_key?(theme, :id) -> theme[:id]
        is_map(theme) and Map.has_key?(theme, "id") -> theme["id"]
        is_map(theme) and Map.has_key?(theme, :name) -> theme[:name]
        is_map(theme) and Map.has_key?(theme, "name") -> theme["name"]
        true -> raise "Theme missing id or name key"
      end

    # Save theme to file
    theme_path = Path.join(full_themes_dir, "#{theme_name}.json")
    File.write(theme_path, theme_json)
  end

  # Recursively convert tuple values to lists and all map keys to strings in maps and structs
  defp deep_convert_tuples_to_lists(%_struct{} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} ->
      {to_string_key(k), deep_convert_tuples_to_lists(v)}
    end)
    |> Enum.into(%{})
  end

  defp deep_convert_tuples_to_lists(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {to_string_key(k), deep_convert_tuples_to_lists(v)}
    end)
    |> Enum.into(%{})
  end

  defp deep_convert_tuples_to_lists(list) when is_list(list) do
    Enum.map(list, &deep_convert_tuples_to_lists/1)
  end

  defp deep_convert_tuples_to_lists(tuple) when is_tuple(tuple) do
    Tuple.to_list(tuple)
  end

  defp deep_convert_tuples_to_lists(val), do: val

  defp to_string_key(k) when is_tuple(k),
    do: Enum.map_join(Tuple.to_list(k), ":", &to_string/1)

  defp to_string_key(k) when is_atom(k), do: Atom.to_string(k)
  defp to_string_key(k), do: to_string(k)

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

    with {:ok, theme_json} <- File.read(theme_path),
         {:ok, theme_map} <- Jason.decode(theme_json) do
      theme_struct = map_to_theme_struct(theme_map)

      {:ok, theme_struct}
    else
      {:error, :enoent} -> {:error, :enoent}
      {:error, reason} -> {:error, reason}
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
        theme_name = Map.get(preferences, "theme", "Default")

        case load_theme(theme_name) do
          {:ok, theme} -> {:ok, theme}
          {:error, _reason} -> {:ok, Theme.default_theme()}
        end

      {:error, _reason} ->
        {:ok, Theme.default_theme()}
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

  # --- Conversion helpers ---
  # Convert a loaded map (with string keys and list keys for variants) back to a Theme struct
  def map_to_theme_struct(%_struct{} = struct) do
    struct
    |> Map.from_struct()
    |> map_to_theme_struct()
  end

  def map_to_theme_struct(map) when is_map(map) do
    # Deeply atomize all keys before normalization
    atomized_map = deep_atomize_keys(map)

    attrs =
      atomized_map
      |> Enum.map(fn {k, v} -> {to_atom_key(k), v} end)
      |> Enum.into(%{})
      |> Map.update(:colors, %{}, &normalize_colors/1)
      |> Map.put_new(:variants, %{})
      |> Map.update(:variants, %{}, &normalize_variants/1)
      |> Map.update(:ui_mappings, %{}, &normalize_ui_mappings/1)

    Raxol.UI.Theming.Theme.new(attrs)
  end

  def map_to_theme_struct(other), do: other

  defp to_atom_key(k) when is_binary(k), do: String.to_atom(k)
  defp to_atom_key(k), do: k

  # Helper to normalize color values in both colors and variants
  defp normalize_color_value(v) do
    cond do
      is_map(v) and Map.has_key?(v, :hex) -> Color.from_hex(v["hex"] || v.hex)
      is_map(v) and Map.has_key?(v, "hex") -> Color.from_hex(v["hex"])
      is_binary(v) and String.starts_with?(v, "#") -> Color.from_hex(v)
      is_struct(v, Color) -> v
      true -> v
    end
  end

  # Convert color keys to atoms and values to hex or Color structs
  defp normalize_colors(colors) when is_map(colors) do
    result =
      Enum.into(colors, %{}, fn {k, v} ->
        key = if is_binary(k), do: String.to_atom(k), else: k
        value = normalize_color_value(v)
        {key, value}
      end)

    result
  end

  defp normalize_colors(other), do: other

  # Convert variant keys like "primary:high_contrast" or ["primary", "high_contrast"] to tuples
  defp normalize_variants(variants) when is_map(variants) do
    result =
      Enum.into(variants, %{}, fn {k, v} ->
        {normalize_variant_key(k), normalize_color_value(v)}
      end)

    result
  end

  defp normalize_variants(other), do: other

  defp normalize_variant_key(k) when is_binary(k) do
    if String.contains?(k, ":") do
      k |> String.split(":") |> Enum.map(&String.to_atom/1) |> List.to_tuple()
    else
      String.to_atom(k)
    end
  end

  defp normalize_variant_key(k) when is_list(k),
    do: Enum.map(k, &to_atom_key/1) |> List.to_tuple()

  defp normalize_variant_key(k) when is_atom(k), do: k
  defp normalize_variant_key(k), do: k

  # Convert ui_mappings keys and values to atoms
  defp normalize_ui_mappings(mappings) when is_map(mappings) do
    Enum.into(mappings, %{}, fn {k, v} ->
      {to_atom_key(k), if(is_binary(v), do: String.to_atom(v), else: v)}
    end)
  end

  defp normalize_ui_mappings(other), do: other

  # Recursively convert all string keys in a map to atoms
  defp deep_atomize_keys(%{} = map) do
    map
    |> Enum.map(fn {k, v} ->
      {if(is_binary(k), do: String.to_atom(k), else: k), deep_atomize_keys(v)}
    end)
    |> Enum.into(%{})
  end

  defp deep_atomize_keys([head | tail]),
    do: [deep_atomize_keys(head) | deep_atomize_keys(tail)]

  defp deep_atomize_keys([]), do: []
  defp deep_atomize_keys(other), do: other
end
