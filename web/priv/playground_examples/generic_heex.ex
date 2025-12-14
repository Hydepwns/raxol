# Raxol Component Template
import Raxol.HEEx.Components

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={2}>
    <.terminal_text color="cyan">
      Component: <%= @component_name %>
    </.terminal_text>
  </.terminal_box>
  """
end
