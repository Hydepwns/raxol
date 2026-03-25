defmodule Raxol.LiveView.Themes do
  @moduledoc """
  Theme system for Raxol web terminals.

  Provides terminal color schemes optimized for readability
  and aesthetics in web browsers. All themes are sourced from
  the unified `Raxol.Core.Theming.ThemeRegistry`.

  ## Usage

      # Get a built-in theme
      {:ok, theme} = Raxol.LiveView.Themes.get_theme(:synthwave84)

      # Or use the unsafe version (returns theme or nil)
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
  alias Raxol.Core.Theming.ThemeRegistry

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
  def get(name) when is_atom(name) do
    ThemeRegistry.to_liveview_format(name)
  end

  def get(_), do: nil

  @doc """
  Returns a built-in theme by name.

  Returns `{:ok, theme}` on success or `{:error, :theme_not_found}` if the theme doesn't exist.
  """
  def get_theme(name) when is_atom(name) do
    case ThemeRegistry.to_liveview_format(name) do
      nil ->
        Log.warning("Unknown theme requested: #{inspect(name)}",
          module: __MODULE__,
          function: :get_theme,
          available_themes: list()
        )

        {:error, :theme_not_found}

      theme ->
        {:ok, theme}
    end
  end

  def get_theme(_), do: {:error, :theme_not_found}

  @doc """
  Lists all available theme names.
  """
  def list do
    ThemeRegistry.list()
  end

  @doc """
  Lists all themes with display names.
  """
  def list_with_names do
    ThemeRegistry.list_with_names()
  end

  @doc """
  Validates a theme structure.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
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

  @doc """
  Generates CSS variables for a theme (modern CSS approach).
  """
  def to_css_variables(theme_name) when is_atom(theme_name) do
    case ThemeRegistry.get(theme_name) do
      {:ok, theme} ->
        """
        :root {
          --raxol-bg: #{theme.ui.background};
          --raxol-fg: #{theme.ui.foreground};
          --raxol-cursor: #{theme.ui.cursor};
          --raxol-selection: #{theme.ui.selection};
          --raxol-black: #{theme.colors.black};
          --raxol-red: #{theme.colors.red};
          --raxol-green: #{theme.colors.green};
          --raxol-yellow: #{theme.colors.yellow};
          --raxol-blue: #{theme.colors.blue};
          --raxol-magenta: #{theme.colors.magenta};
          --raxol-cyan: #{theme.colors.cyan};
          --raxol-white: #{theme.colors.white};
          --raxol-bright-black: #{theme.colors.bright_black};
          --raxol-bright-red: #{theme.colors.bright_red};
          --raxol-bright-green: #{theme.colors.bright_green};
          --raxol-bright-yellow: #{theme.colors.bright_yellow};
          --raxol-bright-blue: #{theme.colors.bright_blue};
          --raxol-bright-magenta: #{theme.colors.bright_magenta};
          --raxol-bright-cyan: #{theme.colors.bright_cyan};
          --raxol-bright-white: #{theme.colors.bright_white};
        }
        """

      {:error, _} ->
        ""
    end
  end

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
end
