defmodule Raxol.Terminal.Commands.CommandServer.SGROps do
  @moduledoc false
  @compile {:no_warn_undefined, Raxol.Terminal.Commands.CommandServer.Helpers}

  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Commands.CommandServer.Helpers

  @sgr_mappings %{
    0 => {:reset, :all},
    1 => {:set_attribute, :bold},
    2 => {:set_attribute, :faint},
    3 => {:set_attribute, :italic},
    4 => {:set_attribute, :underline},
    5 => {:set_attribute, :blink},
    7 => {:set_attribute, :reverse},
    8 => {:set_attribute, :conceal},
    9 => {:set_attribute, :strikethrough},
    22 => {:reset_attribute, :bold_faint},
    23 => {:reset_attribute, :italic},
    24 => {:reset_attribute, :underline},
    25 => {:reset_attribute, :blink},
    27 => {:reset_attribute, :reverse},
    28 => {:reset_attribute, :conceal},
    29 => {:reset_attribute, :strikethrough},
    39 => {:color, :foreground, :reset},
    49 => {:color, :background, :reset}
  }

  def handle_sgr(emulator, %{params: params}, _context) do
    apply_text_formatting(emulator, params)
  end

  defp apply_text_formatting(emulator, params) do
    updated_emulator =
      Enum.reduce(params, emulator, fn param, acc ->
        apply_sgr_parameter(acc, param)
      end)

    {:ok, updated_emulator}
  end

  defp apply_sgr_parameter(emulator, param) do
    current_style = Helpers.get_current_text_style(emulator)
    new_style = apply_sgr_formatting(current_style, param)
    Helpers.set_current_text_style(emulator, new_style)
  end

  defp apply_sgr_formatting(style, param) do
    case categorize_sgr_parameter(param) do
      {:reset, _} -> TextFormatting.reset_attributes(style)
      {:set_attribute, attribute} -> apply_text_attribute(style, attribute)
      {:reset_attribute, attribute} -> reset_text_attribute(style, attribute)
      {:color, type, value} -> apply_color(style, type, value)
      :unknown -> style
    end
  end

  defp categorize_sgr_parameter(param) do
    @sgr_mappings[param] || categorize_sgr_range(param)
  end

  defp categorize_sgr_range(param) do
    cond do
      param >= 30 and param <= 37 -> {:color, :foreground, param - 30}
      param >= 40 and param <= 47 -> {:color, :background, param - 40}
      true -> :unknown
    end
  end

  defp apply_text_attribute(style, attribute) do
    case attribute do
      :bold -> TextFormatting.set_bold(style)
      :faint -> TextFormatting.set_faint(style)
      :italic -> TextFormatting.set_italic(style)
      :underline -> TextFormatting.set_underline(style)
      :blink -> TextFormatting.set_blink(style)
      :reverse -> TextFormatting.set_reverse(style)
      :conceal -> TextFormatting.set_conceal(style)
      :strikethrough -> TextFormatting.set_strikethrough(style)
    end
  end

  defp reset_text_attribute(style, attribute) do
    case attribute do
      :bold_faint ->
        TextFormatting.reset_bold(style) |> TextFormatting.reset_faint()

      :italic ->
        TextFormatting.reset_italic(style)

      :underline ->
        TextFormatting.reset_underline(style)

      :blink ->
        TextFormatting.reset_blink(style)

      :reverse ->
        TextFormatting.reset_reverse(style)

      :conceal ->
        TextFormatting.reset_conceal(style)

      :strikethrough ->
        TextFormatting.reset_strikethrough(style)
    end
  end

  defp apply_color(style, type, value) do
    case {type, value} do
      {:foreground, :reset} ->
        TextFormatting.reset_foreground(style)

      {:background, :reset} ->
        TextFormatting.reset_background(style)

      {:foreground, color_value} ->
        TextFormatting.set_foreground(style, color_value)

      {:background, color_value} ->
        TextFormatting.set_background(style, color_value)
    end
  end
end
