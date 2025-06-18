defmodule Raxol.Terminal.Theme.Manager do
  @moduledoc '''
  Manages terminal themes with advanced features:
  - Theme loading from files and presets
  - Theme customization and modification
  - Dynamic theme switching
  - Theme persistence and state management
  '''

  @type color :: %{
          r: integer(),
          g: integer(),
          b: integer(),
          a: float()
        }

  @type style :: %{
          foreground: color(),
          background: color(),
          bold: boolean(),
          italic: boolean(),
          underline: boolean()
        }

  @type theme :: %{
          name: String.t(),
          description: String.t(),
          author: String.t(),
          version: String.t(),
          colors: %{
            background: color(),
            foreground: color(),
            cursor: color(),
            selection: color(),
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
          },
          styles: %{
            normal: style(),
            bold: style(),
            italic: style(),
            underline: style(),
            cursor: style(),
            selection: style()
          }
        }

  @type t :: %__MODULE__{
          current_theme: theme(),
          themes: %{String.t() => theme()},
          custom_styles: %{String.t() => style()},
          metrics: %{
            theme_switches: integer(),
            style_applications: integer(),
            customizations: integer(),
            load_operations: integer()
          }
        }

  defstruct [
    :current_theme,
    :themes,
    :custom_styles,
    :metrics
  ]

  @doc '''
  Creates a new theme manager with the given options.
  '''
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    default_theme = %{
      name: "default",
      description: "Default terminal theme",
      author: "Raxol",
      version: "1.0.0",
      colors: %{
        background: %{r: 0, g: 0, b: 0, a: 1.0},
        foreground: %{r: 255, g: 255, b: 255, a: 1.0},
        cursor: %{r: 255, g: 255, b: 255, a: 1.0},
        selection: %{r: 51, g: 51, b: 51, a: 1.0},
        black: %{r: 0, g: 0, b: 0, a: 1.0},
        red: %{r: 255, g: 0, b: 0, a: 1.0},
        green: %{r: 0, g: 255, b: 0, a: 1.0},
        yellow: %{r: 255, g: 255, b: 0, a: 1.0},
        blue: %{r: 0, g: 0, b: 255, a: 1.0},
        magenta: %{r: 255, g: 0, b: 255, a: 1.0},
        cyan: %{r: 0, g: 255, b: 255, a: 1.0},
        white: %{r: 255, g: 255, b: 255, a: 1.0},
        bright_black: %{r: 128, g: 128, b: 128, a: 1.0},
        bright_red: %{r: 255, g: 128, b: 128, a: 1.0},
        bright_green: %{r: 128, g: 255, b: 128, a: 1.0},
        bright_yellow: %{r: 255, g: 255, b: 128, a: 1.0},
        bright_blue: %{r: 128, g: 128, b: 255, a: 1.0},
        bright_magenta: %{r: 255, g: 128, b: 255, a: 1.0},
        bright_cyan: %{r: 128, g: 255, b: 255, a: 1.0},
        bright_white: %{r: 255, g: 255, b: 255, a: 1.0}
      },
      styles: %{
        normal: %{
          foreground: %{r: 255, g: 255, b: 255, a: 1.0},
          background: %{r: 0, g: 0, b: 0, a: 1.0},
          bold: false,
          italic: false,
          underline: false
        },
        bold: %{
          foreground: %{r: 255, g: 255, b: 255, a: 1.0},
          background: %{r: 0, g: 0, b: 0, a: 1.0},
          bold: true,
          italic: false,
          underline: false
        },
        italic: %{
          foreground: %{r: 255, g: 255, b: 255, a: 1.0},
          background: %{r: 0, g: 0, b: 0, a: 1.0},
          bold: false,
          italic: true,
          underline: false
        },
        underline: %{
          foreground: %{r: 255, g: 255, b: 255, a: 1.0},
          background: %{r: 0, g: 0, b: 0, a: 1.0},
          bold: false,
          italic: false,
          underline: true
        },
        cursor: %{
          foreground: %{r: 0, g: 0, b: 0, a: 1.0},
          background: %{r: 255, g: 255, b: 255, a: 1.0},
          bold: false,
          italic: false,
          underline: false
        },
        selection: %{
          foreground: %{r: 255, g: 255, b: 255, a: 1.0},
          background: %{r: 51, g: 51, b: 51, a: 1.0},
          bold: false,
          italic: false,
          underline: false
        }
      }
    }

    %__MODULE__{
      current_theme: default_theme,
      themes: %{"default" => default_theme},
      custom_styles: %{},
      metrics: %{
        theme_switches: 0,
        style_applications: 0,
        customizations: 0,
        load_operations: 0
      }
    }
  end

  @doc '''
  Loads a theme from a file or preset.
  '''
  @spec load_theme(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def load_theme(manager, theme_name) do
    case Map.get(manager.themes, theme_name) do
      nil ->
        {:error, :theme_not_found}

      theme ->
        updated_manager = %{
          manager
          | current_theme: theme,
            metrics: update_metrics(manager.metrics, :theme_switches)
        }

        {:ok, updated_manager}
    end
  end

  @doc '''
  Adds a custom style to the current theme.
  '''
  @spec add_custom_style(t(), String.t(), style()) ::
          {:ok, t()} | {:error, term()}
  def add_custom_style(manager, name, style) do
    with :ok <- validate_style(style) do
      new_styles = Map.put(manager.custom_styles, name, style)

      updated_manager = %{
        manager
        | custom_styles: new_styles,
          metrics: update_metrics(manager.metrics, :customizations)
      }

      {:ok, updated_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Gets a style from the current theme or custom styles.
  '''
  @spec get_style(t(), String.t()) :: {:ok, style()} | {:error, term()}
  def get_style(manager, style_name) do
    case Map.get(manager.current_theme.styles, style_name) do
      nil ->
        case Map.get(manager.custom_styles, style_name) do
          nil ->
            {:error, :style_not_found}

          style ->
            updated_manager = %{
              manager
              | metrics: update_metrics(manager.metrics, :style_applications)
            }

            {:ok, style, updated_manager}
        end

      style ->
        updated_manager = %{
          manager
          | metrics: update_metrics(manager.metrics, :style_applications)
        }

        {:ok, style, updated_manager}
    end
  end

  @doc '''
  Gets the current theme metrics.
  '''
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  @doc '''
  Saves the current theme state for persistence.
  '''
  @spec save_theme_state(t()) :: {:ok, map()} | {:error, term()}
  def save_theme_state(manager) do
    state = %{
      current_theme: manager.current_theme.name,
      custom_styles: manager.custom_styles
    }

    {:ok, state}
  end

  @doc '''
  Restores a theme state from saved data.
  '''
  @spec restore_theme_state(t(), map()) :: {:ok, t()} | {:error, term()}
  def restore_theme_state(manager, state) do
    with {:ok, manager} <- load_theme(manager, state.current_theme) do
      updated_manager = %{
        manager
        | custom_styles: state.custom_styles,
          metrics: update_metrics(manager.metrics, :load_operations)
      }

      {:ok, updated_manager}
    end
  end

  # Private helper functions

  defp validate_style(style) do
    required_fields = [:foreground, :background, :bold, :italic, :underline]

    if Enum.all?(required_fields, &Map.has_key?(style, &1)) do
      :ok
    else
      {:error, :invalid_style}
    end
  end

  defp update_metrics(metrics, :theme_switches) do
    update_in(metrics.theme_switches, &(&1 + 1))
  end

  defp update_metrics(metrics, :style_applications) do
    update_in(metrics.style_applications, &(&1 + 1))
  end

  defp update_metrics(metrics, :customizations) do
    update_in(metrics.customizations, &(&1 + 1))
  end

  defp update_metrics(metrics, :load_operations) do
    update_in(metrics.load_operations, &(&1 + 1))
  end
end
