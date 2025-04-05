defmodule Raxol.Examples.IntegratedAccessibilityDemo do
  @moduledoc """
  An integrated demo showcasing Raxol's accessibility features working together
  with color system, animation framework, and internationalization.
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

  def run do
    initialize_systems()
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
      loading_progress: 0,
      shortcuts: %{
        "Alt+H" => "Toggle High Contrast",
        "Alt+M" => "Toggle Reduced Motion",
        "Alt+T" => "Switch Theme",
        "Alt+L" => "Switch Language",
        "Alt+S" => "Save Preferences",
        "Ctrl+Q" => "Exit Demo"
      }
    }
    demo_loop(state)
  end

  defp initialize_systems do
    Accessibility.init()
    UserPreferences.init()
    ColorSystem.init()
    PaletteManager.init()
    AnimationFramework.init()
    I18n.init(default_locale: "en", available_locales: @available_locales)
    KeyboardShortcuts.init()
    FocusManager.init()
  end

  defp demo_loop(state) do
    render(state)
    updated_state = process_input(state)
    animation_state = update_animation(updated_state)
    demo_loop(animation_state)
  end

  defp process_input(state) do
    case Terminal.read_key(timeout: 100) do
      {:ok, key} -> handle_key(key, state)
      _ -> state
    end
  end

  defp handle_key({:arrow, :up}, state) do
    focus_index = max(0, state.focus_index - 1)
    %{state | focus_index: focus_index}
  end

  defp handle_key({:arrow, :down}, state) do
    focus_index = min(length(state.sections) - 1, state.focus_index + 1)
    %{state | focus_index: focus_index}
  end

  defp handle_key(:enter, state) do
    section = Enum.at(state.sections, state.focus_index)
    %{state | active_section: section}
  end

  defp handle_key(:space, state) do
    case state.active_section do
      :animation ->
        if state.sample_animation do
          AnimationFramework.stop_animation(state.sample_animation)
          %{state | sample_animation: nil}
        else
          animation = create_demo_animation(state.animation_speed, state.reduced_motion)
          AnimationFramework.start_animation(animation)
          %{state | sample_animation: animation, loading_progress: 0}
        end
      _ -> state
    end
  end

  defp handle_key(_key, state), do: state

  defp create_demo_animation(speed, reduced_motion) do
    base_duration = case speed do
      :slow -> 3000
      :normal -> 1500
      :fast -> 750
    end
    final_duration = if reduced_motion, do: div(base_duration, 4), else: base_duration
    AnimationFramework.create_animation(
      duration: final_duration,
      from: 0,
      to: 100,
      easing: :ease_in_out
    )
  end

  defp update_animation(state) do
    if state.sample_animation do
      {progress, done} = AnimationFramework.get_current_value(state.sample_animation)
      if done do
        %{state | loading_progress: 100, sample_animation: nil}
      else
        %{state | loading_progress: trunc(progress)}
      end
    else
      state
    end
  end

  defp render(state) do
    Terminal.clear()
    direction = if I18n.rtl?(), do: :rtl, else: :ltr
    render_header(state, direction)
    render_navigation(state, direction)
    render_section_content(state)
    render_footer(state)
  end

  defp render_header(state, direction) do
    title = I18n.t("demo.title")
    title_color = if state.high_contrast, 
      do: ColorSystem.get_color(:primary, :high_contrast), 
      else: ColorSystem.get_color(:primary)
    Terminal.print_centered(title, color: title_color, direction: direction)
    Terminal.println()
    Terminal.print_horizontal_line()
    Terminal.println()
  end

  defp render_navigation(state, _direction) do
    Enum.with_index(state.sections, fn section, index ->
      is_focused = index == state.focus_index
      is_active = section == state.active_section
      color = cond do
        is_active -> ColorSystem.get_color(:accent)
        is_focused -> ColorSystem.get_color(:primary)
        true -> ColorSystem.get_color(:foreground)
      end
      section_name = I18n.t("section.#{section}")
      displayed_name = if is_focused, do: "> #{section_name} <", else: "  #{section_name}  "
      Terminal.print(displayed_name, color: color, bold: is_active || is_focused)
    end)
    Terminal.println()
    Terminal.print_horizontal_line()
    Terminal.println()
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
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}")
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}")
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme}")
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")}")
    Terminal.println()
  end

  defp render_color_system_section(state) do
    Terminal.println("#{I18n.t("section.color_system")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme}", bold: true)
    Terminal.println()
    high_contrast_color = if state.high_contrast, do: ColorSystem.get_color(:success), else: ColorSystem.get_color(:foreground)
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}", color: high_contrast_color)
    Terminal.println()
  end

  defp render_animation_section(state) do
    Terminal.println("#{I18n.t("section.animation")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    reduced_motion_color = if state.reduced_motion, do: ColorSystem.get_color(:success), else: ColorSystem.get_color(:foreground)
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}", color: reduced_motion_color)
    Terminal.println()
    Terminal.println("#{I18n.t("animation.speed")}: #{state.animation_speed}")
    Terminal.println()
    if state.sample_animation do
      Terminal.println("#{I18n.t("animation.stop")} (Space)")
    else
      Terminal.println("#{I18n.t("animation.start")} (Space)")
    end
    Terminal.println()
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
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")}", bold: true)
    Terminal.println()
    is_rtl = I18n.rtl?()
    rtl_label = if is_rtl, do: "RTL (Right-to-Left)", else: "LTR (Left-to-Right)"
    Terminal.println("Direction: #{rtl_label}")
    Terminal.println()
    Terminal.println("Available Languages:")
    Enum.each(@available_locales, fn locale ->
      indicator = if locale == state.locale, do: "✓ ", else: "  "
      Terminal.println("#{indicator}#{I18n.t("locales.#{locale}")}")
    end)
  end

  defp render_preferences_section(state) do
    Terminal.println("#{I18n.t("section.user_preferences")}", color: ColorSystem.get_color(:primary), bold: true)
    Terminal.println()
    Terminal.println("Current Preferences:", bold: true)
    Terminal.println("#{I18n.t("demo.high_contrast")}: #{state.high_contrast}")
    Terminal.println("#{I18n.t("demo.reduced_motion")}: #{state.reduced_motion}")
    Terminal.println("#{I18n.t("demo.theme")}: #{state.theme}")
    Terminal.println("#{I18n.t("demo.language")}: #{I18n.t("locales.#{state.locale}")}")
    Terminal.println()
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
    Enum.each(state.shortcuts, fn {key, action} ->
      Terminal.println("#{key}: #{action}")
    end)
    Terminal.println()
  end

  defp render_footer(state) do
    Terminal.println()
    Terminal.print_horizontal_line()
    Terminal.println()
    footer_text = if state.show_help do
      I18n.t("demo.exit_with_help")
    else
      I18n.t("demo.exit")
    end
    Terminal.println(footer_text, color: ColorSystem.get_color(:foreground))
  end
end 