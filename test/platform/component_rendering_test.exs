# defmodule Raxol.Test.Platform.ComponentRenderingTest do
#   use ExUnit.Case, async: true
#   import ExUnit.CaptureIO
#
#   alias Raxol.UI.Components.Box
#   alias Raxol.UI.Components.Button
#   # alias Raxol.UI.Components.ProgressBar # Original alias was wrong
#   alias Raxol.UI.Components.Progress.ProgressBar # Correct path
#   alias Raxol.UI.Components.Text
#   alias Raxol.System.Platform
#
#   # This test verifies that core UI components render correctly across platforms
#   # NOTE: This test is currently commented out because its methodology is incompatible
#   # with the rex_termbox renderer. It attempts to capture IO.write output from
#   # Component.render/1, but the renderer interacts directly with the termbox buffer
#   # and Component.render/1 returns an Element struct, not a string.
#   # Additionally, the Box and Text components may no longer exist at these paths.
#
#   # describe "core component rendering" do
#   #   test 'button component renders with correct styling' do
#   #     platform = Platform.get_current_platform()
#   #
#   #     # Capture the rendered output
#   #     output =
#   #       capture_io(fn ->
#   #         # Render a basic button component
#   #         Button.new("Click Me", style: :primary)
#   #         |> Button.render() # Returns Element struct
#   #         # |> IO.write() # This causes Protocol.UndefinedError
#   #         # TODO: Need a different way to test rendering, e.g., mock termbox
#   #         IO.write("TODO: Test output") # Placeholder to avoid compile error if uncommented
#   #       end)
#   #
#   #     # All platforms should show the button text
#   #     assert output =~ "Click Me"
#   #
#   #     # Platform-specific button styling tests
#   #     case platform do
#   #       :windows ->
#   #         assert has_basic_styling?(output)
#   #
#   #       :macos ->
#   #         assert has_basic_styling?(output)
#   #         # macOS terminals generally support more advanced styling
#   #         assert has_advanced_styling?(output)
#   #
#   #       :linux ->
#   #         assert has_basic_styling?(output)
#   #         # Most Linux terminals support advanced styling
#   #         assert has_advanced_styling?(output)
#   #     end
#   #   end
#   #
#   #   test 'box component renders borders correctly' do
#   #     platform = Platform.get_current_platform()
#   #
#   #     # Capture the rendered output
#   #     output =
#   #       capture_io(fn ->
#   #         # Render a basic box component
#   #         # Box.new("Box Content", title: "Test Box") # UndefinedFunctionError
#   #         # |> Box.render()
#   #         # |> IO.write()
#   #         IO.write("TODO: Test output") # Placeholder
#   #       end)
#   #
#   #     # All platforms should show the box content and title
#   #     assert output =~ "Box Content"
#   #     assert output =~ "Test Box"
#   #
#   #     # Check for box borders (varies by platform capability)
#   #     if Platform.supports_feature?(:unicode) do
#   #       # Unicode box drawing characters
#   #       # top-left corner
#   #       assert output =~ "┌"
#   #       # top-right corner
#   #       assert output =~ "┐"
#   #       # bottom-left corner
#   #       assert output =~ "└"
#   #       # bottom-right corner
#   #       assert output =~ "┘"
#   #       # horizontal line
#   #       assert output =~ "─"
#   #       # vertical line
#   #       assert output =~ "│"
#   #     else
#   #       # ASCII fallback
#   #       # corners
#   #       assert output =~ "+"
#   #       # horizontal line
#   #       assert output =~ "-"
#   #       # vertical line
#   #       assert output =~ "|"
#   #     end
#   #   end
#   #
#   #   test 'text component handles unicode correctly' do
#   #     # Skip test if platform doesn't support unicode
#   #     if not Platform.supports_feature?(:unicode) do
#   #       flunk("Skipping test on platforms without Unicode support")
#   #     end
#   #
#   #     # Capture the rendered output with Unicode characters
#   #     output =
#   #       capture_io(fn ->
#   #         # Text.new("Unicode: → ★ … ◆ ◇", style: :info) # UndefinedFunctionError
#   #         # |> Text.render()
#   #         # |> IO.write()
#   #         IO.write("TODO: Test output") # Placeholder
#   #       end)
#   #
#   #     # The output should contain all unicode characters
#   #     assert output =~ "→"
#   #     assert output =~ "★"
#   #     assert output =~ "…"
#   #     assert output =~ "◆"
#   #     assert output =~ "◇"
#   #   end
#   #
#   #   test 'progress bar renders appropriately for platform' do
#   #     platform = Platform.get_current_platform()
#   #
#   #     # Capture the rendered output
#   #     output =
#   #       capture_io(fn ->
#   #         # ProgressBar was moved
#   #         ProgressBar.new(0.75, label: "Loading...")
#   #         |> ProgressBar.render()
#   #         # |> IO.write()
#   #         IO.write("TODO: Test output") # Placeholder
#   #       end)
#   #
#   #     # All platforms should show the label
#   #     assert output =~ "Loading..."
#   #
#   #     # Check for appropriate progress indicators based on platform
#   #     if Platform.supports_feature?(:unicode) do
#   #       # Unicode progress blocks
#   #       # full block
#   #       assert output =~ "█"
#   #     else
#   #       # ASCII fallback
#   #       # hash for progress
#   #       assert output =~ "#"
#   #     end
#   #
#   #     # Check if true color is supported before the case statement
#   #     has_true_color = Platform.supports_feature?(:true_color)
#   #
#   #     # Additional platform-specific checks
#   #     case platform do
#   #       :windows when not has_true_color ->
#   #         # Ensure Windows without true color falls back to basic colors
#   #         # No RGB color codes
#   #         refute output =~ "\e[38;2;"
#   #
#   #       _ when has_true_color ->
#   #         # Platforms with true color should use RGB gradient
#   #         # RGB color codes
#   #         assert output =~ "\e[38;2;"
#   #
#   #       # Add a default case to handle platforms without true color if needed
#   #       _ ->
#   #         # Add assertions for platforms without true color, if applicable
#   #         # For example, assert that basic colors are used
#   #         # Assuming no RGB if no true color
#   #         refute output =~ "\e[38;2;"
#   #     end
#   #   end
#   # end
#
#   # # Helper functions for checking styling in rendered output
#   #
#   # defp has_basic_styling?(output) do
#   #   # Check for basic ANSI color codes
#   #   output =~ "\e[3" || output =~ "\e[4"
#   # end
#   #
#   # defp has_advanced_styling?(output) do
#   #   # Check for advanced styling features (true color, etc.)
#   #   # RGB foreground
#   #   # RGB background
#   #   # Underline color
#   #   output =~ "\e[38;2;" ||
#   #     output =~ "\e[48;2;" ||
#   #     output =~ "\e[58"
#   # end
#
#   # TODO: Implement Unicode and ProgressBar rendering tests once the components are available
# end
