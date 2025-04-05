defmodule Raxol.Plugins.ThemePlugin do
  @moduledoc """
  Plugin that manages terminal themes and color schemes.
  Allows users to apply predefined themes or create custom color schemes.
  """

  @behaviour Raxol.Plugins.Plugin

  defstruct [:name, :enabled, :config, :current_theme]

  @default_themes %{
    "default" => %{
      background: {0, 0, 0},
      foreground: {255, 255, 255},
      cursor: {255, 255, 255},
      selection: {128, 128, 128},
      black: {0, 0, 0},
      red: {255, 0, 0},
      green: {0, 255, 0},
      yellow: {255, 255, 0},
      blue: {0, 0, 255},
      magenta: {255, 0, 255},
      cyan: {0, 255, 255},
      white: {255, 255, 255},
      bright_black: {128, 128, 128},
      bright_red: {255, 128, 128},
      bright_green: {128, 255, 128},
      bright_yellow: {255, 255, 128},
      bright_blue: {128, 128, 255},
      bright_magenta: {255, 128, 255},
      bright_cyan: {128, 255, 255},
      bright_white: {255, 255, 255}
    },
    "solarized_dark" => %{
      background: {0, 43, 54},
      foreground: {147, 161, 161},
      cursor: {147, 161, 161},
      selection: {7, 54, 66},
      black: {7, 54, 66},
      red: {220, 50, 47},
      green: {133, 153, 0},
      yellow: {181, 137, 0},
      blue: {38, 139, 210},
      magenta: {211, 54, 130},
      cyan: {42, 161, 152},
      white: {238, 232, 213},
      bright_black: {0, 43, 54},
      bright_red: {203, 75, 22},
      bright_green: {88, 110, 117},
      bright_yellow: {101, 123, 131},
      bright_blue: {131, 148, 150},
      bright_magenta: {108, 113, 196},
      bright_cyan: {147, 161, 161},
      bright_white: {253, 246, 227}
    },
    "solarized_light" => %{
      background: {253, 246, 227},
      foreground: {101, 123, 131},
      cursor: {101, 123, 131},
      selection: {7, 54, 66},
      black: {7, 54, 66},
      red: {220, 50, 47},
      green: {133, 153, 0},
      yellow: {181, 137, 0},
      blue: {38, 139, 210},
      magenta: {211, 54, 130},
      cyan: {42, 161, 152},
      white: {238, 232, 213},
      bright_black: {0, 43, 54},
      bright_red: {203, 75, 22},
      bright_green: {88, 110, 117},
      bright_yellow: {101, 123, 131},
      bright_blue: {131, 148, 150},
      bright_magenta: {108, 113, 196},
      bright_cyan: {147, 161, 161},
      bright_white: {253, 246, 227}
    },
    "dracula" => %{
      background: {40, 42, 54},
      foreground: {248, 248, 242},
      cursor: {248, 248, 242},
      selection: {68, 71, 90},
      black: {40, 42, 54},
      red: {255, 85, 85},
      green: {80, 250, 123},
      yellow: {241, 250, 140},
      blue: {139, 233, 253},
      magenta: {255, 121, 198},
      cyan: {8, 232, 129},
      white: {248, 248, 242},
      bright_black: {68, 71, 90},
      bright_red: {255, 85, 85},
      bright_green: {80, 250, 123},
      bright_yellow: {241, 250, 140},
      bright_blue: {139, 233, 253},
      bright_magenta: {255, 121, 198},
      bright_cyan: {8, 232, 129},
      bright_white: {248, 248, 242}
    }
  }

  @impl true
  def init(config \\ %{}) do
    theme_name = Map.get(config, :theme, "default")
    theme = Map.get(@default_themes, theme_name, Map.get(@default_themes, "default"))
    
    {:ok, %__MODULE__{
      name: "theme",
      enabled: true,
      config: config,
      current_theme: theme
    }}
  end

  @impl true
  def handle_output(plugin, output) do
    # Process output for theme-related content
    case output do
      {:theme_change, theme_name} ->
        change_theme(plugin, theme_name)
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def handle_input(plugin, input) do
    case input do
      {:command, command} ->
        case String.slice(command, 0..6//1) do
          "theme: " ->
            theme_name = String.slice(command, 7..-1//1)
            case load_theme(theme_name) do
              {:ok, theme} -> %{plugin | current_theme: theme}
              {:error, _} -> plugin
            end
          _ ->
            plugin
        end
      _ ->
        plugin
    end
  end

  @impl true
  def handle_mouse(plugin, event) do
    # Handle mouse events for theme-related interactions
    case event do
      {:click, _x, _y} ->
        # Check if click is within theme selector bounds
        # For now, just pass through
        {:ok, plugin}
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def get_name(plugin) do
    plugin.name
  end

  @impl true
  def is_enabled?(plugin) do
    plugin.enabled
  end

  @impl true
  def enable(plugin) do
    %{plugin | enabled: true}
  end

  @impl true
  def disable(plugin) do
    %{plugin | enabled: false}
  end

  @impl true
  def cleanup(_plugin) do
    :ok
  end

  @impl true
  def get_api_version do
    "1.0.0"
  end

  @impl true
  def get_dependencies do
    []
  end

  @impl true
  def handle_resize(_plugin, _width, _height) do
    :ok
  end

  @doc """
  Changes the current theme to the specified theme name.
  """
  def change_theme(plugin, theme_name) do
    theme = Map.get(@default_themes, theme_name)
    
    if theme do
      {:ok, %{plugin | current_theme: theme}}
    else
      {:error, "Theme '#{theme_name}' not found"}
    end
  end

  @doc """
  Gets the current theme.
  """
  def get_theme(plugin) do
    plugin.current_theme
  end

  @doc """
  Gets a list of available themes.
  """
  def list_themes do
    Map.keys(@default_themes)
  end

  @doc """
  Creates a custom theme with the specified colors.
  """
  def create_custom_theme(plugin, name, colors) do
    # Validate that all required colors are present
    required_colors = [
      :background, :foreground, :cursor, :selection,
      :black, :red, :green, :yellow, :blue, :magenta, :cyan, :white,
      :bright_black, :bright_red, :bright_green, :bright_yellow,
      :bright_blue, :bright_magenta, :bright_cyan, :bright_white
    ]
    
    missing_colors = Enum.filter(required_colors, fn color -> !Map.has_key?(colors, color) end)
    
    if Enum.empty?(missing_colors) do
      # Add the custom theme to the available themes
      updated_themes = Map.put(@default_themes, name, colors)
      
      # Update the plugin with the new themes
      {:ok, %{plugin | config: Map.put(plugin.config, :themes, updated_themes)}}
    else
      {:error, "Missing required colors: #{Enum.join(missing_colors, ", ")}"}
    end
  end

  # Private functions

  defp load_theme(theme_name) do
    case Map.get(@default_themes, theme_name) do
      nil -> {:error, "Theme '#{theme_name}' not found"}
      theme -> {:ok, theme}
    end
  end
end 