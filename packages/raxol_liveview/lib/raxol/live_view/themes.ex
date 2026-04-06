defmodule Raxol.LiveView.Themes do
  @moduledoc """
  Built-in color themes for the Raxol LiveView terminal renderer.

  Each theme is a map of named color slots. Use `get/1` to retrieve a theme
  and `to_css_vars/1` to produce a CSS custom-property string suitable for
  an inline `style` attribute.

  ## Built-in themes

    * `:default`     -- dark background, light foreground
    * `:light`       -- light background, dark foreground
    * `:nord`        -- Arctic, north-bluish palette
    * `:dracula`     -- popular purple-accented dark theme
    * `:synthwave84` -- retro neon synthwave

  ## Example

      css = Raxol.LiveView.Themes.to_css_vars(:nord)
      # "--raxol-bg: #2e3440; --raxol-fg: #eceff4; ..."
  """

  @type color :: String.t()
  @type theme_map :: %{
          bg: color(),
          fg: color(),
          cursor: color(),
          black: color(),
          red: color(),
          green: color(),
          yellow: color(),
          blue: color(),
          magenta: color(),
          cyan: color(),
          white: color(),
          bright_black: color(),
          bright_red: color(),
          bright_green: color(),
          bright_yellow: color(),
          bright_blue: color(),
          bright_magenta: color(),
          bright_cyan: color(),
          bright_white: color()
        }

  @themes %{
    default: %{
      bg: "#1a1a2e",
      fg: "#e0e0e0",
      cursor: "#f0f0f0",
      black: "#000000",
      red: "#ff0000",
      green: "#00ff00",
      yellow: "#ffff00",
      blue: "#0000ff",
      magenta: "#ff00ff",
      cyan: "#00ffff",
      white: "#ffffff",
      bright_black: "#808080",
      bright_red: "#ff8080",
      bright_green: "#80ff80",
      bright_yellow: "#ffff80",
      bright_blue: "#8080ff",
      bright_magenta: "#ff80ff",
      bright_cyan: "#80ffff",
      bright_white: "#ffffff"
    },
    light: %{
      bg: "#fafafa",
      fg: "#383a42",
      cursor: "#526eff",
      black: "#383a42",
      red: "#e45649",
      green: "#50a14f",
      yellow: "#c18401",
      blue: "#4078f2",
      magenta: "#a626a4",
      cyan: "#0184bc",
      white: "#fafafa",
      bright_black: "#4f525e",
      bright_red: "#e06c75",
      bright_green: "#98c379",
      bright_yellow: "#e5c07b",
      bright_blue: "#61afef",
      bright_magenta: "#c678dd",
      bright_cyan: "#56b6c2",
      bright_white: "#ffffff"
    },
    nord: %{
      bg: "#2e3440",
      fg: "#eceff4",
      cursor: "#d8dee9",
      black: "#3b4252",
      red: "#bf616a",
      green: "#a3be8c",
      yellow: "#ebcb8b",
      blue: "#81a1c1",
      magenta: "#b48ead",
      cyan: "#88c0d0",
      white: "#e5e9f0",
      bright_black: "#4c566a",
      bright_red: "#bf616a",
      bright_green: "#a3be8c",
      bright_yellow: "#ebcb8b",
      bright_blue: "#81a1c1",
      bright_magenta: "#b48ead",
      bright_cyan: "#8fbcbb",
      bright_white: "#eceff4"
    },
    dracula: %{
      bg: "#282a36",
      fg: "#f8f8f2",
      cursor: "#f8f8f2",
      black: "#21222c",
      red: "#ff5555",
      green: "#50fa7b",
      yellow: "#f1fa8c",
      blue: "#bd93f9",
      magenta: "#ff79c6",
      cyan: "#8be9fd",
      white: "#f8f8f2",
      bright_black: "#6272a4",
      bright_red: "#ff6e6e",
      bright_green: "#69ff94",
      bright_yellow: "#ffffa5",
      bright_blue: "#d6acff",
      bright_magenta: "#ff92df",
      bright_cyan: "#a4ffff",
      bright_white: "#ffffff"
    },
    synthwave84: %{
      bg: "#262335",
      fg: "#ffffff",
      cursor: "#ff7edb",
      black: "#1a1a2e",
      red: "#fe4450",
      green: "#72f1b8",
      yellow: "#fede5d",
      blue: "#03edf9",
      magenta: "#ff7edb",
      cyan: "#03edf9",
      white: "#ffffff",
      bright_black: "#495495",
      bright_red: "#fe4450",
      bright_green: "#72f1b8",
      bright_yellow: "#fede5d",
      bright_blue: "#03edf9",
      bright_magenta: "#ff7edb",
      bright_cyan: "#03edf9",
      bright_white: "#ffffff"
    }
  }

  @doc """
  Returns the theme map for the given theme name.

  Falls back to `:default` when the name is not recognised.

  ## Examples

      iex> theme = Raxol.LiveView.Themes.get(:nord)
      iex> theme.bg
      "#2e3440"

      iex> Raxol.LiveView.Themes.get(:unknown) == Raxol.LiveView.Themes.get(:default)
      true
  """
  @spec get(atom()) :: theme_map()
  def get(theme_name) do
    Map.get(@themes, theme_name, @themes.default)
  end

  @doc """
  Returns a list of all built-in theme names.

  ## Examples

      iex> :default in Raxol.LiveView.Themes.list()
      true
  """
  @spec list() :: [atom()]
  def list, do: Map.keys(@themes)

  @doc """
  Produces a CSS custom-property string for the given theme.

  The returned string is suitable for use in an inline `style` attribute
  and sets `--raxol-bg`, `--raxol-fg`, `--raxol-cursor`, plus all 16
  named color properties.

  ## Examples

      iex> css = Raxol.LiveView.Themes.to_css_vars(:default)
      iex> css =~ "--raxol-bg:"
      true
  """
  @spec to_css_vars(atom()) :: String.t()
  def to_css_vars(theme_name) do
    theme = get(theme_name)

    [
      "--raxol-bg: #{theme.bg}",
      "--raxol-fg: #{theme.fg}",
      "--raxol-cursor: #{theme.cursor}",
      "--raxol-black: #{theme.black}",
      "--raxol-red: #{theme.red}",
      "--raxol-green: #{theme.green}",
      "--raxol-yellow: #{theme.yellow}",
      "--raxol-blue: #{theme.blue}",
      "--raxol-magenta: #{theme.magenta}",
      "--raxol-cyan: #{theme.cyan}",
      "--raxol-white: #{theme.white}",
      "--raxol-bright-black: #{theme.bright_black}",
      "--raxol-bright-red: #{theme.bright_red}",
      "--raxol-bright-green: #{theme.bright_green}",
      "--raxol-bright-yellow: #{theme.bright_yellow}",
      "--raxol-bright-blue: #{theme.bright_blue}",
      "--raxol-bright-magenta: #{theme.bright_magenta}",
      "--raxol-bright-cyan: #{theme.bright_cyan}",
      "--raxol-bright-white: #{theme.bright_white}"
    ]
    |> Enum.join("; ")
    |> Kernel.<>(";")
  end
end
