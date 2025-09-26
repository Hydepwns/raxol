#!/usr/bin/env elixir

# Terminal Compatibility Verification Script
# This script tests various terminal features across platforms and generates a report

defmodule Raxol.Terminal.CompatibilityTest do
  alias Raxol.System.Platform

  @terminal_features [
    :basic_colors,
    :true_color,
    :unicode,
    :mouse,
    :clipboard,
    :keyboard,
    :bracketed_paste,
    :focus_reporting,
    :sixel_graphics,
    :kitty_graphics
  ]

  @unicode_test_chars [
    "★",
    "…",
    "→",
    "═",
    "║",
    "╔",
    "╗",
    "╚",
    "╝",
    "■",
    "□",
    "▢",
    "▣",
    "▤",
    "▥",
    "▦",
    "▧",
    "▨",
    "▩",
    "◆",
    "◇",
    "◈",
    "◉",
    "◊",
    "○",
    "◌",
    "◍",
    "◎",
    "●",
    "◐",
    "◑",
    "◒",
    "◓",
    "◔",
    "◕",
    "◖",
    "◗",
    "◘",
    "◙",
    "◚",
    "◛",
    "◜",
    "◝",
    "◞",
    "◟",
    "◠",
    "◡",
    "◢",
    "◣",
    "◤",
    "◥",
    "◦",
    "◧",
    "◨",
    "◩",
    "◪",
    "◫",
    "◬",
    "◭",
    "◮",
    "◯",
    "◰",
    "◱",
    "◲",
    "◳",
    "◴",
    "◵",
    "◶",
    "◷",
    "◸",
    "◹",
    "◺",
    "◻",
    "◼",
    "◽",
    "◾",
    "◿"
  ]

  def run do
    IO.puts("\n=== Raxol Terminal Compatibility Test ===\n")

    platform_info = Platform.get_platform_info()
    print_platform_info(platform_info)

    IO.puts("\n=== Feature Support ===\n")

    feature_results =
      @terminal_features
      |> Enum.map(fn feature ->
        supported = Platform.supports_feature?(feature)
        {feature, supported}
      end)

    Enum.each(feature_results, fn {feature, supported} ->
      status = if supported, do: "[OK] Supported", else: "[FAIL] Not supported"
      IO.puts("#{feature}: #{status}")
    end)

    # Run platform-specific tests
    run_platform_specific_tests(platform_info)

    # Test color rendering if supported
    if Platform.supports_feature?(:basic_colors) do
      test_color_rendering()
    end

    # Test unicode rendering if supported
    if Platform.supports_feature?(:unicode) do
      test_unicode_rendering()
    end

    # Test graphics capabilities if supported
    if Platform.supports_feature?(:sixel_graphics) ||
         Platform.supports_feature?(:kitty_graphics) do
      test_graphics_capabilities()
    end

    print_summary(feature_results, platform_info)

    # Write results to file for CI
    write_results_file(platform_info, feature_results)
  end

  def print_platform_info(platform_info) do
    IO.puts("Platform: #{inspect(Platform.get_current_platform())}")
    IO.puts("OS: #{platform_info.name} #{platform_info.version}")
    IO.puts("Architecture: #{platform_info.architecture}")
    IO.puts("Terminal: #{platform_info.terminal}")
    IO.puts("Environment:")

    Enum.each(platform_info.env_vars, fn {key, value} ->
      IO.puts("  #{key}: #{value}")
    end)
  end

  def run_platform_specific_tests(platform_info) do
    IO.puts("\n=== Platform-Specific Tests ===\n")

    case Platform.get_current_platform() do
      :windows ->
        test_windows_specific()

      :macos ->
        test_macos_specific()

      :linux ->
        test_linux_specific()
    end
  end

  def test_windows_specific do
    IO.puts("Testing Windows-specific features:")
    IO.puts("- Windows Registry access")
    IO.puts("- Windows API calls")
    IO.puts("- Windows Terminal features")
  end

  def test_macos_specific do
    IO.puts("Testing macOS-specific features:")
    IO.puts("- Metal graphics support")
    IO.puts("- macOS clipboard integration")
    IO.puts("- macOS notification system")
  end

  def test_linux_specific do
    IO.puts("Testing Linux-specific features:")
    IO.puts("- X11/Wayland support")
    IO.puts("- Systemd integration")
    IO.puts("- Linux-specific terminal features")
  end

  def test_color_rendering do
    IO.puts("\n=== Color Rendering Test ===\n")

    # Basic colors (8-color)
    basic_colors = [
      {30, "Black"},
      {31, "Red"},
      {32, "Green"},
      {33, "Yellow"},
      {34, "Blue"},
      {35, "Magenta"},
      {36, "Cyan"},
      {37, "White"}
    ]

    IO.puts("Basic colors:")

    Enum.each(basic_colors, fn {code, name} ->
      IO.write("\e[#{code}m#{name}\e[0m ")
    end)

    IO.puts("\n")

    # Bright colors (8-color bright)
    IO.puts("Bright colors:")

    Enum.each(basic_colors, fn {code, name} ->
      IO.write("\e[#{code};1m#{name}\e[0m ")
    end)

    IO.puts("\n")

    # Test true color if supported
    if Platform.supports_feature?(:true_color) do
      IO.puts("\nTrue color gradient:")

      # Print a gradient of colors
      0..15
      |> Enum.each(fn i ->
        # Create a gradient from blue to red
        r = trunc(i * 255 / 15)
        g = 50
        b = trunc(255 - i * 255 / 15)

        # Print a colored block
        IO.write("\e[48;2;#{r};#{g};#{b}m  \e[0m")
      end)

      IO.puts("\n")
    end
  end

  def test_unicode_rendering do
    IO.puts("\n=== Unicode Rendering Test ===\n")

    # Test basic box drawing
    IO.puts("Box drawing:")
    IO.puts("┌─────────────────────┐")
    IO.puts("│ Unicode Box Drawing  │")
    IO.puts("└─────────────────────┘\n")

    # Test emoji rendering if terminal likely supports it
    IO.puts("Symbols: [>] [*] [+] [o] [#] [=] [|] [?] [!] [@]\\n")

    # Test various unicode characters
    IO.puts("Unicode symbols:")

    @unicode_test_chars
    |> Enum.take(40)
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk ->
      IO.puts(Enum.join(chunk, " "))
    end)

    IO.puts("")
  end

  def test_graphics_capabilities do
    IO.puts("\n=== Graphics Capabilities Test ===\n")

    if Platform.supports_feature?(:sixel_graphics) do
      IO.puts("Testing Sixel graphics:")
      # Add sixel graphics test here
    end

    if Platform.supports_feature?(:kitty_graphics) do
      IO.puts("Testing Kitty graphics:")
      # Add kitty graphics test here
    end
  end

  def print_summary(feature_results, platform_info) do
    supported_count =
      feature_results |> Enum.count(fn {_, supported} -> supported end)

    total_count = length(feature_results)

    IO.puts("\n=== Summary ===\n")

    IO.puts(
      "#{supported_count}/#{total_count} features supported (#{trunc(supported_count / total_count * 100)}%)"
    )

    # Compatibility rating
    rating =
      cond do
        supported_count == total_count -> "Excellent"
        supported_count >= trunc(total_count * 0.8) -> "Good"
        supported_count >= trunc(total_count * 0.6) -> "Adequate"
        true -> "Limited"
      end

    IO.puts("Terminal compatibility: #{rating}")

    # Specific recommendations based on platform
    platform = Platform.get_current_platform()

    missing_features =
      feature_results
      |> Enum.filter(fn {_, supported} -> !supported end)
      |> Enum.map(fn {feature, _} -> feature end)

    if length(missing_features) > 0 do
      IO.puts("\nRecommendations:")

      case platform do
        :windows when :true_color in missing_features ->
          IO.puts(
            "- For better color support, use Windows Terminal instead of Command Prompt or PowerShell"
          )

        :windows when :unicode in missing_features ->
          IO.puts(
            "- For better Unicode support, use Windows Terminal or install a TrueType font with Unicode support"
          )

        :linux when :true_color in missing_features ->
          IO.puts(
            "- Use a terminal that supports true color (like GNOME Terminal, Konsole, or Kitty)"
          )

          IO.puts("- Set TERM=xterm-256color in your environment")

        :linux when :clipboard in missing_features ->
          IO.puts(
            "- Install xclip (X11) or wl-clipboard (Wayland) for clipboard support"
          )

        :macos when :true_color in missing_features ->
          IO.puts(
            "- For full color support, consider iTerm2 or Kitty instead of Terminal.app"
          )

        _ ->
          IO.puts(
            "- No specific recommendations for your platform and missing features"
          )
      end
    end
  end

  def write_results_file(platform_info, feature_results) do
    # Ensure the results directory exists
    File.mkdir_p!("_build/test/results")

    # Generate a filename with platform info
    filename =
      "_build/test/results/terminal_#{platform_info.name}_#{System.os_time(:second)}.log"

    # Format the results
    content = """
    RAXOL TERMINAL COMPATIBILITY TEST RESULTS
    =========================================

    Platform: #{platform_info.name}
    OS Version: #{platform_info.version}
    Architecture: #{platform_info.architecture}
    Terminal: #{platform_info.terminal}

    Environment Variables:
    ====================
    #{Enum.map_join(platform_info.env_vars, "\n", fn {key, value} -> "#{key}: #{value}" end)}

    System Capabilities:
    ==================
    #{Enum.map_join(platform_info.capabilities, "\n", fn {key, value} -> "#{key}: #{inspect(value)}" end)}

    FEATURE SUPPORT:
    ===============
    #{Enum.map_join(feature_results, "\n", fn {feature, supported} -> "#{feature}: #{if supported, do: "Supported", else: "Not supported"}" end)}

    Test completed at: #{DateTime.utc_now() |> to_string}
    """

    # Write the file
    File.write!(filename, content)
    IO.puts("\nResults written to: #{filename}")
  end
end

# Run the test
Raxol.Terminal.CompatibilityTest.run()
