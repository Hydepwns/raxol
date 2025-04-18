defmodule Raxol.ThemeConfig do
  @moduledoc """
  Theme configuration system for Raxol.

  This module provides functionality for loading, saving, and applying themes.
  Themes can be managed by users through a configuration interface or programmatically.

  ## Usage

  ```elixir
  # Get available themes
  themes = Raxol.ThemeConfig.list_themes()

  # Get current theme
  current = Raxol.ThemeConfig.get_current_theme()

  # Apply a theme
  Raxol.ThemeConfig.apply_theme("dark")

  # Create a custom theme
  custom_theme = %{
    "name" => "My Custom Theme",
    "colors" => %{
      "primary" => "#336699",
      "secondary" => "#996633",
      # Other colors...
    },
    # Other theme properties...
  }
  Raxol.ThemeConfig.save_theme(custom_theme)
  ```
  """

  alias Raxol.Style.Theme

  @themes_dir "themes"
  @default_theme "Default"
  @process_key :raxol_current_theme

  @theme_properties [
    "name",
    "colors",
    "typography",
    "spacing",
    "borders",
    "shadows",
    "high_contrast"
  ]

  @doc """
  Lists all available themes.

  Returns a list of theme names.
  """
  @spec list_themes() :: [String.t()]
  def list_themes do
    # Combine built-in and custom themes
    built_in = ["Default", "Dark", "High Contrast"]

    custom =
      case File.ls(themes_dir()) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(&String.replace(&1, ".json", ""))

        {:error, _} ->
          []
      end

    (built_in ++ custom)
    |> Enum.uniq()
  end

  @doc """
  Gets the current theme.

  Returns the current theme configuration.
  """
  @spec get_current_theme() :: map()
  def get_current_theme do
    Process.get(@process_key, load_theme(@default_theme))
  end

  @doc """
  Gets a theme by name.

  ## Parameters

  - `name` - The name of the theme to get

  ## Returns

  The theme configuration or an error tuple if not found.
  """
  @spec get_theme(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_theme(name) do
    case load_theme(name) do
      nil -> {:error, "Theme not found"}
      theme -> {:ok, theme}
    end
  end

  @doc """
  Applies a theme by name.

  ## Parameters

  - `name` - The name of the theme to apply

  ## Returns

  `:ok` if the theme was applied successfully, or an error tuple if not found.
  """
  @spec apply_theme(String.t()) :: :ok | {:error, String.t()}
  def apply_theme(name) do
    case get_theme(name) do
      {:ok, theme} ->
        Process.put(@process_key, theme)
        :ok

      error ->
        error
    end
  end

  @doc """
  Saves a custom theme.

  ## Parameters

  - `theme` - The theme configuration to save

  ## Returns

  `:ok` if the theme was saved successfully, or an error tuple.
  """
  @spec save_theme(map()) :: :ok | {:error, String.t()}
  def save_theme(theme) do
    with {:ok, validated} <- validate_theme(theme),
         :ok <- ensure_themes_dir(),
         {:ok, json} <- Jason.encode(validated, pretty: true) do
      file_name = get_theme_filename(validated["name"])
      File.write(file_name, json)
    else
      {:error, reason} -> {:error, "Failed to save theme: #{inspect(reason)}"}
      _ -> {:error, "Unknown error while saving theme"}
    end
  end

  @doc """
  Creates a theme with the specified options.

  ## Parameters

  - `opts` - Theme options

  ## Returns

  A new theme configuration map.
  """
  @spec create_theme(keyword()) :: map()
  def create_theme(opts \\ []) do
    name = Keyword.get(opts, :name, "Custom Theme")
    colors = Keyword.get(opts, :colors, %{})
    typography = Keyword.get(opts, :typography, %{})
    spacing = Keyword.get(opts, :spacing, %{})
    borders = Keyword.get(opts, :borders, %{})
    shadows = Keyword.get(opts, :shadows, %{})
    high_contrast = Keyword.get(opts, :high_contrast, false)

    # Get base theme
    {:ok, base_theme} = get_theme(@default_theme)

    # Create new theme with merged options
    %{
      "name" => name,
      "colors" =>
        Map.merge(base_theme["colors"] || %{}, stringify_keys(colors)),
      "typography" =>
        Map.merge(base_theme["typography"] || %{}, stringify_keys(typography)),
      "spacing" =>
        Map.merge(base_theme["spacing"] || %{}, stringify_keys(spacing)),
      "borders" =>
        Map.merge(base_theme["borders"] || %{}, stringify_keys(borders)),
      "shadows" =>
        Map.merge(base_theme["shadows"] || %{}, stringify_keys(shadows)),
      "high_contrast" => high_contrast
    }
  end

  @doc """
  Deletes a custom theme.

  ## Parameters

  - `name` - The name of the theme to delete

  ## Returns

  `:ok` if the theme was deleted successfully, or an error tuple.
  """
  @spec delete_theme(String.t()) :: :ok | {:error, String.t()}
  def delete_theme(name) do
    # Can't delete built-in themes
    if name in ["Default", "Dark", "High Contrast"] do
      {:error, "Cannot delete built-in theme"}
    else
      file_name = get_theme_filename(name)

      case File.rm(file_name) do
        :ok ->
          :ok

        {:error, reason} ->
          {:error, "Failed to delete theme: #{inspect(reason)}"}
      end
    end
  end

  # Private functions

  # Loads a theme from file or built-in
  defp load_theme(name) do
    # Try to load from file first
    case load_from_file(name) do
      {:ok, theme} ->
        theme

      _ ->
        # Fall back to built-in themes
        case name do
          "Default" -> load_default_theme()
          "Dark" -> load_dark_theme()
          "High Contrast" -> load_high_contrast_theme()
          _ -> nil
        end
    end
  end

  # Loads a theme from file
  defp load_from_file(name) do
    file_name = get_theme_filename(name)

    if File.exists?(file_name) do
      case File.read(file_name) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, theme} -> {:ok, theme}
            error -> error
          end

        error ->
          error
      end
    else
      {:error, :not_found}
    end
  end

  # Gets the theme filename
  defp get_theme_filename(name) do
    Path.join(themes_dir(), "#{name}.json")
  end

  # Gets the themes directory
  defp themes_dir do
    Path.join(:code.priv_dir(:raxol), @themes_dir)
  end

  # Ensures the themes directory exists
  defp ensure_themes_dir do
    dir = themes_dir()

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Validates a theme configuration
  defp validate_theme(theme) do
    cond do
      not is_map(theme) ->
        {:error, "Theme must be a map"}

      not Map.has_key?(theme, "name") or not is_binary(theme["name"]) ->
        {:error, "Theme must have a valid name"}

      not Map.has_key?(theme, "colors") or not is_map(theme["colors"]) ->
        {:error, "Theme must have a valid colors map"}

      true ->
        # Filter only allowed properties
        validated =
          theme
          |> Map.take(@theme_properties)
          |> ensure_required_properties()

        {:ok, validated}
    end
  end

  # Ensures required properties exist in the theme
  defp ensure_required_properties(theme) do
    # Set defaults for missing properties
    default = load_default_theme()

    @theme_properties
    |> Enum.reduce(theme, fn prop, acc ->
      if Map.has_key?(acc, prop) do
        acc
      else
        Map.put(acc, prop, Map.get(default, prop))
      end
    end)
  end

  # Loads the default theme
  defp load_default_theme do
    %{
      "name" => "Default",
      "colors" => %{
        "primary" => "#1976d2",
        "secondary" => "#424242",
        "background" => "#ffffff",
        "text" => "#212121",
        "border" => "#e0e0e0",
        "success" => "#4caf50",
        "warning" => "#ff9800",
        "error" => "#f44336",
        "info" => "#2196f3"
      },
      "typography" => %{
        "fontFamily" =>
          "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
        "fontSize" => %{
          "small" => "12px",
          "medium" => "14px",
          "large" => "16px",
          "xlarge" => "20px"
        },
        "fontWeight" => %{
          "light" => 300,
          "regular" => 400,
          "medium" => 500,
          "bold" => 700
        }
      },
      "spacing" => %{
        "xs" => "4px",
        "sm" => "8px",
        "md" => "16px",
        "lg" => "24px",
        "xl" => "32px"
      },
      "borders" => %{
        "radius" => %{
          "small" => "4px",
          "medium" => "8px",
          "large" => "12px"
        },
        "width" => %{
          "thin" => "1px",
          "regular" => "2px",
          "thick" => "4px"
        }
      },
      "shadows" => %{
        "small" => "0 2px 4px rgba(0, 0, 0, 0.1)",
        "medium" => "0 4px 8px rgba(0, 0, 0, 0.1)",
        "large" => "0 8px 16px rgba(0, 0, 0, 0.1)"
      },
      "high_contrast" => false
    }
  end

  # Loads the dark theme
  defp load_dark_theme do
    %{
      "name" => "Dark",
      "colors" => %{
        "primary" => "#90caf9",
        "secondary" => "#b0bec5",
        "background" => "#121212",
        "text" => "#ffffff",
        "border" => "#424242",
        "success" => "#81c784",
        "warning" => "#ffb74d",
        "error" => "#e57373",
        "info" => "#64b5f6"
      },
      "typography" => %{
        "fontFamily" =>
          "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
        "fontSize" => %{
          "small" => "12px",
          "medium" => "14px",
          "large" => "16px",
          "xlarge" => "20px"
        },
        "fontWeight" => %{
          "light" => 300,
          "regular" => 400,
          "medium" => 500,
          "bold" => 700
        }
      },
      "spacing" => %{
        "xs" => "4px",
        "sm" => "8px",
        "md" => "16px",
        "lg" => "24px",
        "xl" => "32px"
      },
      "borders" => %{
        "radius" => %{
          "small" => "4px",
          "medium" => "8px",
          "large" => "12px"
        },
        "width" => %{
          "thin" => "1px",
          "regular" => "2px",
          "thick" => "4px"
        }
      },
      "shadows" => %{
        "small" => "0 2px 4px rgba(0, 0, 0, 0.3)",
        "medium" => "0 4px 8px rgba(0, 0, 0, 0.3)",
        "large" => "0 8px 16px rgba(0, 0, 0, 0.3)"
      },
      "high_contrast" => false
    }
  end

  # Loads the high contrast theme
  defp load_high_contrast_theme do
    %{
      "name" => "High Contrast",
      "colors" => %{
        "primary" => "#ffffff",
        "secondary" => "#ffff00",
        "background" => "#000000",
        "text" => "#ffffff",
        "border" => "#ffffff",
        "success" => "#00ff00",
        "warning" => "#ffff00",
        "error" => "#ff0000",
        "info" => "#00ffff"
      },
      "typography" => %{
        "fontFamily" =>
          "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif",
        "fontSize" => %{
          "small" => "14px",
          "medium" => "16px",
          "large" => "18px",
          "xlarge" => "22px"
        },
        "fontWeight" => %{
          "light" => 400,
          "regular" => 500,
          "medium" => 600,
          "bold" => 800
        }
      },
      "spacing" => %{
        "xs" => "6px",
        "sm" => "10px",
        "md" => "18px",
        "lg" => "26px",
        "xl" => "34px"
      },
      "borders" => %{
        "radius" => %{
          "small" => "2px",
          "medium" => "4px",
          "large" => "8px"
        },
        "width" => %{
          "thin" => "2px",
          "regular" => "3px",
          "thick" => "5px"
        }
      },
      "shadows" => %{
        "small" => "0 0 0 2px #ffffff",
        "medium" => "0 0 0 3px #ffffff",
        "large" => "0 0 0 4px #ffffff"
      },
      "high_contrast" => true
    }
  end

  # Helper to stringify map keys
  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), stringify_value(v)} end)
    |> Map.new()
  end

  defp stringify_keys(value), do: value

  # Helper to recursively stringify map values
  defp stringify_value(value) when is_map(value), do: stringify_keys(value)

  defp stringify_value(value) when is_list(value),
    do: Enum.map(value, &stringify_value/1)

  defp stringify_value(value), do: value
end
