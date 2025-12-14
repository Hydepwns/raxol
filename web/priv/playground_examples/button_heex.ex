# Raxol Button - Using HEEx Components
# Import the terminal-aware components
import Raxol.HEEx.Components

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={1}>
    <.terminal_row gap={2}>
      <.terminal_button phx-click="clicked" role="primary">
        Click Me
      </.terminal_button>
      <.terminal_button role="secondary">
        Cancel
      </.terminal_button>
    </.terminal_row>
  </.terminal_box>
  """
end

# Button roles: "primary", "secondary", "danger", "success"
# Supports: phx-click, disabled, and standard HTML attributes

# For terminal-native rendering, use Raxol.UI.Components.Button:
# alias Raxol.UI.Components.Button
#
# Button.new(%{
#   label: "Submit",
#   style: :primary,
#   on_click: fn -> send(self(), :button_clicked) end
# })
