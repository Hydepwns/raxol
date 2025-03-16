defmodule Raxol.Examples.IntegratedAccessibilityDemo do
  @moduledoc """
  An integrated demo showcasing Raxol's accessibility features working together
  with color system, animation framework, and internationalization.
  
  This demo provides an interactive way to explore how Raxol's accessibility
  features work cohesively across different systems:
  
  - Color system with high contrast and theme switching
  - Animation framework with reduced motion support
  - Internationalization with RTL support and screen reader integration
  - User preferences with persistence
  - Keyboard shortcuts with internationalization
  
  ## Features
  
  - Interactive interface to toggle accessibility settings
  - Live demonstration of settings effects across all systems
  - Support for multiple languages including RTL languages
  - Persistent user preferences across sessions
  - Screen reader announcements in the user's preferred language
  """
  
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.I18n
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Style.Colors.System, as: ColorSystem
  alias Raxol.Style.Colors.PaletteManager
  alias Raxol.Animation.Framework, as: AnimationFramework
  alias Raxol.UI.Components.FocusManager
  alias Raxol.UI.Terminal
  
  @demo_sections [
    :welcome,
    :color_system,
    :animation,
    :internationalization,
    :user_preferences,
    :keyboard_shortcuts
  ]
  
  @available_locales ["en", "fr", "es", "ar", "ja"]
  
  @doc """
  Run the integrated accessibility demo.
  
  ## Examples
  
      iex> Raxol.Examples.IntegratedAccessibilityDemo.run()
      :ok
  """
  def run do
    # Initialize core systems
    initialize_systems()
    
    # Create initial state
    state = %{
      active_section: :welcome,
      theme: :standard,
      high_contrast: false,
      reduced_motion: false,
      locale: "en",
      animation_speed: :normal,
      preferences_saved: false,
      focus_index: 0,
      sections: @demo_sections,
      sample_animation: nil,
      loading_progress: 0
    }
    
    # Start the main loop
    Terminal.clear()
    demo_loop(state)
    
    :ok
  end
  
  # Private functions
  
  defp initialize_systems do
    # Initialize accessibility module
    Accessibility.init()
    Accessibility.enable()
    
    # Initialize user preferences
    UserPreferences.init()
    
    # Initialize color system
    ColorSystem.init()
    PaletteManager.init()
    
    # Initialize animation framework
    AnimationFramework.init()
    
    # Initialize internationalization
    I18n.init(
      default_locale: "en",
      available_locales: @available_locales,
      fallback_locale: "en"
    )
    
    # Register translations
    register_translations()
    
    # Initialize keyboard shortcuts
    KeyboardShortcuts.init()
    register_keyboard_shortcuts()
    
    # Initialize focus manager
    FocusManager.init()
  end
  
  defp register_keyboard_shortcuts do
    KeyboardShortcuts.register_shortcut(:toggle_high_contrast, "Alt+H", fn ->
      current = Accessibility.high_contrast_enabled?()
      Accessibility.set_high_contrast(!current)
      Accessibility.announce_to_screen_reader(I18n.t("accessibility.high_contrast_#{!current}"))
    end)
    
    KeyboardShortcuts.register_shortcut(:toggle_reduced_motion, "Alt+M", fn ->
      current = Accessibility.reduced_motion_enabled?()
      Accessibility.set_reduced_motion(!current)
      Accessibility.announce_to_screen_reader(I18n.t("accessibility.reduced_motion_#{!current}"))
    end)
    
    KeyboardShortcuts.register_shortcut(:next_theme, "Alt+T", fn ->
      themes = [:standard, :dark, :high_contrast]
      current_index = Enum.find_index(themes, fn t -> t == UserPreferences.get(:theme, :standard) end)
      next_index = rem(current_index + 1, length(themes))
      next_theme = Enum.at(themes, next_index)
      
      UserPreferences.set(:theme, next_theme)
      ColorSystem.apply_theme(next_theme)
      
      # Announce theme change
      Accessibility.announce_to_screen_reader("#{next_theme} #{I18n.t("demo.theme_changed")}")
    end)
    
    KeyboardShortcuts.register_shortcut(:next_language, "Alt+L", fn ->
      current_locale = I18n.get_locale()
      current_index = Enum.find_index(@available_locales, fn l -> l == current_locale end)
      next_index = rem(current_index + 1, length(@available_locales))
      next_locale = Enum.at(@available_locales, next_index)
      
      I18n.set_locale(next_locale)
      UserPreferences.set(:locale, next_locale)
      
      # Get locale name in that language
      locale_name = I18n.t("locales.#{next_locale}")
      
      # Announce language change
      Accessibility.announce_to_screen_reader("#{locale_name} - #{I18n.t("demo.language_changed")}")
    end)
    
    KeyboardShortcuts.register_shortcut(:save_preferences, "Alt+S", fn ->
      UserPreferences.save()
      
      # Announce saved
      Accessibility.announce_to_screen_reader(I18n.t("demo.preferences_saved"))
    end)
    
    KeyboardShortcuts.register_shortcut(:exit_demo, "Ctrl+Q", fn ->
      # Announce exit
      Accessibility.announce_to_screen_reader(I18n.t("demo.exiting"))
      
      # Exit after a short delay to allow announcement to complete
      Process.sleep(500)
      System.halt(0)
    end)
  end
  
  defp register_translations do
    # English translations
    I18n.register_translations("en", %{
      "demo.title" => "Raxol Integrated Accessibility Demo",
      "demo.welcome" => "Welcome to the Raxol Accessibility Demo!",
      "demo.instructions" => "Use arrow keys to navigate, Enter to select, or shortcut keys.",
      "demo.high_contrast" => "High Contrast Mode",
      "demo.reduced_motion" => "Reduced Motion Mode",
      "demo.theme" => "Current Theme",
      "demo.language" => "Current Language",
      "demo.exit" => "Press Ctrl+Q to exit",
      "demo.save_preferences" => "Save Preferences (Alt+S)",
      "demo.preferences_saved" => "Preferences saved",
      "demo.theme_changed" => "theme applied",
      "demo.language_changed" => "language selected",
      "demo.exiting" => "Exiting demo",
      "locales.en" => "English",
      "locales.fr" => "French",
      "locales.es" => "Spanish",
      "locales.ar" => "Arabic",
      "locales.ja" => "Japanese",
      
      "section.welcome" => "Welcome",
      "section.color_system" => "Color System",
      "section.animation" => "Animation",
      "section.internationalization" => "Internationalization",
      "section.user_preferences" => "User Preferences",
      "section.keyboard_shortcuts" => "Keyboard Shortcuts",
      
      "color.primary" => "Primary",
      "color.secondary" => "Secondary",
      "color.success" => "Success",
      "color.error" => "Error",
      "color.warning" => "Warning",
      "color.info" => "Info",
      "color.background" => "Background",
      "color.foreground" => "Foreground",
      
      "animation.start" => "Start Animation",
      "animation.stop" => "Stop Animation",
      "animation.speed" => "Animation Speed",
      "animation.speed.slow" => "Slow",
      "animation.speed.normal" => "Normal",
      "animation.speed.fast" => "Fast",
      "animation.loading" => "Loading...",
      "animation.completed" => "Loading completed",
      
      "keyboard.shortcut" => "Shortcut",
      "keyboard.description" => "Description",
      "keyboard.toggle_high_contrast" => "Toggle High Contrast Mode",
      "keyboard.toggle_reduced_motion" => "Toggle Reduced Motion Mode",
      "keyboard.next_theme" => "Switch to Next Theme",
      "keyboard.next_language" => "Switch to Next Language",
      "keyboard.save_preferences" => "Save User Preferences",
      "keyboard.exit_demo" => "Exit Demo",
      
      "accessibility.high_contrast_true" => "High contrast mode enabled",
      "accessibility.high_contrast_false" => "High contrast mode disabled",
      "accessibility.reduced_motion_true" => "Reduced motion mode enabled",
      "accessibility.reduced_motion_false" => "Reduced motion mode disabled"
    })
    
    # French translations
    I18n.register_translations("fr", %{
      "demo.title" => "Démo Intégrée d'Accessibilité de Raxol",
      "demo.welcome" => "Bienvenue à la Démo d'Accessibilité de Raxol !",
      "demo.instructions" => "Utilisez les flèches pour naviguer, Entrée pour sélectionner, ou les raccourcis clavier.",
      "demo.high_contrast" => "Mode Contraste Élevé",
      "demo.reduced_motion" => "Mode Mouvement Réduit",
      "demo.theme" => "Thème Actuel",
      "demo.language" => "Langue Actuelle",
      "demo.exit" => "Appuyez sur Ctrl+Q pour quitter",
      "demo.save_preferences" => "Sauvegarder les Préférences (Alt+S)",
      "demo.preferences_saved" => "Préférences sauvegardées",
      "demo.theme_changed" => "thème appliqué",
      "demo.language_changed" => "langue sélectionnée",
      "demo.exiting" => "Fermeture de la démo",
      "locales.en" => "Anglais",
      "locales.fr" => "Français",
      "locales.es" => "Espagnol",
      "locales.ar" => "Arabe",
      "locales.ja" => "Japonais",
      
      "section.welcome" => "Bienvenue",
      "section.color_system" => "Système de Couleurs",
      "section.animation" => "Animation",
      "section.internationalization" => "Internationalisation",
      "section.user_preferences" => "Préférences Utilisateur",
      "section.keyboard_shortcuts" => "Raccourcis Clavier",
      
      "accessibility.high_contrast_true" => "Mode contraste élevé activé",
      "accessibility.high_contrast_false" => "Mode contraste élevé désactivé",
      "accessibility.reduced_motion_true" => "Mode mouvement réduit activé",
      "accessibility.reduced_motion_false" => "Mode mouvement réduit désactivé"
    })
    
    # Spanish translations
    I18n.register_translations("es", %{
      "demo.title" => "Demo Integrada de Accesibilidad de Raxol",
      "demo.welcome" => "¡Bienvenido a la Demo de Accesibilidad de Raxol!",
      "demo.instructions" => "Use las flechas para navegar, Enter para seleccionar, o teclas de acceso rápido.",
      "demo.high_contrast" => "Modo de Alto Contraste",
      "demo.reduced_motion" => "Modo de Movimiento Reducido",
      "demo.theme" => "Tema Actual",
      "demo.language" => "Idioma Actual",
      "demo.exit" => "Presione Ctrl+Q para salir",
      "demo.save_preferences" => "Guardar Preferencias (Alt+S)",
      "demo.preferences_saved" => "Preferencias guardadas",
      "demo.theme_changed" => "tema aplicado",
      "demo.language_changed" => "idioma seleccionado",
      "demo.exiting" => "Saliendo de la demo",
      "locales.en" => "Inglés",
      "locales.fr" => "Francés",
      "locales.es" => "Español",
      "locales.ar" => "Árabe",
      "locales.ja" => "Japonés",
      
      "accessibility.high_contrast_true" => "Modo de alto contraste activado",
      "accessibility.high_contrast_false" => "Modo de alto contraste desactivado",
      "accessibility.reduced_motion_true" => "Modo de movimiento reducido activado",
      "accessibility.reduced_motion_false" => "Modo de movimiento reducido desactivado"
    })
    
    # Arabic translations
    I18n.register_translations("ar", %{
      "demo.title" => "عرض تكاملي لإمكانية الوصول من راكسول",
      "demo.welcome" => "مرحبًا بك في عرض إمكانية الوصول من راكسول!",
      "demo.instructions" => "استخدم مفاتيح الأسهم للتنقل، Enter للتحديد، أو مفاتيح الاختصار.",
      "demo.high_contrast" => "وضع التباين العالي",
      "demo.reduced_motion" => "وضع الحركة المخفضة",
      "demo.theme" => "السمة الحالية",
      "demo.language" => "اللغة الحالية",
      "demo.exit" => "اضغط على Ctrl+Q للخروج",
      "demo.save_preferences" => "حفظ التفضيلات (Alt+S)",
      "demo.preferences_saved" => "تم حفظ التفضيلات",
      "demo.theme_changed" => "تم تطبيق السمة",
      "demo.language_changed" => "تم اختيار اللغة",
      "demo.exiting" => "جاري الخروج من العرض",
      "locales.en" => "الإنجليزية",
      "locales.fr" => "الفرنسية",
      "locales.es" => "الإسبانية",
      "locales.ar" => "العربية",
      "locales.ja" => "اليابانية",
      
      "accessibility.high_contrast_true" => "تم تمكين وضع التباين العالي",
      "accessibility.high_contrast_false" => "تم تعطيل وضع التباين العالي",
      "accessibility.reduced_motion_true" => "تم تمكين وضع الحركة المخفضة",
      "accessibility.reduced_motion_false" => "تم تعطيل وضع الحركة المخفضة"
    })
    
    # Japanese translations
    I18n.register_translations("ja", %{
      "demo.title" => "Raxol 統合アクセシビリティデモ",
      "demo.welcome" => "Raxol アクセシビリティデモへようこそ！",
      "demo.instructions" => "矢印キーで移動、Enterで選択、ショートカットキーも使用できます。",
      "demo.high_contrast" => "ハイコントラストモード",
      "demo.reduced_motion" => "モーション軽減モード",
      "demo.theme" => "現在のテーマ",
      "demo.language" => "現在の言語",
      "demo.exit" => "終了するには Ctrl+Q を押してください",
      "demo.save_preferences" => "設定を保存 (Alt+S)",
      "demo.preferences_saved" => "設定が保存されました",
      "demo.theme_changed" => "テーマが適用されました",
      "demo.language_changed" => "言語が選択されました",
      "demo.exiting" => "デモを終了しています",
      "locales.en" => "英語",
      "locales.fr" => "フランス語",
      "locales.es" => "スペイン語",
      "locales.ar" => "アラビア語",
      "locales.ja" => "日本語",
      
      "accessibility.high_contrast_true" => "ハイコントラストモードが有効になりました",
      "accessibility.high_contrast_false" => "ハイコントラストモードが無効になりました",
      "accessibility.reduced_motion_true" => "モーション軽減モードが有効になりました",
      "accessibility.reduced_motion_false" => "モーション軽減モードが無効になりました"
    })
  end
  
  defp demo_loop(state) do
    # Render the current state
    render(state)
    
    # Process input and get new state
    updated_state = process_input(state)
    
    # Update animation
    animation_state = update_animation(updated_state)
    
    # Continue the loop unless exiting
    demo_loop(animation_state)
  end
  
  defp process_input(state) do
    # Get keyboard input (non-blocking)
    case Terminal.read_key(timeout: 100) do
      {:ok, key} -> handle_key(key, state)
      :timeout -> state
      _ -> state
    end
  end
  
  defp handle_key({:arrow, :up}, state) do
    # Move focus up
    focus_index = max(0, state.focus_index - 1)
    %{state | focus_index: focus_index}
  end
  
  defp handle_key({:arrow, :down}, state) do
    # Move focus down
    focus_index = min(length(state.sections) - 1, state.focus_index + 1)
    %{state | focus_index: focus_index}
  end
  
  defp handle_key({:arrow, :left}, state) do
    # Handle left arrow based on active section
    case state.active_section do
      :color_system ->
        themes = [:standard, :dark, :high_contrast]
        current_index = Enum.find_index(themes, fn t -> t == state.theme end)
        prev_index = if current_index - 1 < 0, do: length(themes) - 1, else: current_index - 1
        theme = Enum.at(themes, prev_index)
        
        ColorSystem.apply_theme(theme)
        %{state | theme: theme}
        
      :animation ->
        speeds = [:slow, :normal, :fast]
        current_index = Enum.find_index(speeds, fn s -> s == state.animation_speed end)
        prev_index = if current_index - 1 < 0, do: length(speeds) - 1, else: current_index - 1
        %{state | animation_speed: Enum.at(speeds, prev_index)}
        
      :internationalization ->
        current_index = Enum.find_index(@available_locales, fn l -> l == state.locale end)
        prev_index = if current_index - 1 < 0, do: length(@available_locales) - 1, else: current_index - 1
        locale = Enum.at(@available_locales, prev_index)
        
        I18n.set_locale(locale)
        %{state | locale: locale}
        
      _ -> state
    end
  end
  
  defp handle_key({:arrow, :right}, state) do
    # Handle right arrow based on active section
    case state.active_section do
      :color_system ->
        themes = [:standard, :dark, :high_contrast]
        current_index = Enum.find_index(themes, fn t -> t == state.theme end)
        next_index = rem(current_index + 1, length(themes))
        theme = Enum.at(themes, next_index)
        
        ColorSystem.apply_theme(theme)
        %{state | theme: theme}
        
      :animation ->
        speeds = [:slow, :normal, :fast]
        current_index = Enum.find_index(speeds, fn s -> s == state.animation_speed end)
        next_index = rem(current_index + 1, length(speeds))
        %{state | animation_speed: Enum.at(speeds, next_index)}
        
      :internationalization ->
        current_index = Enum.find_index(@available_locales, fn l -> l == state.locale end)
        next_index = rem(current_index + 1, length(@available_locales))
        locale = Enum.at(@available_locales, next_index)
        
        I18n.set_locale(locale)
        %{state | locale: locale}
        
      _ -> state
    end
  end
  
  defp handle_key(:enter, state) do
    # Handle enter key - select section
    section = Enum.at(state.sections, state.focus_index)
    %{state | active_section: section}
  end
  
  defp handle_key(:space, state) do
    # Handle space key based on active section
    case state.active_section do
      :color_system ->
        # Toggle high contrast
        high_contrast = !state.high_contrast
        Accessibility.set_high_contrast(high_contrast)
        %{state | high_contrast: high_contrast}
        
      :animation ->
        # Toggle animation
        if state.sample_animation do
          AnimationFramework.stop_animation(state.sample_animation)
          %{state | sample_animation: nil}
        else
          # Create and start a new animation
          animation = create_demo_animation(state.animation_speed, state.reduced_motion)
          AnimationFramework.start_animation(animation)
          %{state | sample_animation: animation, loading_progress: 0}
        end
        
      :user_preferences ->
        # Save preferences
        UserPreferences.save()
        Accessibility.announce_to_screen_reader(I18n.t("demo.preferences_saved"))
        %{state | preferences_saved: true}
        
      _ -> state
    end
  end
  
  defp handle_key(:tab, state) do
    # Toggle reduced motion
    reduced_motion = !state.reduced_motion
    Accessibility.set_reduced_motion(reduced_motion)
    
    # Update any running animation
    if state.sample_animation do
      AnimationFramework.stop_animation(state.sample_animation)
      animation = create_demo_animation(state.animation_speed, reduced_motion)
      AnimationFramework.start_animation(animation)
      %{state | reduced_motion: reduced_motion, sample_animation: animation}
    else
      %{state | reduced_motion: reduced_motion}
    end
  end
  
  defp handle_key(_key, state), do: state
  
  defp create_demo_animation(speed, reduced_motion) do
    # Determine duration based on speed and reduced motion
    base_duration = case speed do
      :slow -> 3000
      :normal -> 1500
      :fast -> 750
    end
    
    # Adjust for reduced motion
    final_duration = if reduced_motion, do: div(base_duration, 4), else: base_duration
    
    # Create animation
    AnimationFramework.create_animation(
      duration: final_duration,
      from: 0,
      to: 100,
      easing: :ease_in_out,
      announce_to_screen_reader: true,
      description: I18n.t("animation.loading")
    )
  end
  
  defp update_animation(state) do
    # If there's an active animation, update its progress
    if state.sample_animation do
      {progress, done} = AnimationFramework.get_current_value(state.sample_animation)
      
      if done do
        # Animation is complete
        %{state | loading_progress: 100, sample_animation: nil}
      else
        # Animation is in progress
        %{state | loading_progress: trunc(progress)}
      end
    else
      state
    end
  end
  
  defp render(state) do
    Terminal.clear()
    
    # Get RTL direction if needed
    direction = if I18n.rtl?(), do: :rtl, else: :ltr
    
    # Print header
    render_header(state)
    
    # Print section navigation
    render_navigation(state)
    
    # Print content based on active section
    render_section_content(state)
    
    # Print footer
    render_footer(state)
  end
  
  defp render_header(state) do
    title = I18n.t("demo.title")
    
    # Use high contrast colors if enabled
    title_color = if state.high_contrast, 
      do: ColorSystem.get_color(:primary, :high_contrast), 
      else: ColorSystem.get_color(:primary)
      
    # Center title
    Terminal.print_centered(title, color: title_color)
    Terminal.println()
    
    # Print horizontal line
    Terminal.print_horizontal_line()
    Terminal.println()
  end
  
  defp render_navigation(state) do
    # Print section tabs
    Enum.with_index(state.sections, fn section, index ->
      # Determine if this section is focused or active
      is_focused = index == state.focus_index
      is_active = section == state.active_section
      
      # Get appropriate colors
      color = cond do
        is_active -> ColorSystem.get_color(:accent)
        is_focused -> ColorSystem.get_color(:primary)
        true -> ColorSystem.get_color(:foreground)
      end
      
      # Get section name
      section_name = I18n.t("section.#{section}")
      
      # Add focus indicator if focused
      displayed_name = if is_focused, do: "> #{section_name} <", else: "  #{section_name}  "
      
      # Print with appropriate styling
      Terminal.print(displayed_name, color: color, bold: is_active || is_focused)
    end)
    
    Terminal.println()
    Terminal.print_horizontal_line()
    Terminal.println("\n")
  end
  
  defp render_section_content(state) do
    case state.active_section do
      :welcome -> render_welcome_section(state)
      :color_system -> render_color_system_section(state)
      :animation -> render_animation_section(state)
      :internationalization -> render_i18n_section(state)
      :user_preferences -> render_preferences_section(state)
      :keyboard_shortcuts -> render_shortcuts_section(state)
      _ -> render_welcome_section(state)
    end
  end
  
  defp render_welcome_section(state) do
    Terminal.println(I18n.t("demo.welcome"), color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    Terminal.println(I18n.t("demo.instructions"))
    Terminal.println()
    
    # Current settings
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}")
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}")
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme}")
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")}")
    Terminal.println()
    
    # Instructions for changing sections
    Terminal.println("• #{I18n.t("demo.instructions")}")
    Terminal.println()
  end
  
  defp render_color_system_section(state) do
    Terminal.println("#{I18n.t("section.color_system")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    
    # Theme selector
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme} (← →)", bold: true)
    Terminal.println()
    
    # High contrast toggle
    high_contrast_color = if state.high_contrast, do: ColorSystem.get_color(:success), else: ColorSystem.get_color(:foreground)
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast} (Space)", color: high_contrast_color)
    Terminal.println()
    
    # Show color swatches
    colors = [:primary, :secondary, :success, :error, :warning, :info, :background, :foreground]
    
    Enum.each(colors, fn color_name ->
      color_value = ColorSystem.get_color(color_name)
      color_name_str = I18n.t("color.#{color_name}")
      
      # Create a color swatch
      swatch = String.duplicate("█", 10)
      
      Terminal.print("#{color_name_str}: ")
      Terminal.print(swatch, color: color_value)
      Terminal.print(" #{color_value}")
      Terminal.println()
    end)
  end
  
  defp render_animation_section(state) do
    Terminal.println("#{I18n.t("section.animation")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    
    # Reduced motion toggle
    reduced_motion_color = if state.reduced_motion, do: ColorSystem.get_color(:success), else: ColorSystem.get_color(:foreground)
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion} (Tab)", color: reduced_motion_color)
    Terminal.println()
    
    # Animation speed selector
    Terminal.println("#{I18n.t("animation.speed")}: #{I18n.t("animation.speed.#{state.animation_speed}")} (← →)")
    Terminal.println()
    
    # Animation control
    if state.sample_animation do
      Terminal.println("#{I18n.t("animation.stop")} (Space)")
    else
      Terminal.println("#{I18n.t("animation.start")} (Space)")
    end
    Terminal.println()
    
    # Progress bar
    if state.loading_progress > 0 do
      progress_width = 50
      completed_chars = trunc(progress_width * state.loading_progress / 100)
      remaining_chars = progress_width - completed_chars
      
      progress_bar = String.duplicate("█", completed_chars) <> String.duplicate("░", remaining_chars)
      
      Terminal.print(progress_bar)
      Terminal.print(" #{state.loading_progress}%")
      Terminal.println()
      
      if state.loading_progress >= 100 do
        Terminal.println("\n#{I18n.t("animation.completed")}", color: ColorSystem.get_color(:success))
      end
    end
  end
  
  defp render_i18n_section(state) do
    Terminal.println("#{I18n.t("section.internationalization")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    
    # Language selector
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")} (← →)", bold: true)
    Terminal.println()
    
    # RTL indicator
    is_rtl = I18n.rtl?()
    rtl_label = if is_rtl, do: "RTL (Right-to-Left)", else: "LTR (Left-to-Right)"
    Terminal.println("Direction: #{rtl_label}")
    Terminal.println()
    
    # Available languages
    Terminal.println("Available Languages:")
    Enum.each(@available_locales, fn locale ->
      indicator = if locale == state.locale, do: "✓ ", else: "  "
      Terminal.println("#{indicator}#{I18n.t("locales.#{locale}")}")
    end)
    Terminal.println()
    
    # Sample translated content
    Terminal.println("------------------")
    Terminal.println("Sample Translated Content:")
    Terminal.println("------------------")
    
    Terminal.println("#{I18n.t("demo.welcome")}")
    Terminal.println("#{I18n.t("demo.instructions")}")
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}")
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}")
  end
  
  defp render_preferences_section(state) do
    Terminal.println("#{I18n.t("section.user_preferences")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    
    # Current preferences
    Terminal.println("Current Preferences:", bold: true)
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}")
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}")
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme}")
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")}")
    Terminal.println()
    
    # Save preferences
    save_color = if state.preferences_saved, do: ColorSystem.get_color(:success), else: ColorSystem.get_color(:foreground)
    Terminal.println("#{I18n.t("demo.save_preferences")} (Space)", color: save_color)
    
    if state.preferences_saved do
      Terminal.println()
      Terminal.println("✓ #{I18n.t("demo.preferences_saved")}", color: ColorSystem.get_color(:success))
    end
  end
  
  defp render_shortcuts_section(state) do
    Terminal.println("#{I18n.t("section.keyboard_shortcuts")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    
    # Shortcut list
    shortcuts = [
      {:toggle_high_contrast, "Alt+H", "keyboard.toggle_high_contrast"},
      {:toggle_reduced_motion, "Alt+M", "keyboard.toggle_reduced_motion"},
      {:next_theme, "Alt+T", "keyboard.next_theme"},
      {:next_language, "Alt+L", "keyboard.next_language"},
      {:save_preferences, "Alt+S", "keyboard.save_preferences"},
      {:exit_demo, "Ctrl+Q", "keyboard.exit_demo"}
    ]
    
    # Header
    Terminal.print(String.pad_trailing("#{I18n.t("keyboard.shortcut")}", 15))
    Terminal.println("#{I18n.t("keyboard.description")}")
    Terminal.println(String.duplicate("-", 50))
    
    # Shortcut rows
    Enum.each(shortcuts, fn {id, key, description_key} ->
      Terminal.print(String.pad_trailing(key, 15))
      Terminal.println(I18n.t(description_key))
    end)
  end
  
  defp render_footer(state) do
    Terminal.println()
    Terminal.print_horizontal_line()
    Terminal.println()
    
    # Exit instruction
    Terminal.println(I18n.t("demo.exit"), color: ColorSystem.get_color(:foreground), dim: true)
  end
end 