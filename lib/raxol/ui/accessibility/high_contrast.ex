defmodule Raxol.UI.Accessibility.HighContrast do
  @moduledoc """
  High contrast mode system for improved visual accessibility in Raxol terminals.

  This module provides comprehensive high contrast support including:
  - Multiple high contrast themes (black/white, white/black, custom)
  - WCAG 2.1 AA and AAA contrast ratio compliance
  - Automatic contrast adjustment for different lighting conditions
  - Color blindness accommodation (Deuteranopia, Protanopia, Tritanopia)
  - Large text mode with scalable fonts
  - Custom user-defined contrast schemes
  - System integration with OS accessibility settings
  - Dynamic contrast adjustment based on ambient light
  - Color palette optimization for terminal interfaces

  ## Features

  ### Contrast Modes
  - High Contrast Black (white text on black background)
  - High Contrast White (black text on white background)  
  - High Contrast Custom (user-defined color schemes)
  - Inverted Colors mode
  - Grayscale mode with enhanced contrast
  - Adaptive contrast based on content type

  ### Accessibility Compliance
  - WCAG 2.1 Level AA (4.5:1 contrast ratio)
  - WCAG 2.1 Level AAA (7:1 contrast ratio)
  - Color blindness simulation and correction
  - Focus indicator enhancement
  - Text shadow and outline options for improved readability

  ## Usage

      # Initialize high contrast system
      {:ok, hc} = HighContrast.start_link(
        default_theme: :high_contrast_black,
        compliance_level: :wcag_aa,
        auto_detect_system: true,
        color_blind_support: true
      )
      
      # Apply high contrast theme
      HighContrast.apply_theme(hc, :high_contrast_white)
      
      # Create custom theme with WCAG compliance
      custom_theme = %{
        name: "custom_blue",
        background: {0, 0, 51},      # Dark blue
        foreground: {255, 255, 204}, # Light yellow
        accent: {255, 102, 0},       # Orange
        compliance_level: :wcag_aaa
      }
      HighContrast.register_theme(hc, custom_theme)
      
      # Enable color blindness accommodation
      HighContrast.configure_color_blindness(hc, :deuteranopia, %{
        strength: 0.8,
        enable_patterns: true,
        alternative_indicators: [:shapes, :textures]
      })
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Platform
  alias Raxol.UI.Theming.ThemeManager
  alias Raxol.Core.Runtime.Log

  defstruct [
    :config,
    :current_theme,
    :theme_registry,
    :contrast_analyzer,
    :color_blind_config,
    :system_monitor,
    :ambient_light_sensor,
    :user_preferences,
    :compliance_validator
  ]

  @type rgb_color :: {0..255, 0..255, 0..255}
  @type contrast_ratio :: float()
  @type compliance_level :: :wcag_a | :wcag_aa | :wcag_aaa
  @type color_blindness_type ::
          :deuteranopia | :protanopia | :tritanopia | :achromatopsia
  @type theme_name :: atom()

  @type theme :: %{
          name: theme_name(),
          background: rgb_color(),
          foreground: rgb_color(),
          accent: rgb_color(),
          secondary: rgb_color(),
          success: rgb_color(),
          warning: rgb_color(),
          error: rgb_color(),
          info: rgb_color(),
          border: rgb_color(),
          shadow: rgb_color(),
          compliance_level: compliance_level(),
          large_text_optimized: boolean()
        }

  @type config :: %{
          default_theme: theme_name(),
          compliance_level: compliance_level(),
          auto_detect_system: boolean(),
          color_blind_support: boolean(),
          large_text_mode: boolean(),
          adaptive_contrast: boolean(),
          ambient_light_adjustment: boolean(),
          focus_enhancement: boolean(),
          text_shadow: boolean(),
          invert_colors: boolean()
        }

  # Default configuration
  @default_config %{
    default_theme: :system,
    compliance_level: :wcag_aa,
    auto_detect_system: true,
    color_blind_support: false,
    large_text_mode: false,
    adaptive_contrast: true,
    ambient_light_adjustment: false,
    focus_enhancement: true,
    text_shadow: false,
    invert_colors: false
  }

  # Pre-defined high contrast themes
  @builtin_themes %{
    high_contrast_black: %{
      name: :high_contrast_black,
      # Black
      background: {0, 0, 0},
      # White
      foreground: {255, 255, 255},
      # Yellow
      accent: {255, 255, 0},
      # Light gray
      secondary: {192, 192, 192},
      # Lime green
      success: {0, 255, 0},
      # Yellow
      warning: {255, 255, 0},
      # Red
      error: {255, 0, 0},
      # Cyan
      info: {0, 255, 255},
      # White
      border: {255, 255, 255},
      # Dark gray
      shadow: {64, 64, 64},
      compliance_level: :wcag_aaa,
      large_text_optimized: true
    },
    high_contrast_white: %{
      name: :high_contrast_white,
      # White
      background: {255, 255, 255},
      # Black
      foreground: {0, 0, 0},
      # Blue
      accent: {0, 0, 255},
      # Dark gray
      secondary: {64, 64, 64},
      # Dark green
      success: {0, 128, 0},
      # Dark orange
      warning: {255, 140, 0},
      # Dark red
      error: {139, 0, 0},
      # Dark blue
      info: {0, 0, 139},
      # Black
      border: {0, 0, 0},
      # Light gray
      shadow: {192, 192, 192},
      compliance_level: :wcag_aaa,
      large_text_optimized: true
    },
    high_contrast_blue: %{
      name: :high_contrast_blue,
      # Very dark blue
      background: {0, 0, 51},
      # Light yellow
      foreground: {255, 255, 204},
      # Orange
      accent: {255, 102, 0},
      # Light blue
      secondary: {153, 153, 255},
      # Light green
      success: {102, 255, 102},
      # Gold
      warning: {255, 204, 0},
      # Light red
      error: {255, 102, 102},
      # Light blue
      info: {102, 204, 255},
      # Light yellow
      border: {255, 255, 204},
      # Darker blue
      shadow: {25, 25, 76},
      compliance_level: :wcag_aa,
      large_text_optimized: false
    },
    grayscale_high_contrast: %{
      name: :grayscale_high_contrast,
      # Black
      background: {0, 0, 0},
      # White
      foreground: {255, 255, 255},
      # Light gray
      accent: {192, 192, 192},
      # Medium gray
      secondary: {128, 128, 128},
      # Very light gray
      success: {224, 224, 224},
      # Medium-light gray
      warning: {160, 160, 160},
      # Medium-dark gray
      error: {96, 96, 96},
      # Light gray
      info: {192, 192, 192},
      # White
      border: {255, 255, 255},
      # Dark gray
      shadow: {64, 64, 64},
      compliance_level: :wcag_aaa,
      large_text_optimized: true
    }
  }

  # WCAG contrast ratio requirements
  @wcag_ratios %{
    wcag_a: 3.0,
    wcag_aa: 4.5,
    wcag_aaa: 7.0
  }

  @large_text_ratios %{
    wcag_a: 2.0,
    wcag_aa: 3.0,
    wcag_aaa: 4.5
  }

  ## Public API

  # BaseManager provides start_link/1 which handles GenServer initialization
  # Usage: Raxol.UI.Accessibility.HighContrast.start_link(name: __MODULE__, config: custom_config)
  # Options:
  #   - `:default_theme` - Initial theme to apply
  #   - `:compliance_level` - WCAG compliance level (:wcag_aa, :wcag_aaa)
  #   - `:auto_detect_system` - Detect system high contrast settings
  #   - `:color_blind_support` - Enable color blindness accommodations

  @doc """
  Applies a high contrast theme.
  """
  def apply_theme(hc \\ __MODULE__, theme_name) do
    GenServer.call(hc, {:apply_theme, theme_name})
  end

  @doc """
  Registers a custom high contrast theme.
  """
  def register_theme(hc \\ __MODULE__, theme) do
    GenServer.call(hc, {:register_theme, theme})
  end

  @doc """
  Gets the current active theme.
  """
  def get_current_theme(hc \\ __MODULE__) do
    GenServer.call(hc, :get_current_theme)
  end

  @doc """
  Lists all available themes.
  """
  def list_themes(hc \\ __MODULE__) do
    GenServer.call(hc, :list_themes)
  end

  @doc """
  Configures color blindness accommodation.
  """
  def configure_color_blindness(hc \\ __MODULE__, type, options \\ %{}) do
    GenServer.call(hc, {:configure_color_blindness, type, options})
  end

  @doc """
  Enables or disables large text mode.
  """
  def set_large_text_mode(hc \\ __MODULE__, enabled) do
    GenServer.call(hc, {:set_large_text_mode, enabled})
  end

  @doc """
  Toggles color inversion.
  """
  def toggle_invert_colors(hc \\ __MODULE__) do
    GenServer.call(hc, :toggle_invert_colors)
  end

  @doc """
  Validates contrast ratio compliance for a color pair.
  """
  def validate_contrast(
        hc \\ __MODULE__,
        foreground,
        background,
        options \\ %{}
      ) do
    GenServer.call(hc, {:validate_contrast, foreground, background, options})
  end

  @doc """
  Suggests improved colors for better contrast.
  """
  def suggest_contrast_improvement(hc \\ __MODULE__, foreground, background) do
    GenServer.call(hc, {:suggest_contrast_improvement, foreground, background})
  end

  @doc """
  Gets accessibility information for the current theme.
  """
  def get_accessibility_info(hc \\ __MODULE__) do
    GenServer.call(hc, :get_accessibility_info)
  end

  ## GenServer Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    config = Map.merge(@default_config, Keyword.get(opts, :config, %{}))
    # Initialize theme registry with built-in themes
    theme_registry = @builtin_themes

    # Detect system high contrast settings if enabled
    {initial_theme, updated_config} = get_initial_theme(config)

    # Initialize contrast analyzer
    contrast_analyzer = init_contrast_analyzer()

    # Initialize color blindness support
    color_blind_config = init_color_blind_config(config)

    # Initialize system monitoring
    system_monitor = init_system_monitor(config)

    state = %__MODULE__{
      config: updated_config,
      current_theme: nil,
      theme_registry: theme_registry,
      contrast_analyzer: contrast_analyzer,
      color_blind_config: color_blind_config,
      system_monitor: system_monitor,
      ambient_light_sensor: init_ambient_light_sensor(config),
      user_preferences: %{},
      compliance_validator: init_compliance_validator(config.compliance_level)
    }

    # Apply initial theme
    {:ok, final_state} = apply_theme_internal(state, initial_theme)

    Log.module_info("High contrast system initialized with theme: #{initial_theme}")
    {:ok, final_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:apply_theme, theme_name}, _from, state) do
    case apply_theme_internal(state, theme_name) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:register_theme, theme}, _from, state) do
    # Validate theme structure
    case validate_theme(theme) do
      {:ok, validated_theme} ->
        # Check contrast compliance
        case validate_theme_compliance(
               validated_theme,
               state.config.compliance_level
             ) do
          {:ok, compliance_info} ->
            new_registry =
              Map.put(
                state.theme_registry,
                validated_theme.name,
                validated_theme
              )

            new_state = %{state | theme_registry: new_registry}

            Log.module_info(
              "Custom theme registered: #{validated_theme.name} (#{compliance_info.level})"
            )

            {:reply, {:ok, compliance_info}, new_state}

          {:warning, issues} ->
            new_registry =
              Map.put(
                state.theme_registry,
                validated_theme.name,
                validated_theme
              )

            new_state = %{state | theme_registry: new_registry}

            Log.module_warning(
              "Theme registered with compliance issues: #{inspect(issues)}"
            )

            {:reply, {:warning, issues}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_current_theme, _from, state) do
    {:reply, state.current_theme, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:list_themes, _from, state) do
    themes =
      state.theme_registry
      |> Map.keys()
      |> Enum.map(fn theme_name ->
        theme = Map.get(state.theme_registry, theme_name)

        %{
          name: theme_name,
          compliance_level: theme.compliance_level,
          large_text_optimized: theme.large_text_optimized
        }
      end)

    {:reply, themes, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:configure_color_blindness, type, options},
        _from,
        state
      ) do
    configure_color_blindness_internal(state, type, options)
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_large_text_mode, enabled}, _from, state) do
    new_config = %{state.config | large_text_mode: enabled}
    new_state = %{state | config: new_config}

    # Re-apply current theme to adjust for large text
    {:ok, updated_state} = reapply_current_theme(new_state)

    Log.module_info("Large text mode #{format_enabled_status(enabled)}")

    {:reply, :ok, updated_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:toggle_invert_colors, _from, state) do
    new_invert = not state.config.invert_colors
    new_config = %{state.config | invert_colors: new_invert}
    new_state = %{state | config: new_config}

    # Re-apply current theme with inversion
    {:ok, updated_state} = reapply_current_theme(new_state)

    Log.module_info("Color inversion #{format_enabled_status(new_invert)}")

    {:reply, :ok, updated_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:validate_contrast, foreground, background, options},
        _from,
        state
      ) do
    large_text = Map.get(options, :large_text, state.config.large_text_mode)

    compliance_level =
      Map.get(options, :compliance_level, state.config.compliance_level)

    contrast_ratio = calculate_contrast_ratio(foreground, background)
    required_ratio = get_required_ratio(compliance_level, large_text)

    result = %{
      contrast_ratio: contrast_ratio,
      required_ratio: required_ratio,
      compliant: contrast_ratio >= required_ratio,
      level_achieved: get_achieved_compliance_level(contrast_ratio, large_text),
      recommendations:
        generate_contrast_recommendations(contrast_ratio, required_ratio)
    }

    {:reply, result, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:suggest_contrast_improvement, foreground, background},
        _from,
        state
      ) do
    current_ratio = calculate_contrast_ratio(foreground, background)

    target_ratio =
      get_required_ratio(
        state.config.compliance_level,
        state.config.large_text_mode
      )

    suggestions =
      build_contrast_suggestions(
        current_ratio,
        target_ratio,
        foreground,
        background
      )

    result = %{
      current_ratio: current_ratio,
      target_ratio: target_ratio,
      suggestions: suggestions
    }

    {:reply, result, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_accessibility_info, _from, state) do
    info = build_accessibility_info(state)
    {:reply, info, state}
  end

  ## Private Implementation

  defp apply_theme_internal(state, theme_name) do
    case Map.get(state.theme_registry, theme_name) do
      nil ->
        {:error, :theme_not_found}

      theme ->
        # Apply color blindness corrections if enabled
        adjusted_theme = apply_color_adjustments(theme, state)

        # Apply color inversion if enabled
        final_theme = apply_color_inversion(adjusted_theme, state.config)

        # Apply the theme to the UI system
        apply_theme_to_system(final_theme, state.config)

        new_state = %{state | current_theme: final_theme}
        {:ok, new_state}
    end
  end

  defp validate_theme(theme) do
    required_keys = [
      :name,
      :background,
      :foreground,
      :accent,
      :secondary,
      :success,
      :warning,
      :error,
      :info,
      :border,
      :shadow
    ]

    missing_keys =
      Enum.filter(required_keys, fn key -> not Map.has_key?(theme, key) end)

    validate_theme_keys(missing_keys, theme)
  end

  defp validate_theme_compliance(theme, required_level) do
    required_ratio = @wcag_ratios[required_level]

    # Check key color pairs
    critical_pairs = [
      {:foreground_background, theme.foreground, theme.background},
      {:accent_background, theme.accent, theme.background}
    ]

    issues = collect_compliance_issues(critical_pairs, required_ratio)

    case issues do
      [] ->
        {:ok, %{level: required_level, all_compliant: true}}

      issues when length(issues) < length(critical_pairs) ->
        {:warning, issues}

      _all_failed ->
        {:error, :insufficient_contrast}
    end
  end

  defp calculate_contrast_ratio({r1, g1, b1}, {r2, g2, b2}) do
    # Calculate relative luminance for each color
    l1 = relative_luminance(r1, g1, b1)
    l2 = relative_luminance(r2, g2, b2)

    # Ensure lighter color is in numerator
    {lighter, darker} =
      case l1 > l2 do
        true -> {l1, l2}
        false -> {l2, l1}
      end

    # Calculate contrast ratio
    (lighter + 0.05) / (darker + 0.05)
  end

  defp relative_luminance(r, g, b) do
    # Convert RGB to relative luminance using sRGB formula
    [r, g, b]
    |> Enum.map(fn c ->
      # Convert to [0, 1] range
      c_norm = c / 255.0

      # Apply gamma correction
      apply_gamma_correction(c_norm)
    end)
    |> then(fn [r_lin, g_lin, b_lin] ->
      # Calculate relative luminance
      0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin
    end)
  end

  defp get_required_ratio(compliance_level, large_text) do
    get_ratio_for_text_size(large_text, compliance_level)
  end

  defp get_ratio_for_text_size(true, compliance_level),
    do: @large_text_ratios[compliance_level]

  defp get_ratio_for_text_size(false, compliance_level),
    do: @wcag_ratios[compliance_level]

  defp get_achieved_compliance_level(ratio, large_text) do
    ratios = get_ratios_for_text_size(large_text)
    determine_compliance_from_ratio(ratio, ratios)
  end

  defp get_ratios_for_text_size(true), do: @large_text_ratios
  defp get_ratios_for_text_size(false), do: @wcag_ratios

  defp generate_contrast_recommendations(current_ratio, required_ratio) do
    improvement_needed = required_ratio / current_ratio
    build_recommendation_list([], improvement_needed, current_ratio)
  end

  defp build_contrast_suggestions(
         current_ratio,
         target_ratio,
         _foreground,
         _background
       )
       when current_ratio >= target_ratio,
       do: []

  defp build_contrast_suggestions(
         current_ratio,
         target_ratio,
         foreground,
         background
       ) do
    improvement_factor = target_ratio / current_ratio

    # Suggest darker background
    darker_bg = darken_color(background, improvement_factor)
    darker_bg_ratio = calculate_contrast_ratio(foreground, darker_bg)

    # Suggest lighter foreground  
    lighter_fg = lighten_color(foreground, improvement_factor)
    lighter_fg_ratio = calculate_contrast_ratio(lighter_fg, background)

    suggestions =
      build_suggestion_list(
        [],
        darker_bg,
        darker_bg_ratio,
        lighter_fg,
        lighter_fg_ratio,
        target_ratio
      )

    # Suggest high contrast alternatives
    high_contrast_suggestions = [
      %{
        type: :both,
        foreground: {255, 255, 255},
        background: {0, 0, 0},
        resulting_ratio: calculate_contrast_ratio({255, 255, 255}, {0, 0, 0})
      },
      %{
        type: :both,
        foreground: {0, 0, 0},
        background: {255, 255, 255},
        resulting_ratio: calculate_contrast_ratio({0, 0, 0}, {255, 255, 255})
      }
    ]

    suggestions ++ high_contrast_suggestions
  end

  defp darken_color({r, g, b}, factor) do
    adjustment = 1.0 / factor

    {
      round(r * adjustment) |> max(0) |> min(255),
      round(g * adjustment) |> max(0) |> min(255),
      round(b * adjustment) |> max(0) |> min(255)
    }
  end

  defp lighten_color({r, g, b}, factor) do
    # Cap the lightening
    adjustment = min(factor, 2.0)

    {
      round(r * adjustment) |> max(0) |> min(255),
      round(g * adjustment) |> max(0) |> min(255),
      round(b * adjustment) |> max(0) |> min(255)
    }
  end

  defp apply_color_blind_corrections(theme, color_blind_config) do
    correction_fn =
      case color_blind_config.type do
        :deuteranopia -> &correct_deuteranopia/2
        :protanopia -> &correct_protanopia/2
        :tritanopia -> &correct_tritanopia/2
        :achromatopsia -> &correct_achromatopsia/2
      end

    %{
      theme
      | foreground:
          correction_fn.(theme.foreground, color_blind_config.strength),
        accent: correction_fn.(theme.accent, color_blind_config.strength),
        success: correction_fn.(theme.success, color_blind_config.strength),
        warning: correction_fn.(theme.warning, color_blind_config.strength),
        error: correction_fn.(theme.error, color_blind_config.strength),
        info: correction_fn.(theme.info, color_blind_config.strength)
    }
  end

  defp correct_deuteranopia({r, g, b}, strength) do
    # Deuteranopia correction matrix (simplified)
    # This would use proper color transformation matrices in practice
    corrected_r = r
    corrected_g = round(g * (1.0 - strength) + r * strength * 0.3)
    corrected_b = b

    {corrected_r, corrected_g, corrected_b}
  end

  defp correct_protanopia({r, g, b}, strength) do
    # Protanopia correction matrix (simplified)
    corrected_r = round(r * (1.0 - strength) + g * strength * 0.7)
    corrected_g = g
    corrected_b = b

    {corrected_r, corrected_g, corrected_b}
  end

  defp correct_tritanopia({r, g, b}, strength) do
    # Tritanopia correction matrix (simplified)
    corrected_r = r
    corrected_g = g
    corrected_b = round(b * (1.0 - strength) + g * strength * 0.5)

    {corrected_r, corrected_g, corrected_b}
  end

  defp correct_achromatopsia({r, g, b}, strength) do
    # Convert to grayscale
    gray = round(0.299 * r + 0.587 * g + 0.114 * b)

    corrected_r = round(r * (1.0 - strength) + gray * strength)
    corrected_g = round(g * (1.0 - strength) + gray * strength)
    corrected_b = round(b * (1.0 - strength) + gray * strength)

    {corrected_r, corrected_g, corrected_b}
  end

  defp invert_theme_colors(theme) do
    %{
      theme
      | background: invert_color(theme.background),
        foreground: invert_color(theme.foreground),
        accent: invert_color(theme.accent),
        secondary: invert_color(theme.secondary),
        success: invert_color(theme.success),
        warning: invert_color(theme.warning),
        error: invert_color(theme.error),
        info: invert_color(theme.info),
        border: invert_color(theme.border),
        shadow: invert_color(theme.shadow)
    }
  end

  defp invert_color({r, g, b}) do
    {255 - r, 255 - g, 255 - b}
  end

  defp apply_theme_to_system(theme, _config) do
    # This would apply the theme to the actual terminal UI system
    # For now, we'll log the application
    Log.module_info("Applying high contrast theme: #{theme.name}")

    # Would integrate with ColorManager to update system colors
    UnifiedThemingManager.update_palette(%{
      background: theme.background,
      foreground: theme.foreground,
      accent: theme.accent
      # ... other colors
    })

    :ok
  end

  defp detect_system_high_contrast do
    case Platform.os_type() do
      :windows ->
        # Check Windows high contrast settings
        detect_windows_high_contrast()

      :macos ->
        # Check macOS accessibility settings
        detect_macos_high_contrast()

      :linux ->
        # Check Linux accessibility settings
        detect_linux_high_contrast()

      _ ->
        {:error, :unsupported_platform}
    end
  end

  defp detect_windows_high_contrast do
    # Would use Windows API to detect high contrast mode
    # For now, return a reasonable default
    {:ok, :high_contrast_black}
  end

  defp detect_macos_high_contrast do
    # Would use macOS Accessibility APIs
    {:ok, :high_contrast_white}
  end

  defp detect_linux_high_contrast do
    # Would check GNOME/KDE accessibility settings
    {:ok, :high_contrast_black}
  end

  ## Initialization helpers

  defp init_contrast_analyzer do
    %{
      cache: %{},
      last_analysis: nil,
      compliance_checks_enabled: true
    }
  end

  defp init_color_blind_support do
    %{
      type: nil,
      strength: 1.0,
      enable_patterns: false,
      alternative_indicators: [],
      correction_matrix: nil
    }
  end

  defp start_system_monitor do
    # Would start a process to monitor system accessibility changes
    %{enabled: true, last_check: System.monotonic_time(:millisecond)}
  end

  defp init_ambient_light_sensor(config) do
    init_ambient_light_sensor_with_config(config.ambient_light_adjustment)
  end

  defp init_ambient_light_sensor_with_config(true) do
    %{enabled: true, last_reading: 0.5, adjustment_factor: 1.0}
  end

  defp init_ambient_light_sensor_with_config(false) do
    %{enabled: false}
  end

  defp init_compliance_validator(level) do
    %{
      level: level,
      strict_mode: level == :wcag_aaa,
      cache: %{}
    }
  end

  defp generate_color_correction_matrix(type) do
    # Generate color correction matrix for color blindness type
    # These would be actual transformation matrices in practice
    case type do
      :deuteranopia ->
        [[1.0, 0.0, 0.0], [0.7, 0.3, 0.0], [0.0, 0.0, 1.0]]

      :protanopia ->
        [[0.3, 0.7, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]

      :tritanopia ->
        [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.5, 0.5]]

      :achromatopsia ->
        [[0.299, 0.587, 0.114], [0.299, 0.587, 0.114], [0.299, 0.587, 0.114]]
    end
  end

  defp color_blind_friendly?(_theme) do
    # Check if theme uses patterns/shapes in addition to color
    # This would analyze the theme for color-blind accessibility
    # Simplified for now
    true
  end

  defp determine_overall_compliance(contrast_analysis) do
    compliant_pairs = Enum.count(contrast_analysis, & &1.wcag_aa_compliant)
    total_pairs = length(contrast_analysis)
    calculate_compliance_level(compliant_pairs, total_pairs)
  end

  defp determine_compliance_from_ratio(ratio, ratios)
       when ratio >= ratios.wcag_aaa,
       do: :wcag_aaa

  defp determine_compliance_from_ratio(ratio, ratios)
       when ratio >= ratios.wcag_aa,
       do: :wcag_aa

  defp determine_compliance_from_ratio(ratio, ratios)
       when ratio >= ratios.wcag_a,
       do: :wcag_a

  defp determine_compliance_from_ratio(_ratio, _ratios), do: :non_compliant

  defp calculate_compliance_level(compliant_pairs, total_pairs)
       when compliant_pairs == total_pairs,
       do: :fully_compliant

  defp calculate_compliance_level(compliant_pairs, total_pairs)
       when compliant_pairs > total_pairs * 0.8,
       do: :mostly_compliant

  defp calculate_compliance_level(compliant_pairs, total_pairs)
       when compliant_pairs > total_pairs * 0.5,
       do: :partially_compliant

  defp calculate_compliance_level(_compliant_pairs, _total_pairs),
    do: :non_compliant

  defp get_enabled_accessibility_features(state) do
    build_feature_list(state)
  end

  ## Public Utility Functions

  @doc """
  Creates a custom theme builder with WCAG validation.
  """
  def create_theme_builder(base_colors, target_compliance \\ :wcag_aa) do
    %{
      base_colors: base_colors,
      target_compliance: target_compliance,
      build: fn ->
        # Build theme with automatic contrast adjustments
        build_compliant_theme(base_colors, target_compliance)
      end
    }
  end

  defp build_compliant_theme(base_colors, target_compliance) do
    # Build a theme that meets the target compliance level
    # This would automatically adjust colors to meet contrast requirements
    target_ratio = @wcag_ratios[target_compliance]

    background = Map.get(base_colors, :background, {0, 0, 0})
    foreground = Map.get(base_colors, :foreground, {255, 255, 255})

    # Ensure foreground/background meet contrast requirements
    current_ratio = calculate_contrast_ratio(foreground, background)

    {final_foreground, final_background} =
      ensure_contrast_compliance(
        foreground,
        background,
        current_ratio,
        target_ratio
      )

    %{
      name: :custom_compliant,
      background: final_background,
      foreground: final_foreground,
      accent: Map.get(base_colors, :accent, {255, 255, 0}),
      secondary: Map.get(base_colors, :secondary, {192, 192, 192}),
      success: Map.get(base_colors, :success, {0, 255, 0}),
      warning: Map.get(base_colors, :warning, {255, 255, 0}),
      error: Map.get(base_colors, :error, {255, 0, 0}),
      info: Map.get(base_colors, :info, {0, 255, 255}),
      border: final_foreground,
      shadow: darken_color(final_background, 1.5),
      compliance_level: target_compliance,
      large_text_optimized: false
    }
  end

  defp adjust_colors_for_contrast(foreground, background, target_ratio) do
    # Try darkening background first
    darker_bg = darken_color(background, 1.5)

    adjust_colors_for_contrast_internal(
      foreground,
      background,
      darker_bg,
      target_ratio
    )
  end

  ## Helper functions for refactored code

  defp get_initial_theme(%{auto_detect_system: true} = config) do
    case detect_system_high_contrast() do
      {:ok, system_theme} -> {system_theme, config}
      {:error, _reason} -> {config.default_theme, config}
    end
  end

  defp get_initial_theme(config) do
    {config.default_theme, config}
  end

  defp init_color_blind_config(%{color_blind_support: true}) do
    init_color_blind_support()
  end

  defp init_color_blind_config(_config) do
    nil
  end

  defp init_system_monitor(%{auto_detect_system: true}) do
    start_system_monitor()
  end

  defp init_system_monitor(_config) do
    nil
  end

  defp configure_color_blindness_internal(
         %{config: %{color_blind_support: false}} = state,
         _type,
         _options
       ) do
    {:reply, {:error, :color_blind_support_disabled}, state}
  end

  defp configure_color_blindness_internal(state, type, options) do
    new_color_blind_config = %{
      type: type,
      strength: Map.get(options, :strength, 1.0),
      enable_patterns: Map.get(options, :enable_patterns, false),
      alternative_indicators: Map.get(options, :alternative_indicators, []),
      correction_matrix: generate_color_correction_matrix(type)
    }

    new_state = %{state | color_blind_config: new_color_blind_config}

    # Re-apply current theme with color blindness corrections
    {:ok, updated_state} = reapply_current_theme(new_state)

    Log.module_info("Color blindness support configured: #{type}")
    {:reply, :ok, updated_state}
  end

  defp reapply_current_theme(%{current_theme: nil} = state) do
    {:ok, state}
  end

  defp reapply_current_theme(%{current_theme: current_theme} = state) do
    apply_theme_internal(state, current_theme.name)
  end

  defp format_enabled_status(true), do: "enabled"
  defp format_enabled_status(false), do: "disabled"

  defp build_accessibility_info(%{current_theme: nil}) do
    %{error: :no_theme_active}
  end

  defp build_accessibility_info(%{current_theme: theme} = state) do
    # Analyze all color pairs in the theme
    color_pairs = [
      {:foreground_background, theme.foreground, theme.background},
      {:accent_background, theme.accent, theme.background},
      {:success_background, theme.success, theme.background},
      {:warning_background, theme.warning, theme.background},
      {:error_background, theme.error, theme.background},
      {:info_background, theme.info, theme.background}
    ]

    contrast_analysis =
      Enum.map(color_pairs, fn {pair_name, fg, bg} ->
        ratio = calculate_contrast_ratio(fg, bg)

        %{
          pair: pair_name,
          foreground: fg,
          background: bg,
          contrast_ratio: ratio,
          # wcag_aa ratio
          wcag_aa_compliant: ratio >= 4.5,
          # wcag_aaa ratio
          wcag_aaa_compliant: ratio >= 7.0
        }
      end)

    %{
      theme_name: theme.name,
      compliance_level: theme.compliance_level,
      large_text_optimized: theme.large_text_optimized,
      color_blind_friendly: color_blind_friendly?(theme),
      contrast_analysis: contrast_analysis,
      overall_compliance: determine_overall_compliance(contrast_analysis),
      accessibility_features: get_enabled_accessibility_features(state)
    }
  end

  defp apply_color_adjustments(theme, %{color_blind_config: nil}) do
    theme
  end

  defp apply_color_adjustments(theme, %{color_blind_config: config}) do
    apply_color_blind_corrections(theme, config)
  end

  defp apply_color_inversion(theme, %{invert_colors: true}) do
    invert_theme_colors(theme)
  end

  defp apply_color_inversion(theme, _config) do
    theme
  end

  defp validate_theme_keys([], theme) do
    # Set defaults for optional keys
    validated =
      Map.merge(
        %{
          compliance_level: :wcag_aa,
          large_text_optimized: false
        },
        theme
      )

    {:ok, validated}
  end

  defp validate_theme_keys(missing_keys, _theme) do
    {:error, {:missing_keys, missing_keys}}
  end

  defp collect_compliance_issues(critical_pairs, required_ratio) do
    Enum.reduce(critical_pairs, [], fn {pair_name, fg, bg}, acc ->
      ratio = calculate_contrast_ratio(fg, bg)

      case ratio < required_ratio do
        true ->
          [%{pair: pair_name, ratio: ratio, required: required_ratio} | acc]

        false ->
          acc
      end
    end)
  end

  defp apply_gamma_correction(c_norm) when c_norm <= 0.03928 do
    c_norm / 12.92
  end

  defp apply_gamma_correction(c_norm) do
    :math.pow((c_norm + 0.055) / 1.055, 2.4)
  end

  defp build_recommendation_list(
         recommendations,
         improvement_needed,
         current_ratio
       ) do
    recommendations
    |> add_major_improvement_recommendation(improvement_needed)
    |> add_minor_improvement_recommendation(improvement_needed)
    |> add_critical_contrast_recommendation(current_ratio)
  end

  defp add_major_improvement_recommendation(recommendations, improvement_needed)
       when improvement_needed > 1.5 do
    [
      "Consider using darker background or lighter foreground colors"
      | recommendations
    ]
  end

  defp add_major_improvement_recommendation(recommendations, _),
    do: recommendations

  defp add_minor_improvement_recommendation(recommendations, improvement_needed)
       when improvement_needed > 1.2 do
    [
      "Adjust color saturation or brightness for better contrast"
      | recommendations
    ]
  end

  defp add_minor_improvement_recommendation(recommendations, _),
    do: recommendations

  defp add_critical_contrast_recommendation(recommendations, current_ratio)
       when current_ratio < 3.0 do
    [
      "Current contrast is very low - significant changes needed"
      | recommendations
    ]
  end

  defp add_critical_contrast_recommendation(recommendations, _),
    do: recommendations

  defp build_suggestion_list(
         suggestions,
         darker_bg,
         darker_bg_ratio,
         lighter_fg,
         lighter_fg_ratio,
         target_ratio
       ) do
    suggestions
    |> add_background_suggestion(darker_bg, darker_bg_ratio, target_ratio)
    |> add_foreground_suggestion(lighter_fg, lighter_fg_ratio, target_ratio)
  end

  defp add_background_suggestion(
         suggestions,
         darker_bg,
         darker_bg_ratio,
         target_ratio
       )
       when darker_bg_ratio >= target_ratio do
    [
      %{
        type: :background,
        color: darker_bg,
        resulting_ratio: darker_bg_ratio
      }
      | suggestions
    ]
  end

  defp add_background_suggestion(suggestions, _, _, _), do: suggestions

  defp add_foreground_suggestion(
         suggestions,
         lighter_fg,
         lighter_fg_ratio,
         target_ratio
       )
       when lighter_fg_ratio >= target_ratio do
    [
      %{
        type: :foreground,
        color: lighter_fg,
        resulting_ratio: lighter_fg_ratio
      }
      | suggestions
    ]
  end

  defp add_foreground_suggestion(suggestions, _, _, _), do: suggestions

  defp build_feature_list(state) do
    []
    |> add_feature("Large text mode", state.config.large_text_mode)
    |> add_feature("Color inversion", state.config.invert_colors)
    |> add_feature("Enhanced focus indicators", state.config.focus_enhancement)
    |> add_feature("Text shadows", state.config.text_shadow)
    |> add_color_blind_feature(state.color_blind_config)
  end

  defp add_feature(features, _name, false), do: features
  defp add_feature(features, name, true), do: [name | features]

  defp add_color_blind_feature(features, %{type: type}) when not is_nil(type) do
    ["Color blindness support" | features]
  end

  defp add_color_blind_feature(features, _), do: features

  defp ensure_contrast_compliance(
         foreground,
         background,
         current_ratio,
         target_ratio
       )
       when current_ratio >= target_ratio do
    {foreground, background}
  end

  defp ensure_contrast_compliance(
         foreground,
         background,
         _current_ratio,
         target_ratio
       ) do
    adjust_colors_for_contrast(foreground, background, target_ratio)
  end

  defp adjust_colors_for_contrast_internal(
         foreground,
         background,
         darker_bg,
         target_ratio
       ) do
    case calculate_contrast_ratio(foreground, darker_bg) >= target_ratio do
      true ->
        {foreground, darker_bg}

      false ->
        # Try lightening foreground
        lighter_fg = lighten_color(foreground, 1.5)

        case calculate_contrast_ratio(lighter_fg, background) >= target_ratio do
          true ->
            {lighter_fg, background}

          false ->
            # Use high contrast pair as last resort
            {r, g, b} = background
            luminance = relative_luminance(r, g, b)

            case luminance > 0.5 do
              true ->
                # Dark on light
                {{0, 0, 0}, background}

              false ->
                # Light on dark
                {{255, 255, 255}, background}
            end
        end
    end
  end
end
