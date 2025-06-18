defmodule Raxol.Terminal.Plugin.Theme do
  @moduledoc '''
  Test theme plugin for the Raxol terminal emulator.
  '''

  def apply_theme(config) do
    # Default theme configuration
    default_config = %{
      colors: %{
        background: "#000000",
        foreground: "#ffffff",
        cursor: "#ffffff",
        selection: "#444444",
        black: "#000000",
        red: "#ff0000",
        green: "#00ff00",
        yellow: "#ffff00",
        blue: "#0000ff",
        magenta: "#ff00ff",
        cyan: "#00ffff",
        white: "#ffffff",
        bright_black: "#666666",
        bright_red: "#ff6666",
        bright_green: "#66ff66",
        bright_yellow: "#ffff66",
        bright_blue: "#6666ff",
        bright_magenta: "#ff66ff",
        bright_cyan: "#66ffff",
        bright_white: "#ffffff"
      },
      font: %{
        family: "monospace",
        size: 12,
        weight: "normal",
        style: "normal"
      },
      cursor: %{
        style: "block",
        blink: true
      },
      padding: %{
        x: 10,
        y: 10
      }
    }

    # Merge with provided configuration
    config = Map.merge(default_config, config)

    # Apply theme
    {:ok, config}
  end

  def get_theme_info do
    %{
      name: "Test Theme",
      version: "1.0.0",
      description: "A test theme for the Raxol terminal emulator",
      author: "Test Author",
      license: "MIT"
    }
  end
end
