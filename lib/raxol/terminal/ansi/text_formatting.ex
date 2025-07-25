defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc """
  Handles advanced text formatting features for the terminal emulator.
  This includes double-width and double-height characters, as well as
  other advanced text attributes and colors.
  """

  @behaviour Raxol.Terminal.ANSI.TextFormattingBehaviour

  alias Raxol.Terminal.ANSI.TextFormatting.{Core, Attributes, Colors, SGR}

  # Re-export types and struct for backward compatibility
  @type color :: Core.color()
  @type text_style :: Core.text_style()
  @type t :: Core.t()

  defstruct [
    :bold, :italic, :underline, :blink, :reverse, :foreground, :background,
    :double_width, :double_height, :faint, :conceal, :strikethrough, :fraktur,
    :double_underline, :framed, :encircled, :overlined, :hyperlink
  ]

  # --- Core functionality delegation ---

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def new, do: %__MODULE__{
    bold: false,
    italic: false,
    underline: false,
    strikethrough: false,
    blink: false,
    reverse: false,
    faint: false,
    conceal: false,
    fraktur: false,
    double_underline: false,
    framed: false,
    encircled: false,
    overlined: false,
    double_width: false,
    double_height: :none
  }

  def default_style, do: new()

  def new(attrs), do: struct(new(), attrs)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_foreground(style, color), do: Core.set_foreground(style, color)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_background(style, color), do: Core.set_background(style, color)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def get_foreground(style), do: Core.get_foreground(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def get_background(style), do: Core.get_background(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_double_width(style), do: Core.set_double_width(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_double_height_top(style), do: Core.set_double_height_top(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_double_height_bottom(style), do: Core.set_double_height_bottom(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_size(style), do: Core.reset_size(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_hyperlink(style, url), do: Core.set_hyperlink(style, url)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_attributes(style), do: Core.reset_attributes(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_attributes(style, attributes), do: Core.set_attributes(style, attributes)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_custom(style, key, value), do: Core.set_custom(style, key, value)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def update_attrs(style, attrs), do: Core.update_attrs(style, attrs)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def validate(style), do: Core.validate(style)

  def apply_color(style, type, color), do: Core.apply_color(style, type, color)

  def effective_width(style, text), do: Core.effective_width(style, text)

  def get_paired_line_type(style), do: Core.get_paired_line_type(style)

  def needs_paired_line?(style), do: Core.needs_paired_line?(style)

  def get_hyperlink(style), do: Core.get_hyperlink(style)

  def set_attribute(emulator, attribute), do: Core.set_attribute(emulator, attribute)

  # --- Attribute functionality delegation ---

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def apply_attribute(style, attribute), do: Attributes.apply_attribute(style, attribute)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_bold(style), do: Attributes.set_bold(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_faint(style), do: Attributes.set_faint(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_italic(style), do: Attributes.set_italic(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_underline(style), do: Attributes.set_underline(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_blink(style), do: Attributes.set_blink(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_reverse(style), do: Attributes.set_reverse(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_conceal(style), do: Attributes.set_conceal(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_strikethrough(style), do: Attributes.set_strikethrough(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_fraktur(style), do: Attributes.set_fraktur(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_double_underline(style), do: Attributes.set_double_underline(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_framed(style), do: Attributes.set_framed(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_encircled(style), do: Attributes.set_encircled(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def set_overlined(style), do: Attributes.set_overlined(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_bold(style), do: Attributes.reset_bold(style)

  # Note: reset_faint is not part of the behaviour
  def reset_faint(style), do: Attributes.reset_faint(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_italic(style), do: Attributes.reset_italic(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_underline(style), do: Attributes.reset_underline(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_blink(style), do: Attributes.reset_blink(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_reverse(style), do: Attributes.reset_reverse(style)

  def reset_foreground(style), do: Attributes.reset_foreground(style)

  def reset_background(style), do: Attributes.reset_background(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_framed_encircled(style), do: Attributes.reset_framed_encircled(style)

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  def reset_overlined(style), do: Attributes.reset_overlined(style)

  def reset_conceal(style), do: Attributes.reset_conceal(style)

  def reset_strikethrough(style), do: Attributes.reset_strikethrough(style)

  def reset_fraktur(style), do: Attributes.reset_fraktur(style)

  def reset_double_underline(style), do: Attributes.reset_double_underline(style)

  def reset_framed(style), do: Attributes.reset_framed(style)

  def reset_encircled(style), do: Attributes.reset_encircled(style)

  # --- Color functionality delegation ---

  def ansi_code_to_color_name(code), do: Colors.ansi_code_to_color_name(code)

  # --- SGR functionality delegation ---

  def format_sgr_params(style), do: SGR.format_sgr_params(style)

  # Note: parse_sgr_param is not part of the behaviour
  def parse_sgr_param(param, style), do: SGR.parse_sgr_param(param, style)
end
