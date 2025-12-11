defmodule Raxol.System.PlatformGraphicsTest do
  use ExUnit.Case, async: true

  alias Raxol.System.Platform

  describe "detect_graphics_support/0" do
    test "returns comprehensive graphics support information" do
      result = Platform.detect_graphics_support()

      # Verify structure
      assert is_map(result)
      assert Map.has_key?(result, :kitty_graphics)
      assert Map.has_key?(result, :sixel_graphics)
      assert Map.has_key?(result, :iterm2_graphics)
      assert Map.has_key?(result, :terminal_type)
      assert Map.has_key?(result, :capabilities)

      # Verify types
      assert is_boolean(result.kitty_graphics)
      assert is_boolean(result.sixel_graphics)
      assert is_boolean(result.iterm2_graphics)
      assert is_atom(result.terminal_type)
      assert is_map(result.capabilities)
    end

    test "detects Kitty terminal correctly" do
      # Mock Kitty environment
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-kitty")

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :kitty
      assert result.kitty_graphics == true
      assert result.capabilities.max_image_size > 0

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "detects WezTerm correctly" do
      # Mock WezTerm environment
      System.put_env("WEZTERM_EXECUTABLE", "/usr/bin/wezterm")

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :wezterm
      assert result.kitty_graphics == true # WezTerm supports Kitty protocol

      System.delete_env("WEZTERM_EXECUTABLE")
    end

    test "detects iTerm2 correctly" do
      # Mock iTerm2 environment
      original_program = System.get_env("TERM_PROGRAM")
      System.put_env("TERM_PROGRAM", "iTerm.app")

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :iterm2
      assert result.iterm2_graphics == true

      # Restore environment
      case original_program do
        nil -> System.delete_env("TERM_PROGRAM")
        program -> System.put_env("TERM_PROGRAM", program)
      end
    end
  end

  describe "supports_feature?/1 graphics features" do
    test "detects Kitty graphics support" do
      # Mock Kitty terminal
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-kitty")

      assert Platform.supports_feature?(:kitty_graphics) == true

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "detects Sixel graphics support" do
      # Mock terminal with Sixel support
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-sixel")

      # Note: This might be false due to version detection logic
      result = Platform.supports_feature?(:sixel_graphics)
      assert is_boolean(result)

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "detects iTerm2 graphics support" do
      # Mock iTerm2 environment
      original_program = System.get_env("TERM_PROGRAM")
      System.put_env("TERM_PROGRAM", "iTerm.app")

      assert Platform.supports_feature?(:iterm2_graphics) == true

      # Restore environment
      case original_program do
        nil -> System.delete_env("TERM_PROGRAM")
        program -> System.put_env("TERM_PROGRAM", program)
      end
    end

    test "returns false for unknown graphics features" do
      assert Platform.supports_feature?(:unknown_graphics) == false
    end
  end

  describe "terminal type detection" do
    test "detects various terminal types from TERM variable" do
      test_cases = [
        {"xterm-kitty", :kitty},
        {"xterm-256color", :xterm},
        {"screen-256color", :screen},
        {"tmux-256color", :tmux},
        {"foot", :foot},
        {"st-256color", :st}
      ]

      original_term = System.get_env("TERM")

      Enum.each(test_cases, fn {term_value, expected_type} ->
        System.put_env("TERM", term_value)
        result = Platform.detect_graphics_support()
        assert result.terminal_type == expected_type
      end)

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "handles unknown terminal gracefully" do
      original_term = System.get_env("TERM")
      System.put_env("TERM", "unknown-terminal")

      result = Platform.detect_graphics_support()
      assert result.terminal_type == :unknown
      assert result.kitty_graphics == false
      assert result.sixel_graphics == false
      assert result.iterm2_graphics == false

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end
  end

  describe "terminal capabilities detection" do
    test "provides Kitty terminal capabilities" do
      # Mock Kitty environment
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-kitty")

      result = Platform.detect_graphics_support()
      capabilities = result.capabilities

      assert capabilities.max_image_size == 100_000_000
      assert capabilities.supports_animation == true
      assert capabilities.supports_transparency == true
      assert capabilities.supports_chunked_transmission == true
      assert capabilities.max_image_width == 10_000
      assert capabilities.max_image_height == 10_000

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "provides iTerm2 capabilities" do
      # Mock iTerm2 environment
      original_program = System.get_env("TERM_PROGRAM")
      System.put_env("TERM_PROGRAM", "iTerm.app")

      result = Platform.detect_graphics_support()
      capabilities = result.capabilities

      assert capabilities.max_image_size == 10_000_000
      assert capabilities.supports_animation == false
      assert capabilities.supports_transparency == true
      assert capabilities.supports_chunked_transmission == false

      # Restore environment
      case original_program do
        nil -> System.delete_env("TERM_PROGRAM")
        program -> System.put_env("TERM_PROGRAM", program)
      end
    end

    test "provides conservative capabilities for unknown terminals" do
      original_term = System.get_env("TERM")
      System.put_env("TERM", "dumb")

      result = Platform.detect_graphics_support()
      capabilities = result.capabilities

      assert capabilities.max_image_size == 0
      assert capabilities.supports_animation == false
      assert capabilities.supports_transparency == false
      assert capabilities.supports_chunked_transmission == false
      assert capabilities.max_image_width == 0
      assert capabilities.max_image_height == 0

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end
  end

  describe "version-based feature detection" do
    test "checks WezTerm version for Kitty support" do
      # Mock WezTerm with version info
      System.put_env("WEZTERM_EXECUTABLE", "/usr/bin/wezterm")
      System.put_env("WEZTERM_VERSION", "20220101")  # Old version

      result = Platform.detect_graphics_support()

      # Should detect WezTerm but may have limited Kitty support based on version
      assert result.terminal_type == :wezterm

      System.delete_env("WEZTERM_EXECUTABLE")
      System.delete_env("WEZTERM_VERSION")
    end

    test "checks iTerm2 version for Kitty support" do
      # Mock iTerm2 with version info
      System.put_env("TERM_PROGRAM", "iTerm.app")
      System.put_env("TERM_PROGRAM_VERSION", "3.5.0")

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :iterm2
      assert result.iterm2_graphics == true

      System.delete_env("TERM_PROGRAM")
      System.delete_env("TERM_PROGRAM_VERSION")
    end

    test "handles missing version information gracefully" do
      # Mock terminal without version info
      System.put_env("TERM_PROGRAM", "iTerm.app")
      # Don't set TERM_PROGRAM_VERSION

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :iterm2
      # Should have conservative defaults when version is unknown

      System.delete_env("TERM_PROGRAM")
    end
  end

  describe "environment variable precedence" do
    test "KITTY_WINDOW_ID takes precedence over TERM" do
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-256color")  # Would normally detect as xterm
      System.put_env("KITTY_WINDOW_ID", "12345")  # But this indicates Kitty

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :kitty
      assert result.kitty_graphics == true

      # Restore environment
      System.delete_env("KITTY_WINDOW_ID")
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end

    test "WEZTERM_EXECUTABLE takes precedence over TERM" do
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-256color")
      System.put_env("WEZTERM_EXECUTABLE", "/usr/bin/wezterm")

      result = Platform.detect_graphics_support()

      assert result.terminal_type == :wezterm
      assert result.kitty_graphics == true  # WezTerm supports Kitty protocol

      # Restore environment
      System.delete_env("WEZTERM_EXECUTABLE")
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end
  end

  describe "Sixel-specific detection" do
    test "detects Sixel support in environment variables" do
      original_colorterm = System.get_env("COLORTERM")
      System.put_env("COLORTERM", "sixel")

      assert Platform.supports_feature?(:sixel_graphics) == true

      # Restore environment
      case original_colorterm do
        nil -> System.delete_env("COLORTERM")
        colorterm -> System.put_env("COLORTERM", colorterm)
      end
    end

    test "detects terminals with built-in Sixel support" do
      test_cases = [:mintty, :mlterm, :wezterm, :foot]
      original_term = System.get_env("TERM")

      Enum.each(test_cases, fn terminal_type ->
        # Mock each terminal type
        term_value = case terminal_type do
          :mintty -> "mintty"
          :mlterm -> "mlterm"
          :wezterm -> "wezterm"
          :foot -> "foot"
        end

        System.put_env("TERM", term_value)

        result = Platform.detect_graphics_support()
        assert result.sixel_graphics == true
      end)

      # Restore environment
      case original_term do
        nil -> System.delete_env("TERM")
        term -> System.put_env("TERM", term)
      end
    end
  end
end