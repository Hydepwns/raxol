defmodule Raxol.LiveView.Themes do
  @moduledoc """
  Built-in theme system for Raxol web terminals.

  Provides curated terminal color schemes optimized for readability
  and aesthetics in web browsers.

  ## Usage

      # Get a built-in theme
      {:ok, theme} = Raxol.LiveView.Themes.get_theme(:synthwave84)

      # Or use the unsafe version (returns theme or default)
      theme = Raxol.LiveView.Themes.get(:synthwave84)

      # Validate a custom theme
      case Raxol.LiveView.Themes.validate_theme(custom_theme) do
        :ok -> # theme is valid
        {:error, reason} -> # handle error
      end

      # Generate CSS for a theme
      css = Raxol.LiveView.Themes.to_css(theme)

      # List available themes
      themes = Raxol.LiveView.Themes.list()
  """

  alias Raxol.Core.Runtime.Log

  @type theme :: %{
          name: atom(),
          background: String.t(),
          foreground: String.t(),
          cursor: String.t(),
          selection: String.t(),
          colors: %{
            black: String.t(),
            red: String.t(),
            green: String.t(),
            yellow: String.t(),
            blue: String.t(),
            magenta: String.t(),
            cyan: String.t(),
            white: String.t(),
            bright_black: String.t(),
            bright_red: String.t(),
            bright_green: String.t(),
            bright_yellow: String.t(),
            bright_blue: String.t(),
            bright_magenta: String.t(),
            bright_cyan: String.t(),
            bright_white: String.t()
          }
        }

  @doc """
  Returns a built-in theme by name, or nil if not found.

  For a version that returns `{:ok, theme} | {:error, reason}`, use `get_theme/1`.
  """
  @spec get(atom()) :: theme() | nil
  def get(name) when is_atom(name) do
    case get_theme(name) do
      {:ok, theme} -> theme
      {:error, _} -> nil
    end
  end

  def get(_), do: nil

  @doc """
  Returns a built-in theme by name.

  Returns `{:ok, theme}` on success or `{:error, :theme_not_found}` if the theme doesn't exist.
  """
  @spec get_theme(atom()) :: {:ok, theme()} | {:error, :theme_not_found}
  def get_theme(:synthwave84), do: {:ok, synthwave84()}
  def get_theme(:nord), do: {:ok, nord()}
  def get_theme(:dracula), do: {:ok, dracula()}
  def get_theme(:monokai), do: {:ok, monokai()}
  def get_theme(:gruvbox), do: {:ok, gruvbox()}
  def get_theme(:solarized_dark), do: {:ok, solarized_dark()}
  def get_theme(:tokyo_night), do: {:ok, tokyo_night()}

  def get_theme(name) when is_atom(name) do
    Log.warning("Unknown theme requested: #{inspect(name)}",
      module: __MODULE__,
      function: :get_theme,
      available_themes: list()
    )

    {:error, :theme_not_found}
  end

  def get_theme(_), do: {:error, :theme_not_found}

  @doc """
  Lists all available theme names.
  """
  @spec list() :: [atom()]
  def list do
    [
      :synthwave84,
      :nord,
      :dracula,
      :monokai,
      :gruvbox,
      :solarized_dark,
      :tokyo_night
    ]
  end

  @doc """
  Validates a theme structure.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
  @spec validate_theme(any()) :: :ok | {:error, atom()}
  def validate_theme(%{
        name: _,
        background: _,
        foreground: _,
        cursor: _,
        selection: _,
        colors: colors
      })
      when is_map(colors) do
    required_colors = [
      :black,
      :red,
      :green,
      :yellow,
      :blue,
      :magenta,
      :cyan,
      :white,
      :bright_black,
      :bright_red,
      :bright_green,
      :bright_yellow,
      :bright_blue,
      :bright_magenta,
      :bright_cyan,
      :bright_white
    ]

    missing_colors = Enum.reject(required_colors, &Map.has_key?(colors, &1))

    case missing_colors do
      [] -> :ok
      missing -> {:error, {:missing_colors, missing}}
    end
  end

  def validate_theme(_), do: {:error, :invalid_theme_structure}

  @doc """
  Generates CSS for a theme.

  Returns CSS as a string that can be injected into a page or style tag.
  If the theme is invalid, returns minimal fallback CSS and logs a warning.
  """
  @spec to_css(theme(), String.t()) :: String.t()
  def to_css(theme, selector \\ ".raxol-terminal")

  def to_css(theme, selector) when is_map(theme) do
    case validate_theme(theme) do
      :ok ->
        generate_theme_css(theme, selector)

      {:error, reason} ->
        Log.warning("Invalid theme provided to to_css: #{inspect(reason)}",
          module: __MODULE__,
          function: :to_css
        )

        generate_fallback_css(selector)
    end
  end

  def to_css(_, selector) do
    Log.error("to_css called with non-map theme",
      module: __MODULE__,
      function: :to_css
    )

    generate_fallback_css(selector)
  end

  @spec generate_theme_css(theme(), String.t()) :: String.t()
  defp generate_theme_css(theme, selector) do
    """
    #{selector} {
      background-color: #{theme.background};
      color: #{theme.foreground};
    }

    #{selector} .raxol-cursor {
      background-color: #{theme.cursor};
    }

    #{selector} ::selection {
      background-color: #{theme.selection};
    }

    /* Standard colors */
    #{selector} .raxol-fg-black { color: #{theme.colors.black}; }
    #{selector} .raxol-fg-red { color: #{theme.colors.red}; }
    #{selector} .raxol-fg-green { color: #{theme.colors.green}; }
    #{selector} .raxol-fg-yellow { color: #{theme.colors.yellow}; }
    #{selector} .raxol-fg-blue { color: #{theme.colors.blue}; }
    #{selector} .raxol-fg-magenta { color: #{theme.colors.magenta}; }
    #{selector} .raxol-fg-cyan { color: #{theme.colors.cyan}; }
    #{selector} .raxol-fg-white { color: #{theme.colors.white}; }

    /* Bright colors */
    #{selector} .raxol-fg-bright-black { color: #{theme.colors.bright_black}; }
    #{selector} .raxol-fg-bright-red { color: #{theme.colors.bright_red}; }
    #{selector} .raxol-fg-bright-green { color: #{theme.colors.bright_green}; }
    #{selector} .raxol-fg-bright-yellow { color: #{theme.colors.bright_yellow}; }
    #{selector} .raxol-fg-bright-blue { color: #{theme.colors.bright_blue}; }
    #{selector} .raxol-fg-bright-magenta { color: #{theme.colors.bright_magenta}; }
    #{selector} .raxol-fg-bright-cyan { color: #{theme.colors.bright_cyan}; }
    #{selector} .raxol-fg-bright-white { color: #{theme.colors.bright_white}; }

    /* Background colors */
    #{selector} .raxol-bg-black { background-color: #{theme.colors.black}; }
    #{selector} .raxol-bg-red { background-color: #{theme.colors.red}; }
    #{selector} .raxol-bg-green { background-color: #{theme.colors.green}; }
    #{selector} .raxol-bg-yellow { background-color: #{theme.colors.yellow}; }
    #{selector} .raxol-bg-blue { background-color: #{theme.colors.blue}; }
    #{selector} .raxol-bg-magenta { background-color: #{theme.colors.magenta}; }
    #{selector} .raxol-bg-cyan { background-color: #{theme.colors.cyan}; }
    #{selector} .raxol-bg-white { background-color: #{theme.colors.white}; }

    /* Text styles */
    #{selector} .raxol-bold { font-weight: bold; }
    #{selector} .raxol-italic { font-style: italic; }
    #{selector} .raxol-underline { text-decoration: underline; }
    #{selector} .raxol-reverse {
      filter: invert(1);
    }
    """
  end

  @spec generate_fallback_css(String.t()) :: String.t()
  defp generate_fallback_css(selector) do
    """
    #{selector} {
      background-color: #1a1a1a;
      color: #ffffff;
    }
    #{selector} .raxol-cell {
      color: #ffffff;
    }
    """
  end

  # Theme Definitions

  defp synthwave84 do
    %{
      name: :synthwave84,
      background: "#2b213a",
      foreground: "#f0eff1",
      cursor: "#f890e7",
      selection: "#495495",
      colors: %{
        black: "#2b213a",
        red: "#fe4450",
        green: "#72f1b8",
        yellow: "#fede5d",
        blue: "#03edf9",
        magenta: "#ff7edb",
        cyan: "#03edf9",
        white: "#f0eff1",
        bright_black: "#534267",
        bright_red: "#fe4450",
        bright_green: "#72f1b8",
        bright_yellow: "#fede5d",
        bright_blue: "#03edf9",
        bright_magenta: "#f890e7",
        bright_cyan: "#03edf9",
        bright_white: "#ffffff"
      }
    }
  end

  defp nord do
    %{
      name: :nord,
      background: "#2e3440",
      foreground: "#d8dee9",
      cursor: "#88c0d0",
      selection: "#434c5e",
      colors: %{
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
      }
    }
  end

  defp dracula do
    %{
      name: :dracula,
      background: "#282a36",
      foreground: "#f8f8f2",
      cursor: "#ff79c6",
      selection: "#44475a",
      colors: %{
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
      }
    }
  end

  defp monokai do
    %{
      name: :monokai,
      background: "#272822",
      foreground: "#f8f8f2",
      cursor: "#f8f8f0",
      selection: "#49483e",
      colors: %{
        black: "#272822",
        red: "#f92672",
        green: "#a6e22e",
        yellow: "#f4bf75",
        blue: "#66d9ef",
        magenta: "#ae81ff",
        cyan: "#a1efe4",
        white: "#f8f8f2",
        bright_black: "#75715e",
        bright_red: "#f92672",
        bright_green: "#a6e22e",
        bright_yellow: "#f4bf75",
        bright_blue: "#66d9ef",
        bright_magenta: "#ae81ff",
        bright_cyan: "#a1efe4",
        bright_white: "#f9f8f5"
      }
    }
  end

  defp gruvbox do
    %{
      name: :gruvbox,
      background: "#282828",
      foreground: "#ebdbb2",
      cursor: "#fe8019",
      selection: "#504945",
      colors: %{
        black: "#282828",
        red: "#cc241d",
        green: "#98971a",
        yellow: "#d79921",
        blue: "#458588",
        magenta: "#b16286",
        cyan: "#689d6a",
        white: "#a89984",
        bright_black: "#928374",
        bright_red: "#fb4934",
        bright_green: "#b8bb26",
        bright_yellow: "#fabd2f",
        bright_blue: "#83a598",
        bright_magenta: "#d3869b",
        bright_cyan: "#8ec07c",
        bright_white: "#ebdbb2"
      }
    }
  end

  defp solarized_dark do
    %{
      name: :solarized_dark,
      background: "#002b36",
      foreground: "#839496",
      cursor: "#93a1a1",
      selection: "#073642",
      colors: %{
        black: "#073642",
        red: "#dc322f",
        green: "#859900",
        yellow: "#b58900",
        blue: "#268bd2",
        magenta: "#d33682",
        cyan: "#2aa198",
        white: "#eee8d5",
        bright_black: "#002b36",
        bright_red: "#cb4b16",
        bright_green: "#586e75",
        bright_yellow: "#657b83",
        bright_blue: "#839496",
        bright_magenta: "#6c71c4",
        bright_cyan: "#93a1a1",
        bright_white: "#fdf6e3"
      }
    }
  end

  defp tokyo_night do
    %{
      name: :tokyo_night,
      background: "#1a1b26",
      foreground: "#c0caf5",
      cursor: "#c0caf5",
      selection: "#33467c",
      colors: %{
        black: "#15161e",
        red: "#f7768e",
        green: "#9ece6a",
        yellow: "#e0af68",
        blue: "#7aa2f7",
        magenta: "#bb9af7",
        cyan: "#7dcfff",
        white: "#a9b1d6",
        bright_black: "#414868",
        bright_red: "#f7768e",
        bright_green: "#9ece6a",
        bright_yellow: "#e0af68",
        bright_blue: "#7aa2f7",
        bright_magenta: "#bb9af7",
        bright_cyan: "#7dcfff",
        bright_white: "#c0caf5"
      }
    }
  end
end
