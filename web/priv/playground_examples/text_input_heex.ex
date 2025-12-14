# Raxol TextInput - Using HEEx Components
import Raxol.HEEx.Components

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={2}>
    <.terminal_column gap={2}>
      <.terminal_text bold>Username</.terminal_text>
      <.terminal_input
        value={@value}
        placeholder="Enter username..."
        phx-change="input_changed"
      />
    </.terminal_column>
  </.terminal_box>
  """
end

# For terminal-native text input:
# alias Raxol.UI.Components.Input.TextField
#
# TextField.new(%{
#   value: "",
#   placeholder: "Type here...",
#   on_change: fn value -> send(self(), {:text_changed, value}) end,
#   width: 30
# })

# Multi-line input:
# alias Raxol.UI.Components.Input.TextArea
# TextArea.new(%{value: "", rows: 5, cols: 40})
