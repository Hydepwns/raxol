use Raxol.UI, framework: :raw

alias Raxol.Terminal.Buffer
alias Raxol.Terminal.Commands

def render(buffer, x, y, label, is_focused) do
  fg = if is_focused, do: :black, else: :white
  bg = if is_focused, do: :cyan, else: :blue

  buffer
  |> Commands.move_cursor(x, y)
  |> Commands.set_fg_color(fg)
  |> Commands.set_bg_color(bg)
  |> Commands.write_text(" " <> label <> " ")
  |> Commands.reset_colors()
end

# Usage:
# buffer = Buffer.new(80, 24)
# buffer = render(buffer, 10, 5, "Click Me", true)
