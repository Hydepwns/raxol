defmodule Raxol.Terminal.ANSI.TextFormatting.Attributes do
  @moduledoc """
  Text attribute handling for the Raxol Terminal ANSI TextFormatting module.
  Handles setters, resetters, and attribute application logic.
  """

  alias Raxol.Terminal.ANSI.TextFormatting.Core

  @attribute_handlers %{
    reset: &Core.new/0,
    double_width: &Core.set_double_width/1,
    double_height_top: &Core.set_double_height_top/1,
    double_height_bottom: &Core.set_double_height_bottom/1,
    no_double_width: &Core.reset_size/1,
    no_double_height: &Core.reset_size/1,
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

  @doc """
  Applies a text attribute to the style map.

  ## Parameters

  * `style` - The current text style
  * `attribute` - The attribute to apply (e.g., :bold, :underline, etc.)

  ## Returns

  The updated text style with the new attribute applied.
  """
  @spec apply_attribute(Core.text_style(), atom()) :: Core.text_style()
  def apply_attribute(style, attribute) do
    case attribute do
      :reset -> Core.new()
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

  @doc """
  Sets bold text mode.
  """
  @spec set_bold(Core.text_style()) :: Core.text_style()
  def set_bold(style) do
    %{style | bold: true}
  end

  @doc """
  Sets faint text mode.
  """
  @spec set_faint(Core.text_style()) :: Core.text_style()
  def set_faint(style) do
    %{style | faint: true}
  end

  @doc """
  Sets italic text mode.
  """
  @spec set_italic(Core.text_style()) :: Core.text_style()
  def set_italic(style) do
    %{style | italic: true}
  end

  @doc """
  Sets underline text mode.
  """
  @spec set_underline(Core.text_style()) :: Core.text_style()
  def set_underline(style) do
    %{style | underline: true}
  end

  @doc """
  Sets blink text mode.
  """
  @spec set_blink(Core.text_style()) :: Core.text_style()
  def set_blink(style) do
    %{style | blink: true}
  end

  @doc """
  Sets reverse video mode.
  """
  @spec set_reverse(Core.text_style()) :: Core.text_style()
  def set_reverse(style) do
    %{style | reverse: true}
  end

  @doc """
  Sets concealed text mode.
  """
  @spec set_conceal(Core.text_style()) :: Core.text_style()
  def set_conceal(style) do
    %{style | conceal: true}
  end

  @doc """
  Sets strikethrough text mode.
  """
  @spec set_strikethrough(Core.text_style()) :: Core.text_style()
  def set_strikethrough(style) do
    %{style | strikethrough: true}
  end

  @doc """
  Sets fraktur text mode.
  """
  @spec set_fraktur(Core.text_style()) :: Core.text_style()
  def set_fraktur(style) do
    %{style | fraktur: true}
  end

  @doc """
  Sets double underline text mode.
  """
  @spec set_double_underline(Core.text_style()) :: Core.text_style()
  def set_double_underline(style) do
    %{style | double_underline: true}
  end

  @doc """
  Sets framed text mode.
  """
  @spec set_framed(Core.text_style()) :: Core.text_style()
  def set_framed(style) do
    %{style | framed: true}
  end

  @doc """
  Sets encircled text mode.
  """
  @spec set_encircled(Core.text_style()) :: Core.text_style()
  def set_encircled(style) do
    %{style | encircled: true}
  end

  @doc """
  Sets overlined text mode.
  """
  @spec set_overlined(Core.text_style()) :: Core.text_style()
  def set_overlined(style) do
    %{style | overlined: true}
  end

  @doc """
  Resets bold text mode.
  """
  @spec reset_bold(Core.text_style()) :: Core.text_style()
  def reset_bold(style) do
    %{style | bold: false}
  end

  @doc """
  Resets faint text mode.
  """
  @spec reset_faint(Core.text_style()) :: Core.text_style()
  def reset_faint(style) do
    %{style | faint: false}
  end

  @doc """
  Resets italic text mode.
  """
  @spec reset_italic(Core.text_style()) :: Core.text_style()
  def reset_italic(style) do
    %{style | italic: false}
  end

  @doc """
  Resets underline text mode.
  """
  @spec reset_underline(Core.text_style()) :: Core.text_style()
  def reset_underline(style) do
    %{style | underline: false}
  end

  @doc """
  Resets blink text mode.
  """
  @spec reset_blink(Core.text_style()) :: Core.text_style()
  def reset_blink(style) do
    %{style | blink: false}
  end

  @doc """
  Resets reverse video mode.
  """
  @spec reset_reverse(Core.text_style()) :: Core.text_style()
  def reset_reverse(style) do
    %{style | reverse: false}
  end

  @doc """
  Resets foreground color.
  """
  @spec reset_foreground(Core.text_style()) :: Core.text_style()
  def reset_foreground(style) do
    %{style | foreground: nil}
  end

  @doc """
  Resets background color.
  """
  @spec reset_background(Core.text_style()) :: Core.text_style()
  def reset_background(style) do
    %{style | background: nil}
  end

  @doc """
  Resets framed and encircled attributes.
  """
  @spec reset_framed_encircled(Core.text_style()) :: Core.text_style()
  def reset_framed_encircled(style) do
    %{style | framed: false, encircled: false}
  end

  @doc """
  Resets overlined attribute.
  """
  @spec reset_overlined(Core.text_style()) :: Core.text_style()
  def reset_overlined(style) do
    %{style | overlined: false}
  end

  @doc """
  Resets conceal text mode.
  """
  @spec reset_conceal(Core.text_style()) :: Core.text_style()
  def reset_conceal(style) do
    %{style | conceal: false}
  end

  @doc """
  Resets strikethrough text mode.
  """
  @spec reset_strikethrough(Core.text_style()) :: Core.text_style()
  def reset_strikethrough(style) do
    %{style | strikethrough: false}
  end

  @doc """
  Resets fraktur text mode.
  """
  @spec reset_fraktur(Core.text_style()) :: Core.text_style()
  def reset_fraktur(style) do
    %{style | fraktur: false}
  end

  @doc """
  Resets double underline text mode.
  """
  @spec reset_double_underline(Core.text_style()) :: Core.text_style()
  def reset_double_underline(style) do
    %{style | double_underline: false}
  end

  @doc """
  Resets framed text mode.
  """
  @spec reset_framed(Core.text_style()) :: Core.text_style()
  def reset_framed(style) do
    %{style | framed: false}
  end

  @doc """
  Resets encircled text mode.
  """
  @spec reset_encircled(Core.text_style()) :: Core.text_style()
  def reset_encircled(style) do
    %{style | encircled: false}
  end
end
