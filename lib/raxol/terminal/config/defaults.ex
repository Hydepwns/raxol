defmodule Raxol.Terminal.Config.Defaults do
  @moduledoc """
  Default terminal configuration values.

  Provides functions for generating default terminal configurations.
  """

  @doc """
  Generates a default configuration based on terminal capabilities.

  ## Returns

  A map containing default configuration values for all settings.
  """
  def generate_default_config do
    %{
      display: default_display_config(),
      input: default_input_config(),
      rendering: default_rendering_config(),
      ansi: default_ansi_config(),
      behavior: default_behavior_config()
    }
  end

  @doc """
  Generates a default display configuration.

  ## Returns

  A map containing default display configuration values.
  """
  def default_display_config do
    %{
      width: 80,
      height: 24,
      colors: 256,
      truecolor: false,
      unicode: true,
      title: "Raxol Terminal",
      font_family: "monospace",
      font_size: 14,
      cursor_style: :block,
      cursor_blink: true
    }
  end

  @doc """
  Generates a default input configuration.

  ## Returns

  A map containing default input configuration values.
  """
  def default_input_config do
    %{
      mouse: true,
      keyboard: true,
      escape_timeout: 100,
      alt_sends_esc: true,
      backspace_sends_backspace: true,
      clipboard: true,
      paste_mode: :bracketed
    }
  end

  @doc """
  Generates a default rendering configuration.

  ## Returns

  A map containing default rendering configuration values.
  """
  def default_rendering_config do
    %{
      fps: 60,
      double_buffer: true,
      redraw_mode: :incremental,
      optimize_empty_cells: true,
      smooth_resize: true,
      cell_width: 8,
      cell_height: 16,
      line_height: 1.2
    }
  end

  @doc """
  Generates a default ANSI configuration.

  ## Returns

  A map containing default ANSI configuration values.
  """
  def default_ansi_config do
    %{
      enabled: true,
      color_mode: :extended,
      interpret_control_codes: true,
      enable_c1_codes: false,
      enable_vt52_mode: false,
      graphics_mode: true,
      colors: %{
        black: "#000000",
        red: "#cd0000",
        green: "#00cd00",
        yellow: "#cdcd00",
        blue: "#0000ee",
        magenta: "#cd00cd",
        cyan: "#00cdcd",
        white: "#e5e5e5",
        bright_black: "#7f7f7f",
        bright_red: "#ff0000",
        bright_green: "#00ff00",
        bright_yellow: "#ffff00",
        bright_blue: "#5c5cff",
        bright_magenta: "#ff00ff",
        bright_cyan: "#00ffff",
        bright_white: "#ffffff"
      }
    }
  end

  @doc """
  Generates a default behavior configuration.

  ## Returns

  A map containing default behavior configuration values.
  """
  def default_behavior_config do
    %{
      scrollback_lines: 10000,
      save_history: true,
      history_file: "~/.raxol_history",
      exit_on_close: false,
      confirm_exit: true,
      bell_style: :visible,
      silence_bell: false,
      word_separators: " \t\"'`()[]{}<>|",
      auto_wrap: true,
      scroll_on_output: false,
      scroll_on_keystroke: true
    }
  end

  @doc """
  Returns a minimal configuration with only essential settings.

  This is useful for testing or scenarios where minimal resources are required.

  ## Returns

  A map containing minimal configuration values.
  """
  def minimal_config do
    %{
      display: %{
        width: 80,
        height: 24,
        colors: 16,
        truecolor: false,
        unicode: false
      },
      input: %{
        mouse: false,
        keyboard: true,
        escape_timeout: 100
      },
      rendering: %{
        fps: 30,
        double_buffer: false,
        redraw_mode: :full
      },
      ansi: %{
        enabled: true,
        color_mode: :basic
      },
      behavior: %{
        scrollback_lines: 1000,
        save_history: false,
        auto_wrap: true
      }
    }
  end
end
