defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc """
  Consolidated text formatting module for the terminal emulator.
  Combines Core, Attributes, and Colors functionality.
  Handles advanced text formatting features including double-width/height,
  text attributes, and color management.
  """

  @behaviour Raxol.Terminal.ANSI.Behaviours.TextFormatting

  # Type definitions
  @type color ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | {:index, non_neg_integer()}
          | nil

  @type text_style :: %{
          double_width: boolean(),
          double_height: :none | :top | :bottom,
          bold: boolean(),
          faint: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          fraktur: boolean(),
          double_underline: boolean(),
          framed: boolean(),
          encircled: boolean(),
          overlined: boolean(),
          foreground: color(),
          background: color(),
          hyperlink: String.t() | nil
        }

  @type t :: %__MODULE__{
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          foreground: color(),
          background: color(),
          double_width: boolean(),
          double_height: :none | :top | :bottom,
          faint: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          fraktur: boolean(),
          double_underline: boolean(),
          framed: boolean(),
          encircled: boolean(),
          overlined: boolean(),
          hyperlink: String.t() | nil
        }

  defstruct bold: false,
            italic: false,
            underline: false,
            blink: false,
            reverse: false,
            foreground: nil,
            background: nil,
            double_width: false,
            double_height: :none,
            faint: false,
            conceal: false,
            strikethrough: false,
            fraktur: false,
            double_underline: false,
            framed: false,
            encircled: false,
            overlined: false,
            hyperlink: nil

  # Core sub-module - Primary text formatting operations
  defmodule Core do
    @moduledoc """
    Core text formatting functionality.
    """

    alias Raxol.Terminal.ANSI.TextFormatting

    def new do
      %TextFormatting{}
    end

    def default_style, do: new()

    def new(attrs) when is_list(attrs) do
      attrs |> Enum.into(%{}) |> new()
    end

    def new(%{} = attrs) do
      struct(TextFormatting, attrs)
    end

    def set_foreground(style, color) do
      style = ensure_text_formatting_struct(style)
      %{style | foreground: color}
    end

    def set_background(style, color) do
      style = ensure_text_formatting_struct(style)
      %{style | background: color}
    end

    def get_foreground(%{} = style), do: style.foreground
    def get_background(%{} = style), do: style.background

    def set_double_width(style) do
      %{style | double_width: true, double_height: :none}
    end

    def set_double_height_top(style) do
      %{style | double_width: true, double_height: :top}
    end

    def set_double_height_bottom(style) do
      %{style | double_width: true, double_height: :bottom}
    end

    def reset_size(style) do
      %{style | double_width: false, double_height: :none}
    end

    def set_hyperlink(style, url) do
      %{style | hyperlink: url}
    end

    def reset_attributes(_style), do: new()

    def set_attributes(style, attributes) do
      Enum.reduce(
        attributes,
        style,
        &TextFormatting.Attributes.apply_attribute(&2, &1)
      )
    end

    def set_custom(style, key, value) do
      Map.put(style, key, value)
    end

    def update_attrs(style, attrs) do
      Map.merge(style, attrs)
    end

    def validate(style) do
      case style do
        %{
          double_width: _,
          double_height: _,
          bold: _,
          faint: _,
          italic: _,
          underline: _,
          blink: _,
          reverse: _,
          conceal: _,
          strikethrough: _,
          fraktur: _,
          double_underline: _,
          framed: _,
          encircled: _,
          overlined: _,
          foreground: _,
          background: _,
          hyperlink: _
        } ->
          {:ok, style}

        _ ->
          {:error, "Invalid text style map"}
      end
    end

    def apply_color(style, :foreground, color) do
      %{style | foreground: color}
    end

    def apply_color(style, :background, color) do
      %{style | background: color}
    end

    def effective_width(style, text) do
      base_width =
        case text do
          # Wide Unicode character
          "你" -> 2
          _ -> String.length(text)
        end

      calculate_width_with_style(base_width, style)
    end

    defp calculate_width_with_style(base_width, %{double_width: true}),
      do: base_width * 2

    defp calculate_width_with_style(base_width, %{double_height: height})
         when height != :none,
         do: base_width

    defp calculate_width_with_style(base_width, _style), do: base_width

    def get_paired_line_type(style) do
      case style.double_height do
        :top -> :bottom
        :bottom -> :top
        :none -> nil
      end
    end

    def needs_paired_line?(style) do
      style.double_height != :none
    end

    def get_hyperlink(%{hyperlink: url}) when is_binary(url), do: url
    def get_hyperlink(_), do: nil

    def set_attribute(emulator, attribute) do
      attributes = MapSet.put(emulator.attributes, attribute)
      %{emulator | attributes: attributes}
    end

    defp ensure_text_formatting_struct(nil), do: new()
    defp ensure_text_formatting_struct(%TextFormatting{} = style), do: style

    defp ensure_text_formatting_struct(style) when is_map(style) do
      new() |> Map.merge(style)
    end

    defp ensure_text_formatting_struct(_), do: new()
  end

  # Attributes sub-module - Handles text attributes
  defmodule Attributes do
    @moduledoc """
    Text attribute handling for ANSI text formatting.
    """

    alias Raxol.Terminal.ANSI.TextFormatting

    @attribute_handlers %{
      reset: &TextFormatting.Core.new/0,
      double_width: &TextFormatting.Core.set_double_width/1,
      double_height_top: &TextFormatting.Core.set_double_height_top/1,
      double_height_bottom: &TextFormatting.Core.set_double_height_bottom/1,
      no_double_width: &TextFormatting.Core.reset_size/1,
      no_double_height: &TextFormatting.Core.reset_size/1,
      bold: &__MODULE__.set_bold/1,
      faint: &__MODULE__.set_faint/1,
      italic: &__MODULE__.set_italic/1,
      underline: &__MODULE__.set_underline/1,
      blink: &__MODULE__.set_blink/1,
      reverse: &__MODULE__.set_reverse/1,
      conceal: &__MODULE__.set_conceal/1,
      strikethrough: &__MODULE__.set_strikethrough/1,
      fraktur: &__MODULE__.set_fraktur/1,
      double_underline: &__MODULE__.set_double_underline/1,
      framed: &__MODULE__.set_framed/1,
      encircled: &__MODULE__.set_encircled/1,
      overlined: &__MODULE__.set_overlined/1,
      default_fg: &__MODULE__.reset_foreground/1,
      default_bg: &__MODULE__.reset_background/1,
      normal_intensity: &__MODULE__.reset_bold/1,
      not_framed_encircled: &__MODULE__.reset_framed_encircled/1,
      not_overlined: &__MODULE__.reset_overlined/1
    }

    @reset_attribute_map %{
      no_bold: :bold,
      no_italic: :italic,
      no_underline: :underline,
      no_blink: :blink,
      no_reverse: :reverse,
      no_conceal: :conceal,
      no_strikethrough: :strikethrough,
      no_fraktur: :fraktur,
      no_double_underline: :double_underline,
      no_framed: :framed,
      no_encircled: :encircled,
      no_overlined: :overlined
    }

    def apply_attribute(style, attribute) do
      case attribute do
        :reset -> TextFormatting.Core.new()
        _ -> handle_reset_attribute(style, attribute)
      end
    end

    defp handle_reset_attribute(style, attribute) do
      case Map.get(@reset_attribute_map, attribute) do
        nil -> handle_positive_attribute(style, attribute)
        field -> %{style | field => false}
      end
    end

    defp handle_positive_attribute(style, attribute) do
      case Map.get(@attribute_handlers, attribute) do
        nil -> style
        handler -> handler.(style)
      end
    end

    def set_bold(style), do: %{style | bold: true}
    def set_faint(style), do: %{style | faint: true}
    def set_italic(style), do: %{style | italic: true}
    def set_underline(style), do: %{style | underline: true}
    def set_blink(style), do: %{style | blink: true}
    def set_reverse(style), do: %{style | reverse: true}
    def set_conceal(style), do: %{style | conceal: true}
    def set_strikethrough(style), do: %{style | strikethrough: true}
    def set_fraktur(style), do: %{style | fraktur: true}
    def set_double_underline(style), do: %{style | double_underline: true}
    def set_framed(style), do: %{style | framed: true}
    def set_encircled(style), do: %{style | encircled: true}
    def set_overlined(style), do: %{style | overlined: true}

    def reset_bold(style), do: %{style | bold: false, faint: false}
    def reset_faint(style), do: %{style | faint: false}
    def reset_italic(style), do: %{style | italic: false}

    def reset_underline(style),
      do: %{style | underline: false, double_underline: false}

    def reset_blink(style), do: %{style | blink: false}
    def reset_reverse(style), do: %{style | reverse: false}
    def reset_foreground(style), do: %{style | foreground: nil}
    def reset_background(style), do: %{style | background: nil}

    def reset_framed_encircled(style),
      do: %{style | framed: false, encircled: false}

    def reset_overlined(style), do: %{style | overlined: false}
    def reset_conceal(style), do: %{style | conceal: false}
    def reset_strikethrough(style), do: %{style | strikethrough: false}
    def reset_fraktur(style), do: %{style | fraktur: false}
    def reset_double_underline(style), do: %{style | double_underline: false}
    def reset_framed(style), do: %{style | framed: false}
    def reset_encircled(style), do: %{style | encircled: false}
  end

  # Colors sub-module - Color handling utilities
  defmodule Colors do
    @moduledoc """
    Color handling utilities for ANSI text formatting.
    """

    def ansi_code_to_color_name(code) do
      case code do
        30 -> :black
        31 -> :red
        32 -> :green
        33 -> :yellow
        34 -> :blue
        35 -> :magenta
        36 -> :cyan
        37 -> :white
        40 -> :black
        41 -> :red
        42 -> :green
        43 -> :yellow
        44 -> :blue
        45 -> :magenta
        46 -> :cyan
        47 -> :white
        90 -> :bright_black
        91 -> :bright_red
        92 -> :bright_green
        93 -> :bright_yellow
        94 -> :bright_blue
        95 -> :bright_magenta
        96 -> :bright_cyan
        97 -> :bright_white
        100 -> :bright_black
        101 -> :bright_red
        102 -> :bright_green
        103 -> :bright_yellow
        104 -> :bright_blue
        105 -> :bright_magenta
        106 -> :bright_cyan
        107 -> :bright_white
        _ -> nil
      end
    end

    def build_foreground_codes(nil), do: []

    def build_foreground_codes(color) when is_binary(color) do
      case color_name_to_code(color) do
        nil -> []
        code -> [to_string(code)]
      end
    end

    def build_foreground_codes(color) when is_atom(color) do
      case color_name_to_code(to_string(color)) do
        nil -> []
        code -> [to_string(code)]
      end
    end

    def build_foreground_codes(color) when is_integer(color),
      do: [to_string(color)]

    def build_foreground_codes(_), do: []

    def build_background_codes(nil), do: []

    def build_background_codes(color) when is_binary(color) do
      case color_name_to_bg_code(color) do
        nil -> []
        code -> [to_string(code)]
      end
    end

    def build_background_codes(color) when is_atom(color) do
      case color_name_to_bg_code(to_string(color)) do
        nil -> []
        code -> [to_string(code)]
      end
    end

    def build_background_codes(color) when is_integer(color),
      do: [to_string(color + 10)]

    def build_background_codes(_), do: []

    defp color_name_to_code(name) do
      case name do
        "black" -> 30
        "red" -> 31
        "green" -> 32
        "yellow" -> 33
        "blue" -> 34
        "magenta" -> 35
        "cyan" -> 36
        "white" -> 37
        "bright_black" -> 90
        "bright_red" -> 91
        "bright_green" -> 92
        "bright_yellow" -> 93
        "bright_blue" -> 94
        "bright_magenta" -> 95
        "bright_cyan" -> 96
        "bright_white" -> 97
        _ -> nil
      end
    end

    defp color_name_to_bg_code(name) do
      case name do
        "black" -> 40
        "red" -> 41
        "green" -> 42
        "yellow" -> 43
        "blue" -> 44
        "magenta" -> 45
        "cyan" -> 46
        "white" -> 47
        "bright_black" -> 100
        "bright_red" -> 101
        "bright_green" -> 102
        "bright_yellow" -> 103
        "bright_blue" -> 104
        "bright_magenta" -> 105
        "bright_cyan" -> 106
        "bright_white" -> 107
        _ -> nil
      end
    end

    def handle_integer_color_param(code, style) do
      cond do
        code >= 30 and code <= 37 ->
          %{style | foreground: ansi_code_to_color_name(code)}

        code >= 40 and code <= 47 ->
          %{style | background: ansi_code_to_color_name(code - 10)}

        code >= 90 and code <= 97 ->
          # Convert 90-97 to 30-37
          base_color = ansi_code_to_color_name(code - 60)
          %{style | foreground: base_color, bold: true}

        code >= 100 and code <= 107 ->
          # Convert 100-107 to 30-37
          base_color = ansi_code_to_color_name(code - 70)
          %{style | background: base_color}

        true ->
          style
      end
    end

    def handle_tuple_color_param(tuple, style) do
      case tuple do
        {38, 5, n} when n >= 0 and n <= 255 ->
          %{style | foreground: {:indexed, n}}

        {48, 5, n} when n >= 0 and n <= 255 ->
          %{style | background: {:indexed, n}}

        {38, 2, r, g, b}
        when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
          %{style | foreground: {:rgb, r, g, b}}

        {48, 2, r, g, b}
        when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
          %{style | background: {:rgb, r, g, b}}

        _ ->
          style
      end
    end
  end

  # SGR sub-module (if needed for SGR param formatting)
  defmodule SGR do
    @moduledoc """
    SGR parameter formatting for text styles.
    """

    def format_sgr_params(style) do
      # Build SGR parameter codes based on style attributes
      codes = []
      codes = if style.bold, do: ["1" | codes], else: codes
      codes = if style.italic, do: ["3" | codes], else: codes
      codes = if style.underline, do: ["4" | codes], else: codes
      codes = if style.blink, do: ["5" | codes], else: codes
      codes = if style.reverse, do: ["7" | codes], else: codes
      codes = if style.conceal, do: ["8" | codes], else: codes
      codes = if style.strikethrough, do: ["9" | codes], else: codes

      # Add color codes
      codes = codes ++ Colors.build_foreground_codes(style.foreground)
      codes = codes ++ Colors.build_background_codes(style.background)

      codes
      |> Enum.reverse()
      |> Enum.join(";")
    end

    def parse_sgr_param(param, style) do
      # Parse SGR parameter and update style
      case param do
        # Reset all attributes
        0 ->
          Raxol.Terminal.ANSI.TextFormatting.Core.new()

        # Text attributes
        1 ->
          %{style | bold: true}

        2 ->
          %{style | faint: true}

        6 ->
          %{style | blink: true}

        3 ->
          %{style | italic: true}

        4 ->
          %{style | underline: true}

        5 ->
          %{style | blink: true}

        7 ->
          %{style | reverse: true}

        8 ->
          %{style | conceal: true}

        9 ->
          %{style | strikethrough: true}

        # Extended attributes
        20 ->
          %{style | fraktur: true}

        21 ->
          %{style | double_underline: true}

        # Reset attributes
        22 ->
          %{style | bold: false, faint: false}

        23 ->
          %{style | italic: false, fraktur: false}

        24 ->
          %{style | underline: false, double_underline: false}

        25 ->
          %{style | blink: false}

        27 ->
          %{style | reverse: false}

        28 ->
          %{style | conceal: false}

        29 ->
          %{style | strikethrough: false}

        # Framed, encircled, overlined
        51 ->
          %{style | framed: true}

        52 ->
          %{style | encircled: true}

        53 ->
          %{style | overlined: true}

        54 ->
          %{style | framed: false, encircled: false}

        55 ->
          %{style | overlined: false}

        # Standard foreground colors (30-37)
        30 ->
          %{style | foreground: :black}

        31 ->
          %{style | foreground: :red}

        32 ->
          %{style | foreground: :green}

        33 ->
          %{style | foreground: :yellow}

        34 ->
          %{style | foreground: :blue}

        35 ->
          %{style | foreground: :magenta}

        36 ->
          %{style | foreground: :cyan}

        37 ->
          %{style | foreground: :white}

        # Default foreground
        39 ->
          %{style | foreground: nil}

        # Standard background colors (40-47)
        40 ->
          %{style | background: :black}

        41 ->
          %{style | background: :red}

        42 ->
          %{style | background: :green}

        43 ->
          %{style | background: :yellow}

        44 ->
          %{style | background: :blue}

        45 ->
          %{style | background: :magenta}

        46 ->
          %{style | background: :cyan}

        47 ->
          %{style | background: :white}

        # Default background
        49 ->
          %{style | background: nil}

        # Bright foreground colors (90-97) - set base color + bold
        90 ->
          %{style | foreground: :black, bold: true}

        91 ->
          %{style | foreground: :red, bold: true}

        92 ->
          %{style | foreground: :green, bold: true}

        93 ->
          %{style | foreground: :yellow, bold: true}

        94 ->
          %{style | foreground: :blue, bold: true}

        95 ->
          %{style | foreground: :magenta, bold: true}

        96 ->
          %{style | foreground: :cyan, bold: true}

        97 ->
          %{style | foreground: :white, bold: true}

        # Bright background colors (100-107) - just base color, no bold
        100 ->
          %{style | background: :black}

        101 ->
          %{style | background: :red}

        102 ->
          %{style | background: :green}

        103 ->
          %{style | background: :yellow}

        104 ->
          %{style | background: :blue}

        105 ->
          %{style | background: :magenta}

        106 ->
          %{style | background: :cyan}

        107 ->
          %{style | background: :white}

        # 8-bit color codes
        {:fg_8bit, n} when is_integer(n) and n >= 0 and n <= 255 ->
          %{style | foreground: {:index, n}}

        {:bg_8bit, n} when is_integer(n) and n >= 0 and n <= 255 ->
          %{style | background: {:index, n}}

        # 24-bit RGB codes
        {:fg_rgb, r, g, b} ->
          %{style | foreground: {:rgb, r, g, b}}

        {:bg_rgb, r, g, b} ->
          %{style | background: {:rgb, r, g, b}}

        # Unknown parameter, return unchanged
        _ ->
          style
      end
    end
  end

  # Main module - behavior implementation and delegations
  @impl true
  def new, do: Core.new()

  def default_style, do: Core.default_style()
  def new(attrs), do: Core.new(attrs)

  @impl true
  def set_foreground(style, color), do: Core.set_foreground(style, color)

  @impl true
  def set_background(style, color), do: Core.set_background(style, color)

  @impl true
  def get_foreground(style), do: Core.get_foreground(style)

  @impl true
  def get_background(style), do: Core.get_background(style)

  @impl true
  def set_double_width(style), do: Core.set_double_width(style)

  @impl true
  def set_double_height_top(style), do: Core.set_double_height_top(style)

  @impl true
  def set_double_height_bottom(style), do: Core.set_double_height_bottom(style)

  @impl true
  def reset_size(style), do: Core.reset_size(style)

  @impl true
  def set_hyperlink(style, url), do: Core.set_hyperlink(style, url)

  @impl true
  def reset_attributes(style), do: Core.reset_attributes(style)

  @impl true
  def set_attributes(style, attributes),
    do: Core.set_attributes(style, attributes)

  @impl true
  def set_custom(style, key, value), do: Core.set_custom(style, key, value)

  @impl true
  def update_attrs(style, attrs), do: Core.update_attrs(style, attrs)

  @impl true
  def validate(style), do: Core.validate(style)

  @impl true
  def apply_attribute(style, attribute) do
    case attribute do
      :reset -> new()
      _ -> Attributes.apply_attribute(style, attribute)
    end
  end

  @impl true
  def set_bold(style), do: Attributes.set_bold(style)

  @impl true
  def set_faint(style), do: Attributes.set_faint(style)

  @impl true
  def set_italic(style), do: Attributes.set_italic(style)

  @impl true
  def set_underline(style), do: Attributes.set_underline(style)

  @impl true
  def set_blink(style), do: Attributes.set_blink(style)

  @impl true
  def set_reverse(style), do: Attributes.set_reverse(style)

  @impl true
  def set_conceal(style), do: Attributes.set_conceal(style)

  @impl true
  def set_strikethrough(style), do: Attributes.set_strikethrough(style)

  @impl true
  def set_fraktur(style), do: Attributes.set_fraktur(style)

  @impl true
  def set_double_underline(style), do: Attributes.set_double_underline(style)

  @impl true
  def set_framed(style), do: Attributes.set_framed(style)

  @impl true
  def set_encircled(style), do: Attributes.set_encircled(style)

  @impl true
  def set_overlined(style), do: Attributes.set_overlined(style)

  @impl true
  def reset_bold(style), do: Attributes.reset_bold(style)

  @impl true
  def reset_italic(style), do: Attributes.reset_italic(style)

  @impl true
  def reset_underline(style), do: Attributes.reset_underline(style)

  @impl true
  def reset_blink(style), do: Attributes.reset_blink(style)

  @impl true
  def reset_reverse(style), do: Attributes.reset_reverse(style)

  @impl true
  def reset_framed_encircled(style),
    do: Attributes.reset_framed_encircled(style)

  @impl true
  def reset_overlined(style), do: Attributes.reset_overlined(style)

  # Additional non-behavior functions
  def reset_faint(style), do: Attributes.reset_faint(style)
  def reset_foreground(style), do: Attributes.reset_foreground(style)
  def reset_background(style), do: Attributes.reset_background(style)
  def reset_conceal(style), do: Attributes.reset_conceal(style)
  def reset_strikethrough(style), do: Attributes.reset_strikethrough(style)
  def reset_fraktur(style), do: Attributes.reset_fraktur(style)

  def reset_double_underline(style),
    do: Attributes.reset_double_underline(style)

  def reset_framed(style), do: Attributes.reset_framed(style)
  def reset_encircled(style), do: Attributes.reset_encircled(style)

  def apply_color(style, type, color), do: Core.apply_color(style, type, color)
  def effective_width(style, text), do: Core.effective_width(style, text)
  def get_paired_line_type(style), do: Core.get_paired_line_type(style)
  def needs_paired_line?(style), do: Core.needs_paired_line?(style)
  def get_hyperlink(style), do: Core.get_hyperlink(style)

  def set_attribute(emulator, attribute),
    do: Core.set_attribute(emulator, attribute)

  def ansi_code_to_color_name(code), do: Colors.ansi_code_to_color_name(code)
  def format_sgr_params(style), do: SGR.format_sgr_params(style)
  def parse_sgr_param(param, style), do: SGR.parse_sgr_param(param, style)
end
