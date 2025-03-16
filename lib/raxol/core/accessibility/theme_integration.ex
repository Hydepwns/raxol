defmodule Raxol.Core.Accessibility.ThemeIntegration do
  @moduledoc """
  Integrates accessibility settings with visual components.
  
  This module bridges the accessibility features with visual components
  to ensure proper rendering based on accessibility settings like:
  - High contrast mode
  - Reduced motion
  - Large text
  
  It provides event handlers that respond to accessibility setting changes
  and applies them to the appropriate components.
  
  ## Usage
  
  ```elixir
  # Initialize theme integration
  ThemeIntegration.init()
  
  # Apply current accessibility settings to components
  ThemeIntegration.apply_current_settings()
  ```
  """
  
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Components.FocusRing
  alias Raxol.Core.Accessibility
  
  @doc """
  Initialize the theme integration.
  
  Registers event handlers for accessibility setting changes.
  
  ## Examples
  
      iex> ThemeIntegration.init()
      :ok
  """
  def init do
    # Register event handlers for accessibility settings
    EventManager.register_handler(:accessibility_high_contrast, __MODULE__, :handle_high_contrast)
    EventManager.register_handler(:accessibility_reduced_motion, __MODULE__, :handle_reduced_motion)
    EventManager.register_handler(:accessibility_large_text, __MODULE__, :handle_large_text)
    
    :ok
  end
  
  @doc """
  Clean up the theme integration.
  
  Unregisters event handlers.
  
  ## Examples
  
      iex> ThemeIntegration.cleanup()
      :ok
  """
  def cleanup do
    # Unregister event handlers
    EventManager.unregister_handler(:accessibility_high_contrast, __MODULE__, :handle_high_contrast)
    EventManager.unregister_handler(:accessibility_reduced_motion, __MODULE__, :handle_reduced_motion)
    EventManager.unregister_handler(:accessibility_large_text, __MODULE__, :handle_large_text)
    
    :ok
  end
  
  @doc """
  Apply the current accessibility settings to components.
  
  ## Examples
  
      iex> ThemeIntegration.apply_current_settings()
      :ok
  """
  def apply_current_settings do
    # Get current accessibility options
    options = Process.get(:accessibility_options) || default_options()
    
    # Apply high contrast setting
    handle_high_contrast({:accessibility_high_contrast, options[:high_contrast]})
    
    # Apply reduced motion setting
    handle_reduced_motion({:accessibility_reduced_motion, options[:reduced_motion]})
    
    # Apply large text setting
    handle_large_text({:accessibility_large_text, options[:large_text]})
    
    :ok
  end
  
  @doc """
  Handle high contrast mode changes.
  
  ## Examples
  
      iex> ThemeIntegration.handle_high_contrast({:accessibility_high_contrast, true})
      :ok
  """
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    # Update focus ring for high contrast
    FocusRing.set_high_contrast(enabled)
    
    # Update component colors based on high contrast setting
    update_component_colors(enabled)
    
    :ok
  end
  
  @doc """
  Handle reduced motion setting changes.
  
  ## Examples
  
      iex> ThemeIntegration.handle_reduced_motion({:accessibility_reduced_motion, true})
      :ok
  """
  def handle_reduced_motion({:accessibility_reduced_motion, enabled}) do
    # Configure animations based on reduced motion setting
    if enabled do
      # Disable animations for focus ring
      FocusRing.configure(animation: :none, transition_effect: :none)
    else
      # Enable default animations for focus ring
      FocusRing.configure(animation: :pulse, transition_effect: :fade)
    end
    
    :ok
  end
  
  @doc """
  Handle large text setting changes.
  
  ## Examples
  
      iex> ThemeIntegration.handle_large_text({:accessibility_large_text, true})
      :ok
  """
  def handle_large_text({:accessibility_large_text, enabled}) do
    # Update text size based on large text setting
    text_scale = if enabled, do: 1.5, else: 1.0
    
    # Store text scale factor in process dictionary for components to use
    Process.put(:accessibility_text_scale, text_scale)
    
    :ok
  end
  
  @doc """
  Define high contrast color scheme for components.
  
  ## Examples
  
      iex> ThemeIntegration.get_high_contrast_colors()
      %{
        background: :black,
        foreground: :white,
        accent: :yellow,
        focus: :white,
        button: :yellow,
        error: :red
      }
  """
  def get_high_contrast_colors do
    %{
      background: :black,
      foreground: :white,
      accent: :yellow,
      focus: :white,
      button: :yellow,
      error: :red,
      success: :green,
      warning: :yellow,
      info: :cyan,
      border: :white
    }
  end
  
  @doc """
  Define standard color scheme for components.
  
  ## Examples
  
      iex> ThemeIntegration.get_standard_colors()
      %{
        background: {:rgb, 30, 30, 30},
        foreground: {:rgb, 220, 220, 220},
        accent: {:rgb, 0, 120, 215},
        focus: {:rgb, 0, 120, 215},
        button: {:rgb, 0, 120, 215},
        error: {:rgb, 232, 17, 35},
        success: {:rgb, 16, 124, 16},
        warning: {:rgb, 255, 140, 0},
        info: {:rgb, 41, 128, 185},
        border: {:rgb, 100, 100, 100}
      }
  """
  def get_standard_colors do
    %{
      background: {:rgb, 30, 30, 30},
      foreground: {:rgb, 220, 220, 220},
      accent: {:rgb, 0, 120, 215},
      focus: {:rgb, 0, 120, 215},
      button: {:rgb, 0, 120, 215},
      error: {:rgb, 232, 17, 35},
      success: {:rgb, 16, 124, 16},
      warning: {:rgb, 255, 140, 0},
      info: {:rgb, 41, 128, 185},
      border: {:rgb, 100, 100, 100}
    }
  end
  
  @doc """
  Get the current color scheme based on high contrast setting.
  
  ## Examples
  
      iex> ThemeIntegration.get_current_colors()
      %{...} # Returns either high contrast or standard colors
  """
  def get_current_colors do
    # Get current accessibility options
    options = Process.get(:accessibility_options) || default_options()
    
    if options[:high_contrast] do
      get_high_contrast_colors()
    else
      get_standard_colors()
    end
  end
  
  # Private functions
  
  defp default_options do
    [
      high_contrast: false,
      reduced_motion: false,
      large_text: false
    ]
  end
  
  defp update_component_colors(high_contrast) do
    # This would set colors for specific component types
    # based on high contrast mode
    
    # Example: Configure button styles for high contrast
    if high_contrast do
      # Set high contrast colors for buttons
      colors = get_high_contrast_colors()
      
      # Store component-specific styles in process dictionary
      # for components to use when rendering
      Process.put(:accessibility_component_styles, %{
        button: %{
          background: colors.button,
          foreground: colors.background,
          border: colors.border
        },
        input: %{
          background: colors.background,
          foreground: colors.foreground,
          border: colors.border
        },
        panel: %{
          background: colors.background,
          foreground: colors.foreground,
          border: colors.border
        }
      })
    else
      # Set standard colors
      colors = get_standard_colors()
      
      # Store component-specific styles in process dictionary
      Process.put(:accessibility_component_styles, %{
        button: %{
          background: colors.button,
          foreground: :white,
          border: colors.border
        },
        input: %{
          background: {:lighten, colors.background, 0.1},
          foreground: colors.foreground,
          border: colors.border
        },
        panel: %{
          background: colors.background,
          foreground: colors.foreground,
          border: colors.border
        }
      })
    end
    
    :ok
  end
end 