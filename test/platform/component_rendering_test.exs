defmodule Raxol.Test.Platform.ComponentRenderingTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  
  alias Raxol.System.Platform
  
  # This test verifies that core UI components render correctly across platforms
  
  describe "core component rendering" do
    test "button component renders with correct styling" do
      platform = Platform.get_current_platform()
      
      # Capture the rendered output
      output = capture_io(fn ->
        # Render a basic button component
        Raxol.Components.Button.render("Click Me", style: :primary)
        |> IO.write()
      end)
      
      # All platforms should show the button text
      assert output =~ "Click Me"
      
      # Platform-specific button styling tests
      case platform do
        :windows ->
          assert has_basic_styling?(output)
          
        :macos ->
          assert has_basic_styling?(output)
          # macOS terminals generally support more advanced styling
          assert has_advanced_styling?(output)
          
        :linux ->
          assert has_basic_styling?(output)
          # Most Linux terminals support advanced styling
          assert has_advanced_styling?(output)
      end
    end
    
    test "box component renders borders correctly" do
      platform = Platform.get_current_platform()
      
      # Capture the rendered output
      output = capture_io(fn ->
        # Render a basic box component
        Raxol.Components.Box.render("Box Content", title: "Test Box")
        |> IO.write()
      end)
      
      # All platforms should show the box content and title
      assert output =~ "Box Content"
      assert output =~ "Test Box"
      
      # Check for box borders (varies by platform capability)
      if Platform.supports_feature?(:unicode) do
        # Unicode box drawing characters
        assert output =~ "┌" # top-left corner
        assert output =~ "┐" # top-right corner
        assert output =~ "└" # bottom-left corner
        assert output =~ "┘" # bottom-right corner
        assert output =~ "─" # horizontal line
        assert output =~ "│" # vertical line
      else
        # ASCII fallback
        assert output =~ "+" # corners
        assert output =~ "-" # horizontal line
        assert output =~ "|" # vertical line
      end
    end
    
    test "text component handles unicode correctly" do
      # Skip test if platform doesn't support unicode
      if not Platform.supports_feature?(:unicode) do
        flunk("Skipping test on platforms without Unicode support")
      end
      
      # Capture the rendered output with Unicode characters
      output = capture_io(fn ->
        Raxol.Components.Text.render("Unicode: → ★ … ◆ ◇", style: :info)
        |> IO.write()
      end)
      
      # The output should contain all unicode characters
      assert output =~ "→"
      assert output =~ "★"
      assert output =~ "…"
      assert output =~ "◆"
      assert output =~ "◇"
    end
    
    test "progress bar renders appropriately for platform" do
      platform = Platform.get_current_platform()
      
      # Capture the rendered output
      output = capture_io(fn ->
        Raxol.Components.ProgressBar.render(0.75, label: "Loading...")
        |> IO.write()
      end)
      
      # All platforms should show the label
      assert output =~ "Loading..."
      
      # Check for appropriate progress indicators based on platform
      if Platform.supports_feature?(:unicode) do
        # Unicode progress blocks
        assert output =~ "█" # full block
      else
        # ASCII fallback
        assert output =~ "#" # hash for progress
      end
      
      # Additional platform-specific checks
      case platform do
        :windows when not Platform.supports_feature?(:true_color) ->
          # Ensure Windows without true color falls back to basic colors
          refute output =~ "\e[38;2;" # No RGB color codes
          
        _ when Platform.supports_feature?(:true_color) ->
          # Platforms with true color should use RGB gradient
          assert output =~ "\e[38;2;" # RGB color codes
      end
    end
  end
  
  # Helper functions for checking styling in rendered output
  
  defp has_basic_styling?(output) do
    # Check for basic ANSI color codes
    output =~ "\e[3" || output =~ "\e[4"
  end
  
  defp has_advanced_styling?(output) do
    # Check for advanced styling features (true color, etc.)
    output =~ "\e[38;2;" || # RGB foreground
    output =~ "\e[48;2;" || # RGB background
    output =~ "\e[58" # Underline color
  end
end 