use Raxol.UI, framework: :raw

alias Raxol.Terminal.Buffer
alias Raxol.Terminal.Commands

def render(buffer, x, y, component_name) do
  buffer
  |> Commands.move_cursor(x, y)
  |> Commands.set_fg_color(:cyan)
  |> Commands.write_text("Component: " <> component_name)
  |> Commands.reset_colors()
end

# Usage:
# buffer = Buffer.new(80, 24)
# buffer = render(buffer, 0, 0, "MyComponent")
