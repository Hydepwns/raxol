defmodule Raxol.Examples.Demos.IntegratedAccessibilityDemo do
  @moduledoc """
  Demo showcasing accessibility features including screen reader support,
  high contrast mode, and keyboard navigation.
  """

  alias Raxol.Core.Events.Event

  @type t :: %__MODULE__{
          mode: :menu | :contrast | :screen_reader | :navigation,
          selected_option: non_neg_integer(),
          contrast_level: :normal | :high | :highest,
          screen_reader_enabled: boolean(),
          navigation_mode: :standard | :vim,
          announcements: [String.t()]
        }

  defstruct mode: :menu,
            selected_option: 0,
            contrast_level: :normal,
            screen_reader_enabled: false,
            navigation_mode: :standard,
            announcements: []

  @doc """
  Initializes the accessibility demo.
  """
  @spec init(keyword()) :: {:ok, {t(), list()}}
  def init(_opts \\ []) do
    state = %__MODULE__{
      announcements: ["Welcome to the Accessibility Demo"]
    }

    commands = [
      {:announce, "Welcome to the Accessibility Demo. Press H for help."}
    ]

    {:ok, {state, commands}}
  end

  @doc """
  Updates the demo state based on events.
  """
  @spec update(Event.t(), t()) :: {t(), list()}
  def update(%Event{type: :key, data: %{key: key}}, state) do
    case {state.mode, key} do
      # Global navigation
      {_, "q"} ->
        {state, [{:exit}]}

      # Menu mode navigation
      {:menu, "h"} ->
        show_help(state)

      {:menu, "1"} ->
        {%{state | mode: :contrast}, [{:announce, "Contrast settings mode"}]}

      {:menu, "2"} ->
        {%{state | mode: :screen_reader},
         [{:announce, "Screen reader settings"}]}

      {:menu, "3"} ->
        {%{state | mode: :navigation}, [{:announce, "Navigation settings"}]}

      {:menu, :escape} ->
        {state, [{:exit}]}

      # Contrast mode
      {:contrast, "n"} ->
        set_contrast(state, :normal)

      {:contrast, "c"} ->
        set_contrast(state, :high)

      {:contrast, "x"} ->
        set_contrast(state, :highest)

      {:contrast, "h"} ->
        show_help(state)

      {:contrast, :escape} ->
        {%{state | mode: :menu}, [{:announce, "Back to main menu"}]}

      # Screen reader mode
      {:screen_reader, "e"} ->
        toggle_screen_reader(state, true)

      {:screen_reader, "d"} ->
        toggle_screen_reader(state, false)

      {:screen_reader, :escape} ->
        {%{state | mode: :menu}, [{:announce, "Back to main menu"}]}

      # Navigation mode
      {:navigation, "s"} ->
        set_navigation(state, :standard)

      {:navigation, "v"} ->
        set_navigation(state, :vim)

      {:navigation, :escape} ->
        {%{state | mode: :menu}, [{:announce, "Back to main menu"}]}

      # Default - no action
      _ ->
        {state, []}
    end
  end

  def update(_event, state), do: {state, []}

  @doc """
  Renders the current view.
  """
  @spec view(t()) :: iolist()
  def view(state) do
    case state.mode do
      :menu -> render_menu(state)
      :contrast -> render_contrast_settings(state)
      :screen_reader -> render_screen_reader_settings(state)
      :navigation -> render_navigation_settings(state)
    end
  end

  # Private functions

  defp show_help(state) do
    help_text = """
    Accessibility Demo Help:

    Main Menu:
      1 - Contrast Settings
      2 - Screen Reader Settings
      3 - Navigation Settings
      Q - Quit
      H - Show this help

    In Settings:
      ESC - Return to main menu

    Current Status:
      Contrast: #{state.contrast_level}
      Screen Reader: #{if state.screen_reader_enabled, do: "Enabled", else: "Disabled"}
      Navigation: #{state.navigation_mode}
    """

    announcement = "Help displayed. Press any key to continue."
    {state, [{:announce, announcement}, {:display, help_text}]}
  end

  defp set_contrast(state, level) do
    state = %{state | contrast_level: level}
    announcement = "Contrast level set to #{level}"

    commands = [
      {:announce, announcement},
      {:set_contrast, level}
    ]

    {state, commands}
  end

  defp toggle_screen_reader(state, enabled) do
    state = %{state | screen_reader_enabled: enabled}
    status = if enabled, do: "enabled", else: "disabled"
    announcement = "Screen reader #{status}"

    commands = [
      {:announce, announcement},
      {:set_screen_reader, enabled}
    ]

    {state, commands}
  end

  defp set_navigation(state, mode) do
    state = %{state | navigation_mode: mode}
    announcement = "Navigation mode set to #{mode}"

    commands = [
      {:announce, announcement},
      {:set_navigation_mode, mode}
    ]

    {state, commands}
  end

  defp render_menu(state) do
    """
    ====================================
        ACCESSIBILITY DEMO
    ====================================

    Main Menu:
      [1] Contrast Settings (#{state.contrast_level})
      [2] Screen Reader (#{if state.screen_reader_enabled, do: "ON", else: "OFF"})
      [3] Navigation Mode (#{state.navigation_mode})

    Press H for help, Q to quit
    ====================================
    """
  end

  defp render_contrast_settings(state) do
    """
    ====================================
        CONTRAST SETTINGS
    ====================================

    Current Level: #{state.contrast_level}

    Options:
      [N] Normal Contrast
      [C] High Contrast
      [X] Highest Contrast
      [H] Help

    Press ESC to return to menu
    ====================================
    """
  end

  defp render_screen_reader_settings(state) do
    """
    ====================================
        SCREEN READER SETTINGS
    ====================================

    Status: #{if state.screen_reader_enabled, do: "ENABLED", else: "DISABLED"}

    Options:
      [E] Enable Screen Reader
      [D] Disable Screen Reader

    Press ESC to return to menu
    ====================================
    """
  end

  defp render_navigation_settings(state) do
    """
    ====================================
        NAVIGATION SETTINGS
    ====================================

    Current Mode: #{state.navigation_mode}

    Options:
      [S] Standard Navigation
      [V] Vim-style Navigation

    Press ESC to return to menu
    ====================================
    """
  end
end
