defmodule Raxol.Application do
  @moduledoc """
  The entry point for the Raxol application.
  
  This module handles:
  - Starting the application supervision tree
  - Initializing core systems
  - Managing application state
  """
  
  use Application
  
  alias Raxol.Style.Colors.{Persistence, HotReload, Accessibility}
  
  @impl true
  def start(_type, _args) do
    children = [
      # Initialize color system
      {Task, &init_color_system/0},
      
      # Start hot-reload server
      {HotReload, []}
    ]
    
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  @doc """
  Initializes the color system.
  
  This function:
  1. Loads user preferences
  2. Applies the theme if available
  3. Validates color accessibility
  4. Sets up hot-reloading
  """
  def init_color_system do
    # Load user preferences
    case Persistence.load_user_preferences("default") do
      {:ok, preferences} ->
        # Load and apply theme
        case Persistence.load_theme(preferences.theme_path) do
          {:ok, theme} ->
            # Validate and adjust colors for accessibility
            validate_and_adjust_theme(theme)
            
            # Subscribe to theme changes
            HotReload.subscribe()
            
            # Apply theme
            apply_theme(theme)
            
          {:error, _} ->
            # Create and apply default theme
            default_theme = create_default_theme()
            validate_and_adjust_theme(default_theme)
            apply_theme(default_theme)
        end
        
      {:error, _} ->
        # Create and apply default theme
        default_theme = create_default_theme()
        validate_and_adjust_theme(default_theme)
        apply_theme(default_theme)
    end
  end
  
  @doc """
  Validates and adjusts a theme for accessibility.
  
  ## Parameters
  
  - `theme` - The theme to validate and adjust
  
  ## Returns
  
  - The adjusted theme with accessible colors
  """
  def validate_and_adjust_theme(theme) do
    # Get background color
    background = theme.background || "#FFFFFF"
    
    # Validate and adjust UI colors
    case Accessibility.validate_colors(theme.ui_colors, background) do
      {:ok, _} ->
        theme
      {:error, _} ->
        # Adjust colors to meet accessibility requirements
        adjusted_colors = Accessibility.adjust_palette(theme.ui_colors, background)
        %{theme | ui_colors: adjusted_colors}
    end
  end
  
  @doc """
  Creates a default theme with accessible colors.
  
  ## Returns
  
  - A new theme with accessible colors
  """
  def create_default_theme do
    background = "#FFFFFF"
    base_color = "#0077CC"
    
    # Generate accessible palette
    palette = Accessibility.generate_accessible_palette(base_color, background)
    
    %{
      name: "Default",
      background: background,
      ui_colors: palette,
      modes: %{
        dark: %{
          background: "#000000",
          ui_colors: Accessibility.generate_accessible_palette(base_color, "#000000")
        },
        high_contrast: %{
          background: "#000000",
          ui_colors: Accessibility.generate_accessible_palette(base_color, "#000000", :aaa)
        }
      }
    }
  end
  
  @doc """
  Applies a theme to the application.
  
  ## Parameters
  
  - `theme` - The theme to apply
  """
  def apply_theme(theme) do
    # Save theme for persistence
    Persistence.save_theme(theme)
    
    # Apply theme to UI components
    # This will be implemented when we add the UI components
    :ok
  end
end