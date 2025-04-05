defmodule Raxol.Style.Colors.Persistence do
  @moduledoc """
  Handles persistence of color schemes, themes, and user preferences.
  
  This module provides functionality to save and load color-related settings,
  including themes, palettes, and user preferences. It supports both file-based
  and database storage options.
  """
  
  alias Raxol.Style.Colors.{Theme, Palette}
  
  @doc """
  Saves a theme to a file.
  
  ## Parameters
  
  - `theme` - The theme to save
  - `path` - The file path to save to (default: user's config directory)
  
  ## Examples
  
      iex> theme = Theme.from_palette(Palette.nord())
      iex> Persistence.save_theme(theme)
      {:ok, "/path/to/saved/theme.json"}
  """
  def save_theme(%Theme{} = theme, path \\ nil) do
    path = path || default_theme_path()
    
    # Convert theme to JSON-serializable format
    theme_data = %{
      name: theme.name,
      palette: %{
        name: theme.palette.name,
        colors: Map.new(theme.palette.colors, fn {k, v} -> {k, v.hex} end),
        primary: theme.palette.primary,
        secondary: theme.palette.secondary,
        accent: theme.palette.accent,
        background: theme.palette.background,
        foreground: theme.palette.foreground
      },
      ui_mappings: theme.ui_mappings,
      dark_mode: theme.dark_mode,
      high_contrast: theme.high_contrast
    }
    
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(path))
    
    # Write to file
    case File.write(path, Jason.encode!(theme_data, pretty: true)) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Loads a theme from a file.
  
  ## Parameters
  
  - `path` - The file path to load from (default: user's config directory)
  
  ## Examples
  
      iex> {:ok, theme} = Persistence.load_theme()
      iex> theme.name
      "Nord"
  """
  def load_theme(path \\ nil) do
    path = path || default_theme_path()
    
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Reconstruct the theme from the loaded data
            palette = %Palette{
              name: data["palette"]["name"],
              colors: Map.new(data["palette"]["colors"], fn {k, v} -> 
                {String.to_existing_atom(k), Raxol.Style.Colors.Color.from_hex(v)}
              end),
              primary: String.to_existing_atom(data["palette"]["primary"]),
              secondary: String.to_existing_atom(data["palette"]["secondary"]),
              accent: String.to_existing_atom(data["palette"]["accent"]),
              background: String.to_existing_atom(data["palette"]["background"]),
              foreground: String.to_existing_atom(data["palette"]["foreground"])
            }
            
            theme = %Theme{
              name: data["name"],
              palette: palette,
              ui_mappings: Map.new(data["ui_mappings"], fn {k, v} -> 
                {String.to_existing_atom(k), String.to_existing_atom(v)}
              end),
              dark_mode: data["dark_mode"],
              high_contrast: data["high_contrast"]
            }
            
            {:ok, theme}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, :enoent} ->
        {:error, :theme_not_found}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Saves user color preferences.
  
  ## Parameters
  
  - `user_id` - The user's identifier
  - `preferences` - Map of color preferences
  
  ## Examples
  
      iex> preferences = %{
      ...>   theme: "nord",
      ...>   high_contrast: true,
      ...>   font_size: 14
      ...> }
      iex> Persistence.save_user_preferences("user123", preferences)
      :ok
  """
  def save_user_preferences(user_id, preferences) do
    path = user_preferences_path(user_id)
    
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(path))
    
    # Write to file
    case File.write(path, Jason.encode!(preferences, pretty: true)) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Loads user color preferences.
  
  ## Parameters
  
  - `user_id` - The user's identifier
  
  ## Examples
  
      iex> {:ok, preferences} = Persistence.load_user_preferences("user123")
      iex> preferences.theme
      "nord"
  """
  def load_user_preferences(user_id) do
    path = user_preferences_path(user_id)
    
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, reason}
        end
        
      {:error, :enoent} ->
        {:ok, %{}}  # Return empty preferences if file doesn't exist
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Gets the default path for theme storage.
  
  ## Examples
  
      iex> Persistence.default_theme_path()
      "/path/to/config/themes/current.json"
  """
  def default_theme_path do
    Path.join([config_dir(), "themes", "current.json"])
  end
  
  @doc """
  Gets the path for user preferences storage.
  
  ## Parameters
  
  - `user_id` - The user's identifier
  
  ## Examples
  
      iex> Persistence.user_preferences_path("user123")
      "/path/to/config/users/user123/preferences.json"
  """
  def user_preferences_path(user_id) do
    Path.join([config_dir(), "users", user_id, "preferences.json"])
  end
  
  # Private functions
  
  defp config_dir do
    case :os.type() do
      {:unix, :darwin} ->  # macOS
        Path.expand("~/Library/Application Support/Raxol")
      {:unix, _} ->  # Linux/BSD
        Path.expand("~/.config/raxol")
      {:win32, _} ->  # Windows
        Path.expand("~/AppData/Roaming/Raxol")
      _ ->
        Path.expand("~/.raxol")
    end
  end
end 