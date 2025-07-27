defmodule Raxol.Terminal.Buffer.CellHelper do
  @moduledoc """
  Shared helper functions for cell operations across terminal buffer modules.
  """

  @doc """
  Creates a cell from input data, handling both old and new cell formats.
  """
  @spec create_cell_from_input(Raxol.Terminal.Cell.t()) ::
          Raxol.Terminal.Cell.t()
  def create_cell_from_input(cell) do
    # Handle both old and new cell formats
    style =
      case cell do
        %{style: %Raxol.Terminal.ANSI.TextFormatting.Core{} = style} ->
          style

        %{style: %Raxol.Terminal.ANSI.TextFormatting{} = style} ->
          style

        %{foreground: fg, background: bg} = old_cell ->
          # Convert old format to new format
          %Raxol.Terminal.ANSI.TextFormatting.Core{
            foreground: fg,
            background: bg,
            bold: Map.get(old_cell, :bold, false),
            italic: Map.get(old_cell, :italic, false),
            underline: Map.get(old_cell, :underline, false),
            blink: Map.get(old_cell, :blink, false),
            reverse: Map.get(old_cell, :reverse, false),
            double_width: Map.get(old_cell, :double_width, false),
            double_height: Map.get(old_cell, :double_height, :none),
            strikethrough: Map.get(old_cell, :strikethrough, false),
            faint: Map.get(old_cell, :faint, false),
            conceal: Map.get(old_cell, :conceal, false),
            fraktur: Map.get(old_cell, :fraktur, false),
            double_underline: Map.get(old_cell, :double_underline, false),
            framed: Map.get(old_cell, :framed, false),
            encircled: Map.get(old_cell, :encircled, false),
            overlined: Map.get(old_cell, :overlined, false),
            hyperlink: Map.get(old_cell, :hyperlink, nil)
          }

        _ ->
          Raxol.Terminal.ANSI.TextFormatting.Core.new()
      end

    %Raxol.Terminal.Cell{
      char: cell.char,
      style: style,
      dirty: Map.get(cell, :dirty, false),
      wide_placeholder: Map.get(cell, :wide_placeholder, false)
    }
  end
end
