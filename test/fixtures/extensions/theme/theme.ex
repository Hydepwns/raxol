defmodule Raxol.Terminal.Extension.Theme do
  @moduledoc '''
  A test theme extension for the Raxol terminal emulator.
  '''

  def get_theme_info do
    %{
      name: "Test Theme",
      version: "1.0.0",
      description: "A test theme extension",
      author: "Test Author",
      license: "MIT",
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
        blink: true,
        blink_rate: 500
      },
      padding: %{
        top: 10,
        right: 10,
        bottom: 10,
        left: 10
      }
    }
  end

  def apply_theme(config) do
    # Merge default theme with config
    theme = Map.merge(get_theme_info(), config)

    # Apply theme settings
    {:ok,
     %{
       colors: theme.colors,
       font: theme.font,
       cursor: theme.cursor,
       padding: theme.padding
     }}
  end

  def update_theme(config) do
    # Update theme settings
    {:ok, apply_theme(config)}
  end
end
