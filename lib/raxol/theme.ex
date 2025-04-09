defmodule Raxol.Theme do
  @moduledoc """
  Theming system for Raxol applications.

  This module provides a way to define and apply consistent visual themes
  to Raxol UI components. Themes define colors, spacing, borders, and other
  visual aspects of the UI.

  ## Usage

  ```elixir
  # Create a custom theme
  theme = Raxol.Theme.new(
    name: "Ocean",
    colors: %{
      primary: :blue,
      secondary: :cyan,
      background: :black,
      text: :white
    }
  )

  # Apply theme to a component
  Raxol.Components.button(
    [
      style: Raxol.Theme.button_style(theme, :primary),
      label: "Submit"
    ]
  )
  ```

  ## Built-in Themes

  * `:default` - The default Raxol theme
  * `:dark` - A dark theme with blue accents
  * `:light` - A light theme with dark text
  * `:high_contrast` - A high contrast theme for accessibility
  """

  @type t :: map()

  @doc """
  Creates a new theme with the given options.

  ## Options

  * `:name` - Theme name (default: "Custom")
  * `:colors` - Map of color definitions
  * `:spacing` - Map of spacing values
  * `:borders` - Map of border styles
  * `:sizes` - Map of size definitions

  ## Returns

  A new theme map.

  ## Example

  ```elixir
  Raxol.Theme.new(
    name: "Forest",
    colors: %{
      primary: :green,
      accent: :yellow,
      background: :black,
      text: :white
    }
  )
  ```
  """
  def new(opts \\ []) do
    name = Keyword.get(opts, :name, "Custom")
    colors = Keyword.get(opts, :colors, %{})
    spacing = Keyword.get(opts, :spacing, %{})
    borders = Keyword.get(opts, :borders, %{})
    sizes = Keyword.get(opts, :sizes, %{})

    # Start with default theme
    default_theme = default()

    # Merge custom options
    %{
      name: name,
      colors: Map.merge(default_theme.colors, colors),
      spacing: Map.merge(default_theme.spacing, spacing),
      borders: Map.merge(default_theme.borders, borders),
      sizes: Map.merge(default_theme.sizes, sizes)
    }
  end

  @doc """
  Returns the default theme.

  ## Returns

  The default theme map.

  ## Example

  ```elixir
  theme = Raxol.Theme.default()
  ```
  """
  def default do
    %{
      name: "Default",
      colors: %{
        primary: :blue,
        secondary: :cyan,
        accent: :magenta,
        background: :black,
        text: :white,
        text_dim: :light_black,
        text_accent: :yellow,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :cyan
      },
      spacing: %{
        xs: 1,
        sm: 2,
        md: 3,
        lg: 4,
        xl: 6
      },
      borders: %{
        none: %{border: false},
        normal: %{border: true},
        thick: %{border: true, border_style: :double}
      },
      sizes: %{
        button: %{
          min_width: 8
        },
        input: %{
          width: 20
        },
        modal: %{
          width: 50
        }
      }
    }
  end

  @doc """
  Returns the dark theme.

  ## Returns

  The dark theme map.

  ## Example

  ```elixir
  theme = Raxol.Theme.dark()
  ```
  """
  def dark do
    new(
      name: "Dark",
      colors: %{
        primary: :blue,
        secondary: :cyan,
        accent: :magenta,
        background: :black,
        text: :white,
        text_dim: :light_black,
        text_accent: :light_yellow
      }
    )
  end

  @doc """
  Returns the light theme.

  ## Returns

  The light theme map.

  ## Example

  ```elixir
  theme = Raxol.Theme.light()
  ```
  """
  def light do
    new(
      name: "Light",
      colors: %{
        primary: :blue,
        secondary: :cyan,
        accent: :magenta,
        background: :white,
        text: :black,
        text_dim: :light_black,
        text_accent: :blue,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :cyan
      }
    )
  end

  @doc """
  Returns the high contrast theme for accessibility.

  ## Returns

  The high contrast theme map.

  ## Example

  ```elixir
  theme = Raxol.Theme.high_contrast()
  ```
  """
  def high_contrast do
    new(
      name: "High Contrast",
      colors: %{
        primary: :yellow,
        secondary: :magenta,
        accent: :cyan,
        background: :black,
        text: :white,
        text_dim: :white,
        text_accent: :yellow,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :cyan
      },
      borders: %{
        normal: %{border: true, border_style: :heavy},
        thick: %{border: true, border_style: :double}
      }
    )
  end

  @doc """
  Returns the style for a button based on the given theme and variant.

  ## Parameters

  * `theme` - The theme to use
  * `variant` - Button variant (:primary, :secondary, :success, :warning, :error, :info)
  * `opts` - Additional options for the button style

  ## Options

  * `:size` - Button size (:sm, :md, :lg, default: :md)
  * `:outlined` - Whether the button should have an outlined style (default: false)
  * `:disabled` - Whether the button is disabled (default: false)

  ## Returns

  A style map for use with the button component.

  ## Example

  ```elixir
  style = Raxol.Theme.button_style(theme, :primary, size: :lg)
  ```
  """
  def button_style(theme, variant, opts \\ []) do
    # Extract options
    size = Keyword.get(opts, :size, :md)
    outlined = Keyword.get(opts, :outlined, false)
    disabled = Keyword.get(opts, :disabled, false)

    # Base style
    base_style = %{
      min_width: get_in(theme, [:sizes, :button, :min_width]) || 8
    }

    # Size-based styling
    size_style = case size do
      :sm -> %{padding_left: 1, padding_right: 1}
      :md -> %{padding_left: 2, padding_right: 2}
      :lg -> %{padding_left: 3, padding_right: 3}
      _ -> %{padding_left: 2, padding_right: 2}
    end

    # Variant-based styling
    variant_color = case variant do
      :primary -> theme.colors.primary
      :secondary -> theme.colors.secondary
      :success -> theme.colors.success
      :warning -> theme.colors.warning
      :error -> theme.colors.error
      :info -> theme.colors.info
      _ -> theme.colors.primary
    end

    variant_style = if outlined do
      %{
        fg: variant_color,
        border: true,
        border_fg: variant_color
      }
    else
      %{
        fg: :white,
        bg: variant_color
      }
    end

    # Disabled styling
    disabled_style = if disabled do
      if outlined do
        %{fg: :light_black, border_fg: :light_black}
      else
        %{fg: :light_black, bg: :black}
      end
    else
      %{}
    end

    # Combine all style components
    Map.merge(base_style, size_style)
    |> Map.merge(variant_style)
    |> Map.merge(disabled_style)
  end

  @doc """
  Returns the style for an input field based on the given theme.

  ## Parameters

  * `theme` - The theme to use
  * `opts` - Additional options for the input style

  ## Options

  * `:size` - Input size (:sm, :md, :lg, default: :md)
  * `:focused` - Whether the input is focused (default: false)
  * `:disabled` - Whether the input is disabled (default: false)
  * `:invalid` - Whether the input is invalid (default: false)

  ## Returns

  A style map for use with input components.

  ## Example

  ```elixir
  style = Raxol.Theme.input_style(theme, focused: true)
  ```
  """
  def input_style(theme, opts \\ []) do
    # Extract options
    size = Keyword.get(opts, :size, :md)
    focused = Keyword.get(opts, :focused, false)
    disabled = Keyword.get(opts, :disabled, false)
    invalid = Keyword.get(opts, :invalid, false)

    # Base style
    base_style = %{
      width: get_in(theme, [:sizes, :input, :width]) || 20,
      border: true
    }

    # Size-based styling
    size_style = case size do
      :sm -> %{padding_left: 1, padding_right: 1}
      :md -> %{padding_left: 1, padding_right: 1}
      :lg -> %{padding_left: 2, padding_right: 2}
      _ -> %{padding_left: 1, padding_right: 1}
    end

    # State-based styling
    state_style = cond do
      invalid -> %{border_fg: theme.colors.error}
      focused -> %{border_fg: theme.colors.primary}
      disabled -> %{fg: :light_black, border_fg: :light_black}
      true -> %{}
    end

    # Combine all style components
    Map.merge(base_style, size_style)
    |> Map.merge(state_style)
  end

  @doc """
  Returns the style for a panel based on the given theme and variant.

  ## Parameters

  * `theme` - The theme to use
  * `variant` - Panel variant (:normal, :elevated, :inset, default: :normal)
  * `opts` - Additional options for the panel style

  ## Options

  * `:border` - Border style (:none, :normal, :thick, default: :normal)
  * `:padding` - Padding size (:none, :xs, :sm, :md, :lg, :xl, default: :none)

  ## Returns

  A style map for use with the panel component.

  ## Example

  ```elixir
  style = Raxol.Theme.panel_style(theme, :elevated, padding: :md)
  ```
  """
  def panel_style(theme, variant \\ :normal, opts \\ []) do
    # Extract options
    border_type = Keyword.get(opts, :border, :normal)
    padding_size = Keyword.get(opts, :padding, :none)

    # Base style based on variant
    base_style = case variant do
      :elevated -> %{bg: :light_black}
      :inset -> %{bg: :black}
      _ -> %{}
    end

    # Border style
    border_style = case border_type do
      :none -> %{border: false}
      :normal -> theme.borders.normal
      :thick -> theme.borders.thick
      _ -> %{border: false}
    end

    # Padding style
    padding = if padding_size == :none do
      %{}
    else
      padding_value = get_in(theme, [:spacing, padding_size]) || 0
      %{
        padding_top: padding_value,
        padding_right: padding_value,
        padding_bottom: padding_value,
        padding_left: padding_value
      }
    end

    # Combine all style components
    Map.merge(base_style, border_style)
    |> Map.merge(padding)
  end

  @doc """
  Returns the style for text based on the given theme and variant.

  ## Parameters

  * `theme` - The theme to use
  * `variant` - Text variant (:normal, :dim, :accent, :primary, :success, :warning, :error, :info, default: :normal)
  * `opts` - Additional options for the text style

  ## Options

  * `:bold` - Whether the text should be bold (default: false)
  * `:italic` - Whether the text should be italic (default: false)
  * `:underline` - Whether the text should be underlined (default: false)

  ## Returns

  A style map for use with text elements.

  ## Example

  ```elixir
  style = Raxol.Theme.text_style(theme, :accent, bold: true)
  ```
  """
  def text_style(theme, variant \\ :normal, opts \\ []) do
    # Extract options
    bold = Keyword.get(opts, :bold, false)
    italic = Keyword.get(opts, :italic, false)
    underline = Keyword.get(opts, :underline, false)

    # Variant-based styling
    variant_style = case variant do
      :dim -> %{fg: theme.colors.text_dim}
      :accent -> %{fg: theme.colors.text_accent}
      :primary -> %{fg: theme.colors.primary}
      :success -> %{fg: theme.colors.success}
      :warning -> %{fg: theme.colors.warning}
      :error -> %{fg: theme.colors.error}
      :info -> %{fg: theme.colors.info}
      _ -> %{fg: theme.colors.text}
    end

    # Text decoration styling
    decoration_style = %{}
    decoration_style = if bold, do: Map.put(decoration_style, :bold, true), else: decoration_style
    decoration_style = if italic, do: Map.put(decoration_style, :italic, true), else: decoration_style
    decoration_style = if underline, do: Map.put(decoration_style, :underline, true), else: decoration_style

    # Combine style components
    Map.merge(variant_style, decoration_style)
  end

  @doc """
  Returns the style for a table based on the given theme.

  ## Parameters

  * `theme` - The theme to use
  * `component` - Table component (:table, :header, :row, :cell, :selected_row, default: :table)
  * `opts` - Additional options for the table style

  ## Returns

  A style map for use with table components.

  ## Example

  ```elixir
  header_style = Raxol.Theme.table_style(theme, :header)
  ```
  """
  def table_style(theme, component \\ :table, _opts \\ []) do
    default_style = %{
      border: true,
      fg: theme.colors.text,
      bold: true,
      bg: :light_black
    }

    case component do
      :table -> %{
        border: true
      }
      :header -> default_style
      :row -> %{}
      :cell -> %{
        padding_left: 1,
        padding_right: 1
      }
      :selected_row -> %{
        bg: theme.colors.primary,
        fg: :white
      }
      :zebra_row -> %{
        bg: :light_black
      }
      _ -> %{}
    end
  end

  @doc """
  Applies the theme to a style map, based on a component type.

  This is a convenience function for quickly applying theme-appropriate
  styling to components without having to use the specific style functions.

  ## Parameters

  * `theme` - The theme to use
  * `component` - Component type (:button, :input, :panel, :text, :table)
  * `variant` - Component variant (depends on component type)
  * `style` - Existing style map to merge with themed style

  ## Returns

  A style map with theme applied.

  ## Example

  ```elixir
  style = %{width: 30}
  themed_style = Raxol.Theme.apply(theme, :button, :primary, style)
  ```
  """
  def apply(theme, component, variant \\ :normal, style \\ %{}) do
    themed_style = case component do
      :button -> button_style(theme, variant)
      :input -> input_style(theme)
      :panel -> panel_style(theme, variant)
      :text -> text_style(theme, variant)
      :table -> table_style(theme, variant)
      _ -> %{}
    end

    Map.merge(themed_style, style)
  end
end
