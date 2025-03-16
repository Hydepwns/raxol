defmodule Raxol.Examples.ColorSystemDemo do
  @moduledoc """
  A demonstration of the Raxol color system with accessibility integration.
  
  This example showcases:
  - Theme switching
  - Color palette management
  - High contrast mode
  - User preferences
  - Accessibility integration
  - Interactive color picker
  
  Run this demo to see how the color system adapts to accessibility settings
  and user preferences.
  """
  
  alias Raxol.Core.Accessibility
  alias Raxol.Style.Colors.System, as: ColorSystem
  alias Raxol.Style.Colors.PaletteManager
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.FocusManager
  
  @doc """
  Run the color system demo.
  
  ## Examples
  
      iex> Raxol.Examples.ColorSystemDemo.run()
  """
  def run do
    # Initialize required systems
    initialize_systems()
    
    # Set up demo state
    state = initial_state()
    
    # Run the demo loop
    run_demo_loop(state)
  end
  
  defp initialize_systems do
    # Initialize color system
    ColorSystem.init()
    
    # Initialize palette manager
    PaletteManager.init()
    
    # Initialize accessibility
    Accessibility.enable()
    
    # Initialize user preferences
    UserPreferences.init()
    
    # Initialize focus management
    FocusManager.init()
    
    # Initialize keyboard shortcuts
    KeyboardShortcuts.init()
    
    # Register keyboard shortcuts for the demo
    register_shortcuts()
  end
  
  defp initial_state do
    %{
      current_theme: :standard,
      high_contrast: false,
      reduced_motion: false,
      selected_palette: :primary,
      selected_color: :main,
      custom_color: "#4B9CD3",
      view: :themes,
      active_panel: :theme_selector
    }
  end
  
  defp register_shortcuts do
    # Theme switching shortcuts
    KeyboardShortcuts.register_shortcut("1", :select_standard_theme, fn ->
      select_theme(:standard)
    end, description: "Select standard theme")
    
    KeyboardShortcuts.register_shortcut("2", :select_dark_theme, fn ->
      select_theme(:dark)
    end, description: "Select dark theme")
    
    KeyboardShortcuts.register_shortcut("3", :select_high_contrast_theme, fn ->
      select_theme(:high_contrast)
    end, description: "Select high contrast theme")
    
    # Accessibility shortcuts
    KeyboardShortcuts.register_shortcut("h", :toggle_high_contrast, fn ->
      toggle_high_contrast()
    end, description: "Toggle high contrast mode")
    
    KeyboardShortcuts.register_shortcut("m", :toggle_reduced_motion, fn ->
      toggle_reduced_motion()
    end, description: "Toggle reduced motion")
    
    # View switching shortcuts
    KeyboardShortcuts.register_shortcut("t", :view_themes, fn ->
      switch_view(:themes)
    end, description: "View themes")
    
    KeyboardShortcuts.register_shortcut("p", :view_palettes, fn ->
      switch_view(:palettes)
    end, description: "View color palettes")
    
    KeyboardShortcuts.register_shortcut("c", :view_contrast, fn ->
      switch_view(:contrast)
    end, description: "View contrast checker")
    
    # Navigation shortcuts
    KeyboardShortcuts.register_shortcut("Tab", :next_panel, fn ->
      next_panel()
    end, description: "Navigate to next panel")
    
    KeyboardShortcuts.register_shortcut("Shift+Tab", :previous_panel, fn ->
      previous_panel()
    end, description: "Navigate to previous panel")
    
    # Exit shortcut
    KeyboardShortcuts.register_shortcut("q", :quit, fn ->
      exit_demo()
    end, description: "Quit demo")
  end
  
  defp run_demo_loop(state) do
    # Render the current state
    render(state)
    
    # Wait for user input
    case read_input() do
      {:key, key} ->
        # Handle keyboard input
        case handle_key(key, state) do
          {:exit, _new_state} ->
            # Exit the demo
            :ok
            
          {:continue, new_state} ->
            # Continue the demo loop with the new state
            run_demo_loop(new_state)
        end
        
      :error ->
        # Error reading input, exit
        :ok
    end
  end
  
  defp render(state) do
    # Clear the screen
    IO.write "\e[2J"
    IO.write "\e[H"
    
    # Print header
    print_header()
    
    # Print current settings
    print_settings(state)
    
    # Render the current view
    case state.view do
      :themes -> render_themes_view(state)
      :palettes -> render_palettes_view(state)
      :contrast -> render_contrast_view(state)
    end
    
    # Print keyboard shortcuts
    print_shortcuts()
    
    # Print footer
    print_footer()
  end
  
  defp print_header do
    IO.puts """
    ====================================
          RAXOL COLOR SYSTEM DEMO
    ====================================
    """
  end
  
  defp print_settings(state) do
    IO.puts """
    Current Theme: #{state.current_theme}
    High Contrast: #{state.high_contrast}
    Reduced Motion: #{state.reduced_motion}
    Active Panel: #{state.active_panel}
    
    """
  end
  
  defp render_themes_view(state) do
    IO.puts """
    === THEMES ===
    
    Available Themes:
    1. Standard
    2. Dark
    3. High Contrast
    4. Custom (#{state.custom_color})
    
    Theme Preview:
    """
    
    # Render theme preview boxes
    render_theme_preview(state.current_theme, state.high_contrast)
  end
  
  defp render_palettes_view(state) do
    IO.puts """
    === COLOR PALETTES ===
    
    Selected Palette: #{state.selected_palette}
    
    Colors:
    """
    
    # Render palette colors
    render_palette_colors(state.selected_palette, state.high_contrast)
    
    IO.puts """
    
    Use arrow keys to navigate palettes
    Press SPACE to select a color
    """
  end
  
  defp render_contrast_view(state) do
    IO.puts """
    === CONTRAST CHECKER ===
    
    Foreground: #{state.custom_color}
    Background: #FFFFFF
    
    Contrast Ratio: #{calculate_contrast_ratio(state.custom_color, "#FFFFFF")}
    WCAG AA Compliance: #{wcag_compliance(state.custom_color, "#FFFFFF", :aa)}
    WCAG AAA Compliance: #{wcag_compliance(state.custom_color, "#FFFFFF", :aaa)}
    
    Use R/G/B keys to adjust color
    """
    
    # Render contrast example
    render_contrast_example(state.custom_color, "#FFFFFF")
  end
  
  defp render_theme_preview(theme, high_contrast) do
    # Apply the theme temporarily for preview
    ColorSystem.apply_theme(theme, high_contrast: high_contrast)
    
    # Get colors from the theme
    primary = ColorSystem.get_color(:primary)
    secondary = ColorSystem.get_color(:secondary)
    background = ColorSystem.get_color(:background)
    foreground = ColorSystem.get_color(:foreground)
    
    # Render colored boxes
    IO.puts """
    Primary:    \e[48;2;#{rgb_values(primary)}m          \e[0m #{primary}
    Secondary:  \e[48;2;#{rgb_values(secondary)}m          \e[0m #{secondary}
    Background: \e[48;2;#{rgb_values(background)}m          \e[0m #{background}
    Foreground: \e[48;2;#{rgb_values(foreground)}m          \e[0m #{foreground}
    """
  end
  
  defp render_palette_colors(palette, high_contrast) do
    # Get colors from the palette
    colors = case palette do
      :primary -> %{
        main: PaletteManager.get_color(:primary, :main),
        light: PaletteManager.get_color(:primary, :light),
        dark: PaletteManager.get_color(:primary, :dark),
        contrast: PaletteManager.get_color(:primary, :contrast)
      }
      :neutral -> %{
        main: PaletteManager.get_color(:neutral, :main),
        light: PaletteManager.get_color(:neutral, :light),
        lighter: PaletteManager.get_color(:neutral, :lighter),
        dark: PaletteManager.get_color(:neutral, :dark),
        darker: PaletteManager.get_color(:neutral, :darker)
      }
      :semantic -> %{
        success: PaletteManager.get_color(:semantic, :success),
        warning: PaletteManager.get_color(:semantic, :warning),
        error: PaletteManager.get_color(:semantic, :error),
        info: PaletteManager.get_color(:semantic, :info)
      }
      _ -> %{}
    end
    
    # Apply high contrast if needed
    colors = if high_contrast do
      Enum.map(colors, fn {key, value} ->
        {key, make_high_contrast(value)}
      end)
      |> Enum.into(%{})
    else
      colors
    end
    
    # Render color boxes
    Enum.each(colors, fn {name, color} ->
      IO.puts "#{name}: \e[48;2;#{rgb_values(color)}m          \e[0m #{color}"
    end)
  end
  
  defp render_contrast_example(fg_color, bg_color) do
    # Convert hex colors to ANSI escape codes
    fg_rgb = rgb_values(fg_color)
    bg_rgb = rgb_values(bg_color)
    
    # Render a text example with the specified colors
    IO.puts """
    
    Example Text:
    \e[38;2;#{fg_rgb}m\e[48;2;#{bg_rgb}m This is example text with the selected colors \e[0m
    \e[38;2;#{fg_rgb}m\e[48;2;#{bg_rgb}m ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !@#$%^&*() \e[0m
    """
  end
  
  defp print_shortcuts do
    IO.puts """
    
    === KEYBOARD SHORTCUTS ===
    1-3: Select theme   h: Toggle high contrast   m: Toggle reduced motion
    t: Themes view      p: Palettes view          c: Contrast checker
    Tab/Shift+Tab: Navigate panels               q: Quit demo
    """
  end
  
  defp print_footer do
    IO.puts """
    ====================================
     Press any key to continue...
    ====================================
    """
  end
  
  defp read_input do
    # Read a single keypress
    case IO.read(1) do
      :eof -> :error
      error = {:error, _} -> error
      key -> {:key, key}
    end
  end
  
  defp handle_key(key, state) do
    case key do
      # Theme selection
      "1" -> 
        {:continue, select_theme(:standard, state)}
      "2" -> 
        {:continue, select_theme(:dark, state)}
      "3" -> 
        {:continue, select_theme(:high_contrast, state)}
        
      # Accessibility toggles
      "h" -> 
        {:continue, toggle_high_contrast(state)}
      "m" -> 
        {:continue, toggle_reduced_motion(state)}
        
      # View switching
      "t" -> 
        {:continue, switch_view(:themes, state)}
      "p" -> 
        {:continue, switch_view(:palettes, state)}
      "c" -> 
        {:continue, switch_view(:contrast, state)}
        
      # Navigation
      "\t" -> 
        {:continue, next_panel(state)}
      # Shift+Tab is harder to detect in raw mode, this is a simplification
        
      # Color adjustment in contrast view
      "r" when state.view == :contrast -> 
        {:continue, adjust_color(state, :red, 10)}
      "R" when state.view == :contrast -> 
        {:continue, adjust_color(state, :red, -10)}
      "g" when state.view == :contrast -> 
        {:continue, adjust_color(state, :green, 10)}
      "G" when state.view == :contrast -> 
        {:continue, adjust_color(state, :green, -10)}
      "b" when state.view == :contrast -> 
        {:continue, adjust_color(state, :blue, 10)}
      "B" when state.view == :contrast -> 
        {:continue, adjust_color(state, :blue, -10)}
        
      # Exit
      "q" -> 
        {:exit, state}
        
      # Default case for unhandled keys
      _ -> 
        {:continue, state}
    end
  end
  
  defp select_theme(theme, state \\ nil) do
    # Apply the theme
    ColorSystem.apply_theme(theme)
    
    # Announce theme change to screen readers
    Accessibility.announce("#{theme} theme selected")
    
    # Update state if provided
    if state do
      %{state | current_theme: theme}
    else
      nil
    end
  end
  
  defp toggle_high_contrast(state \\ nil) do
    # Toggle high contrast mode
    current = Accessibility.high_contrast_enabled?()
    new_value = not current
    Accessibility.set_high_contrast(new_value)
    
    # Announce change to screen readers
    if new_value do
      Accessibility.announce("High contrast mode enabled")
    else
      Accessibility.announce("High contrast mode disabled")
    end
    
    # Update state if provided
    if state do
      # Re-apply current theme with new high contrast setting
      ColorSystem.apply_theme(state.current_theme, high_contrast: new_value)
      %{state | high_contrast: new_value}
    else
      nil
    end
  end
  
  defp toggle_reduced_motion(state \\ nil) do
    # Toggle reduced motion
    current = Accessibility.reduced_motion_enabled?()
    new_value = not current
    Accessibility.set_reduced_motion(new_value)
    
    # Announce change to screen readers
    if new_value do
      Accessibility.announce("Reduced motion enabled")
    else
      Accessibility.announce("Reduced motion disabled")
    end
    
    # Update state if provided
    if state do
      %{state | reduced_motion: new_value}
    else
      nil
    end
  end
  
  defp switch_view(view, state \\ nil) do
    # Announce view change to screen readers
    view_name = case view do
      :themes -> "themes"
      :palettes -> "color palettes"
      :contrast -> "contrast checker"
    end
    Accessibility.announce("Switched to #{view_name} view")
    
    # Update state if provided
    if state do
      %{state | view: view}
    else
      nil
    end
  end
  
  defp next_panel(state \\ nil) do
    # Navigate to the next panel
    next = case state && state.active_panel do
      :theme_selector -> :color_selector
      :color_selector -> :preview
      :preview -> :theme_selector
      _ -> :theme_selector
    end
    
    # Announce panel change to screen readers
    panel_name = case next do
      :theme_selector -> "theme selector"
      :color_selector -> "color selector"
      :preview -> "preview"
    end
    Accessibility.announce("Moved to #{panel_name} panel")
    
    # Update state if provided
    if state do
      %{state | active_panel: next}
    else
      nil
    end
  end
  
  defp previous_panel(state \\ nil) do
    # Navigate to the previous panel
    prev = case state && state.active_panel do
      :theme_selector -> :preview
      :color_selector -> :theme_selector
      :preview -> :color_selector
      _ -> :preview
    end
    
    # Announce panel change to screen readers
    panel_name = case prev do
      :theme_selector -> "theme selector"
      :color_selector -> "color selector"
      :preview -> "preview"
    end
    Accessibility.announce("Moved to #{panel_name} panel")
    
    # Update state if provided
    if state do
      %{state | active_panel: prev}
    else
      nil
    end
  end
  
  defp adjust_color(state, component, amount) do
    # Parse the current color
    {r, g, b} = hex_to_rgb(state.custom_color)
    
    # Adjust the specified component
    {r, g, b} = case component do
      :red -> {clamp(r + amount, 0, 255), g, b}
      :green -> {r, clamp(g + amount, 0, 255), b}
      :blue -> {r, g, clamp(b + amount, 0, 255)}
    end
    
    # Convert back to hex
    new_color = rgb_to_hex(r, g, b)
    
    # Announce color change to screen readers
    Accessibility.announce("Color adjusted to #{new_color}")
    
    # Update state
    %{state | custom_color: new_color}
  end
  
  defp exit_demo do
    # Announce exit to screen readers
    Accessibility.announce("Exiting color system demo")
    
    nil
  end
  
  # Helper functions
  
  defp rgb_values(hex_color) do
    {r, g, b} = hex_to_rgb(hex_color)
    "#{r};#{g};#{b}"
  end
  
  defp hex_to_rgb(hex) do
    hex = String.replace(hex, ~r/^#/, "")
    
    r = String.slice(hex, 0..1) |> String.to_integer(16)
    g = String.slice(hex, 2..3) |> String.to_integer(16)
    b = String.slice(hex, 4..5) |> String.to_integer(16)
    
    {r, g, b}
  end
  
  defp rgb_to_hex(r, g, b) do
    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")
    
    "##{r_hex}#{g_hex}#{b_hex}"
  end
  
  defp clamp(value, min, max) do
    cond do
      value < min -> min
      value > max -> max
      true -> value
    end
  end
  
  defp calculate_contrast_ratio(color1, color2) do
    # This is a simplified implementation - the real one would use the
    # Utilities.contrast_ratio function from the color utilities module
    
    # Convert colors to luminance
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)
    
    # Calculate contrast ratio
    ratio = if l1 > l2 do
      (l1 + 0.05) / (l2 + 0.05)
    else
      (l2 + 0.05) / (l1 + 0.05)
    end
    
    # Format to one decimal place
    :erlang.float_to_binary(ratio, [decimals: 1])
  end
  
  defp relative_luminance(hex) do
    {r, g, b} = hex_to_rgb(hex)
    
    # Convert to sRGB
    r_srgb = r / 255
    g_srgb = g / 255
    b_srgb = b / 255
    
    # Calculate luminance components
    r_lum = if r_srgb <= 0.03928, do: r_srgb / 12.92, else: :math.pow((r_srgb + 0.055) / 1.055, 2.4)
    g_lum = if g_srgb <= 0.03928, do: g_srgb / 12.92, else: :math.pow((g_srgb + 0.055) / 1.055, 2.4)
    b_lum = if b_srgb <= 0.03928, do: b_srgb / 12.92, else: :math.pow((b_srgb + 0.055) / 1.055, 2.4)
    
    # Calculate relative luminance
    0.2126 * r_lum + 0.7152 * g_lum + 0.0722 * b_lum
  end
  
  defp wcag_compliance(color1, color2, level) do
    # Calculate contrast ratio
    ratio_string = calculate_contrast_ratio(color1, color2)
    ratio = String.to_float(ratio_string)
    
    # Check compliance
    case level do
      :aa -> if ratio >= 4.5, do: "Pass", else: "Fail"
      :aaa -> if ratio >= 7.0, do: "Pass", else: "Fail"
    end
  end
  
  defp make_high_contrast(color) do
    # Determine if color is dark or light
    {r, g, b} = hex_to_rgb(color)
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    
    if luminance > 0.5 do
      # Light color - make darker for high contrast
      rgb_to_hex(
        clamp(round(r * 0.3), 0, 255),
        clamp(round(g * 0.3), 0, 255),
        clamp(round(b * 0.3), 0, 255)
      )
    else
      # Dark color - make lighter for high contrast
      rgb_to_hex(
        clamp(round(r + (255 - r) * 0.7), 0, 255),
        clamp(round(g + (255 - g) * 0.7), 0, 255),
        clamp(round(b + (255 - b) * 0.7), 0, 255)
      )
    end
  end
end 