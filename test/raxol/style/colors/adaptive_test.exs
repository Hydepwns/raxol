defmodule Raxol.Style.Colors.AdaptiveTest do
  use ExUnit.Case

  def init, do: {:ok, %{}}

  alias Raxol.Style.Colors.Adaptive
  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.Palette
  alias Raxol.Style.Colors.Theme

  setup do
    # Initialize the capabilities cache for each test
    Adaptive.init()
    :ok
  end

  describe "initialization" do
    test "init creates the capabilities cache" do
      assert Adaptive.init() == :ok

      # Test that we can use the cache after initialization
      color = Color.from_hex("#FF0000")
      assert %Color{} = Adaptive.adapt_color(color)
    end

    test "reset_detection clears capability cache" do
      # First set up a value in the cache by calling a detection function
      assert Adaptive.detect_color_support() in [
               :true_color,
               :ansi_256,
               :ansi_16,
               :no_color
             ]

      # Reset the detection
      assert Adaptive.reset_detection() == :ok

      # The next detection should rerun (but result is the same)
      assert Adaptive.detect_color_support() in [
               :true_color,
               :ansi_256,
               :ansi_16,
               :no_color
             ]
    end
  end

  describe "color support detection" do
    test "detects true color support from COLORTERM" do
      set_mock_env(%{"COLORTERM" => "truecolor"})
      assert Adaptive.detect_color_support() == :true_color
    end

    test "detects true color support from terminal name" do
      set_mock_env(%{"TERM" => "xterm-kitty"})
      assert Adaptive.detect_color_support() == :true_color
    end

    test "detects true color support from TERM_PROGRAM" do
      set_mock_env(%{"TERM_PROGRAM" => "iTerm.app"})
      assert Adaptive.detect_color_support() == :true_color
    end

    test "detects true color support from iTerm2 version" do
      set_mock_env(%{
        "TERM_PROGRAM" => "iTerm.app",
        "TERM_PROGRAM_VERSION" => "3.4.0"
      })

      assert Adaptive.detect_color_support() == :true_color
    end

    test "detects 256 color support" do
      set_mock_env(%{"TERM" => "xterm-256color"})
      assert Adaptive.detect_color_support() == :ansi_256
    end

    test "detects 16 color support" do
      set_mock_env(%{"TERM" => "xterm"})
      assert Adaptive.detect_color_support() == :ansi_16
    end

    test "detects no color support" do
      set_mock_env(%{"NO_COLOR" => "1"})
      assert Adaptive.detect_color_support() == :no_color
    end

    test "detects no color support for dumb terminal" do
      set_mock_env(%{"TERM" => "dumb"})
      assert Adaptive.detect_color_support() == :no_color
    end
  end

  describe "color adaptation" do
    test "adapt_color with true_color support returns original color" do
      set_mock_detection(:true_color)

      color = Color.from_hex("#FF5500")
      adapted = Adaptive.adapt_color(color)

      # With true color support, the adapted color should be the same
      assert adapted.hex == color.hex
    end

    test "adapt_color with ansi_256 support returns closest color" do
      set_mock_detection(:ansi_256)

      color = Color.from_hex("#FF5500")
      adapted = Adaptive.adapt_color(color)

      # With 256 color support, it should return a color close to the original
      # We can't test the exact value as it depends on the Color.to_ansi_256 implementation
      assert is_struct(adapted, Color)
    end

    test "adapt_color with ansi_16 support returns closest color" do
      set_mock_detection(:ansi_16)

      color = Color.from_hex("#FF5500")
      adapted = Adaptive.adapt_color(color)

      # With 16 color support, it should return a color from the 16-color palette
      assert is_struct(adapted, Color)
      assert adapted.ansi_code != nil
      assert adapted.ansi_code >= 0 and adapted.ansi_code <= 15
    end

    test "adapt_color with no color support returns grayscale" do
      set_mock_detection(:no_color)

      color = Color.from_hex("#FF5500")
      adapted = Adaptive.adapt_color(color)

      # With no color support, it should return a grayscale color
      assert is_struct(adapted, Color)
      assert adapted.r == adapted.g and adapted.g == adapted.b
    end
  end

  describe "palette adaptation" do
    test "adapt_palette adapts all colors in a palette" do
      set_mock_detection(:ansi_16)

      palette = Palette.nord()
      adapted = Adaptive.adapt_palette(palette)

      # The name should be modified
      assert adapted.name == "Nord (Adapted)"

      # All colors should be adapted
      adapted.colors
      |> Enum.each(fn {_name, color} ->
        assert color.ansi_code != nil
        assert color.ansi_code >= 0 and color.ansi_code <= 15
      end)
    end
  end

  describe "theme adaptation" do
    setup do
      # Initialize the theme registry - Removed as it seems unnecessary
      # Theme.init()
      :ok
    end

    test "adapt_theme adapts the theme's palette" do
      set_mock_detection(:ansi_16)

      theme = Theme.from_palette(Palette.nord(), "Nord")
      adapted = Adaptive.adapt_theme(theme)

      # The name should be modified
      assert adapted.name == "Nord (Adapted)"

      # The palette should be adapted
      assert adapted.palette.name == "Nord (Adapted)"
    end

    test "adapt_theme adapts dark theme to light terminal" do
      # Set up mock environment
      set_mock_detection(:true_color)
      set_mock_background(:light)

      # Create a dark theme and explicitly set dark_mode
      dark_theme = %{Theme.from_palette(Palette.dracula()) | dark_mode: true}
      assert dark_theme.dark_mode == true

      # Adapt it to the light terminal
      adapted = Adaptive.adapt_theme(dark_theme)

      # It should be converted to a light theme
      assert adapted.dark_mode == false
    end

    test "adapt_theme adapts light theme to dark terminal" do
      # Set up mock environment
      set_mock_detection(:true_color)
      set_mock_background(:dark)

      # Create a light theme
      light_theme = %{Theme.from_palette(Palette.nord()) | dark_mode: false}
      assert light_theme.dark_mode == false

      # Adapt it to the dark terminal
      adapted = Adaptive.adapt_theme(light_theme)

      # It should be converted to a dark theme
      assert adapted.dark_mode == true
    end
  end

  describe "optimal format" do
    test "get_optimal_format returns the same as detect_color_support" do
      set_mock_detection(:true_color)
      assert Adaptive.get_optimal_format() == :true_color

      set_mock_detection(:ansi_256)
      assert Adaptive.get_optimal_format() == :ansi_256

      set_mock_detection(:ansi_16)
      assert Adaptive.get_optimal_format() == :ansi_16

      set_mock_detection(:no_color)
      assert Adaptive.get_optimal_format() == :no_color
    end
  end

  # Utility functions for testing

  # Sets a mock detection result
  defp set_mock_detection(value) do
    # Reset the cache first
    Adaptive.reset_detection()

    # Use the module name to access the cache
    :ets.insert(:raxol_terminal_capabilities, {:color_support, value})
  end

  # Sets a mock background detection result
  defp set_mock_background(value) do
    # Reset the cache first
    Adaptive.reset_detection()

    # Use the module name to access the cache
    :ets.insert(:raxol_terminal_capabilities, {:background, value})
  end

  # Sets mock environment variables and ensures they are reset after the test
  defp set_mock_env(env_vars_to_set) do
    # Reset the detection cache
    Adaptive.reset_detection()

    # List of all relevant env vars for color detection
    relevant_vars = [
      "COLORTERM",
      "TERM",
      "TERM_PROGRAM",
      "TERM_PROGRAM_VERSION",
      "NO_COLOR"
    ]

    # Store original values of ALL relevant vars
    original_values =
      Enum.map(relevant_vars, fn key ->
        {key, System.get_env(key)}
      end)
      |> Map.new()

    # Clear all relevant vars first
    Enum.each(relevant_vars, &System.delete_env/1)

    # Set the specific mock environment variables for this test
    Enum.each(env_vars_to_set, fn {key, value} ->
      System.put_env(key, value)
    end)

    # Return an on_exit callback to restore original values
    on_exit(fn ->
      # Clear mocks first before restoring
      Enum.each(relevant_vars, &System.delete_env/1)
      # Restore original values
      Enum.each(original_values, fn {key, original_value} ->
        case original_value do
          # Already cleared
          nil -> :ok
          _ -> System.put_env(key, original_value)
        end
      end)

      # Important: Reset detection again after restoring env vars
      Adaptive.reset_detection()
    end)
  end
end
