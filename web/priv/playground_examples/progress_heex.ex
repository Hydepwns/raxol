# Raxol Progress - Using HEEx Components
import Raxol.HEEx.Components

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={2}>
    <.terminal_column gap={2}>
      <.terminal_text>Download Progress</.terminal_text>
      <.terminal_progress
        value={@progress}
        max={100}
        width={30}
        color="green"
        show_percentage={true}
      />
    </.terminal_column>
  </.terminal_box>
  """
end

# Progress attributes:
# - value: Current progress (0-100)
# - max: Maximum value (default: 100)
# - width: Bar width in characters
# - color: Bar color (green, blue, yellow, red)
# - show_percentage: Show % text
# - filled_char: Character for filled portion (default: "=")
# - empty_char: Character for empty portion (default: "-")

# Terminal-native progress components:
# alias Raxol.UI.Components.Progress.Bar
# alias Raxol.UI.Components.Progress.Spinner
# alias Raxol.UI.Components.Progress.Circular
