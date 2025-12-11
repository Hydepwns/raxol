defmodule Raxol.Terminal.Style.StyleProcessor do
  @moduledoc """
  Handles style management for the terminal emulator.
  This module extracts the style handling logic from the main emulator.
  """

  @style_updates [
    {{:bold, true}, &Raxol.Terminal.ANSI.TextFormatting.set_bold/1},
    {{:bold, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_bold/1},
    {{:faint, true}, &Raxol.Terminal.ANSI.TextFormatting.set_faint/1},
    {{:italic, true}, &Raxol.Terminal.ANSI.TextFormatting.set_italic/1},
    {{:italic, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_italic/1},
    {{:underline, true}, &Raxol.Terminal.ANSI.TextFormatting.set_underline/1},
    {{:underline, false},
     &Raxol.Terminal.ANSI.TextFormatting.reset_underline/1},
    {{:blink, true}, &Raxol.Terminal.ANSI.TextFormatting.set_blink/1},
    {{:blink, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_blink/1},
    {{:reverse, true}, &Raxol.Terminal.ANSI.TextFormatting.set_reverse/1},
    {{:reverse, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_reverse/1},
    {{:conceal, true}, &Raxol.Terminal.ANSI.TextFormatting.set_conceal/1},
    {{:conceal, false}, &Raxol.Terminal.ANSI.TextFormatting.reset_conceal/1},
    {{:crossed_out, true},
     &Raxol.Terminal.ANSI.TextFormatting.set_strikethrough/1},
    {{:crossed_out, false},
     &Raxol.Terminal.ANSI.TextFormatting.reset_strikethrough/1}
  ]

  @doc """
  Updates the emulator style with the given style attributes.
  """
  def update_style(emulator, style_attrs) when is_map(style_attrs) do
    current_style = emulator.style || Raxol.Terminal.ANSI.TextFormatting.new()

    # Convert current_style to TextFormatting struct if it's a plain map
    current_style =
      case Map.has_key?(current_style, :__struct__) do
        true -> current_style
        false -> Raxol.Terminal.ANSI.TextFormatting.new(current_style)
      end

    updated_style =
      Enum.reduce(style_attrs, current_style, &apply_style_attribute/2)

    %{emulator | style: updated_style}
  end

  @doc """
  Applies a single style attribute to the current style.
  """
  def apply_style_attribute({attr, value}, style) do
    case attr do
      :foreground ->
        Raxol.Terminal.ANSI.TextFormatting.set_foreground(style, value)

      :background ->
        Raxol.Terminal.ANSI.TextFormatting.set_background(style, value)

      _ ->
        case get_style_update_function(attr, value) do
          {:ok, update_fn} -> update_fn.(style)
          :error -> style
        end
    end
  end

  @doc """
  Gets the style update function for a given attribute and value.
  """
  def get_style_update_function(attr, value) do
    case Map.fetch(get_style_updates(), {attr, value}) do
      {:ok, update_fn} -> {:ok, update_fn}
      :error -> :error
    end
  end

  @doc """
  Returns the mapping of style attributes to their corresponding update functions.
  """
  def get_style_updates do
    @style_updates |> Enum.into(%{})
  end
end
