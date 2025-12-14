# Raxol Menu - Raw Terminal Buffer Rendering
# Direct cell-based rendering for terminal applications

alias Raxol.Terminal.ScreenBuffer
alias Raxol.Style.TextFormatting

defmodule TerminalMenu do
  def render(buffer, x, y, items, selected_index) do
    # Render menu header
    buffer = render_header(buffer, x, y)

    # Render each menu item
    items
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {item, index}, buf ->
      render_item(buf, x, y + index + 1, item, index == selected_index)
    end)
  end

  defp render_header(buffer, x, y) do
    style = TextFormatting.new(%{
      foreground: :white,
      background: :blue,
      bold: true
    })

    ScreenBuffer.write_string(buffer, x, y, " Menu ", style)
  end

  defp render_item(buffer, x, y, text, selected?) do
    style = TextFormatting.new(%{
      foreground: if(selected?, do: :black, else: :white),
      background: if(selected?, do: :cyan, else: :default)
    })

    padding = String.duplicate(" ", 2)
    ScreenBuffer.write_string(buffer, x, y, padding <> text <> padding, style)
  end
end

# Usage:
# buffer = ScreenBuffer.new(80, 24)
# buffer = TerminalMenu.render(buffer, 2, 2, ["File", "Edit", "View"], 1)
#
# # Convert to HTML for web display:
# html = Raxol.LiveView.TerminalBridge.buffer_to_html(buffer, theme: :dracula)
