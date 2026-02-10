defmodule Raxol.Demo.DemoHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Demo.DemoHandler

  describe "help/0" do
    test "returns ok tuple with formatted help text" do
      assert {:ok, output} = DemoHandler.help()
      assert is_binary(output)
      assert output =~ "Raxol Terminal Demo"
      assert output =~ "Available Commands"
    end

    test "includes all registered commands" do
      {:ok, output} = DemoHandler.help()

      assert output =~ "help"
      assert output =~ "demo"
      assert output =~ "demo colors"
      assert output =~ "demo components"
      assert output =~ "demo emulation"
      assert output =~ "theme"
      assert output =~ "clear"
      assert output =~ "exit"
    end
  end

  describe "demo_colors/0" do
    test "returns ok tuple with color palette" do
      assert {:ok, output} = DemoHandler.demo_colors()
      assert is_binary(output)
      assert output =~ "ANSI Color Palette"
    end

    test "includes 16 standard colors section" do
      {:ok, output} = DemoHandler.demo_colors()
      assert output =~ "16 Standard Colors"
    end

    test "includes 256 color palette section" do
      {:ok, output} = DemoHandler.demo_colors()
      assert output =~ "256 Color Palette"
    end

    test "includes truecolor gradient section" do
      {:ok, output} = DemoHandler.demo_colors()
      assert output =~ "Truecolor Gradient"
    end

    test "includes text styles section" do
      {:ok, output} = DemoHandler.demo_colors()
      assert output =~ "Text Styles"
    end

    test "contains ANSI escape sequences" do
      {:ok, output} = DemoHandler.demo_colors()
      assert output =~ "\e["
    end
  end

  describe "demo_components/0" do
    test "returns ok tuple with component gallery" do
      assert {:ok, output} = DemoHandler.demo_components()
      assert is_binary(output)
      assert output =~ "UI Component Gallery"
    end

    test "includes buttons section" do
      {:ok, output} = DemoHandler.demo_components()
      assert output =~ "Buttons"
    end

    test "includes progress bars section" do
      {:ok, output} = DemoHandler.demo_components()
      assert output =~ "Progress Bars"
    end

    test "includes table section" do
      {:ok, output} = DemoHandler.demo_components()
      assert output =~ "Table"
    end

    test "includes box drawing section" do
      {:ok, output} = DemoHandler.demo_components()
      assert output =~ "Box Drawing"
    end
  end

  describe "demo_animation/0" do
    test "returns ok tuple with animation showcase" do
      assert {:ok, output} = DemoHandler.demo_animation()
      assert is_binary(output)
      assert output =~ "Animation Capabilities"
    end

    test "includes spinner styles" do
      {:ok, output} = DemoHandler.demo_animation()
      assert output =~ "Spinner Styles"
    end

    test "includes progress animation" do
      {:ok, output} = DemoHandler.demo_animation()
      assert output =~ "Progress Animation"
    end

    test "includes typing effect" do
      {:ok, output} = DemoHandler.demo_animation()
      assert output =~ "Typing Effect"
    end
  end

  describe "demo_emulation/0" do
    test "returns ok tuple with emulation info" do
      assert {:ok, output} = DemoHandler.demo_emulation()
      assert is_binary(output)
      assert output =~ "Terminal Emulation"
    end

    test "documents cursor movement sequences" do
      {:ok, output} = DemoHandler.demo_emulation()
      assert output =~ "Cursor Movement"
    end

    test "documents screen control sequences" do
      {:ok, output} = DemoHandler.demo_emulation()
      assert output =~ "Screen Control"
    end

    test "lists supported standards" do
      {:ok, output} = DemoHandler.demo_emulation()
      assert output =~ "VT100"
      assert output =~ "ANSI"
    end
  end

  describe "set_theme/1" do
    test "dracula theme returns ok with escape sequences" do
      assert {:ok, output} = DemoHandler.set_theme("dracula")
      assert output =~ "Theme set to Dracula"
      assert output =~ "\e["
    end

    test "nord theme returns ok with escape sequences" do
      assert {:ok, output} = DemoHandler.set_theme("nord")
      assert output =~ "Theme set to Nord"
    end

    test "monokai theme returns ok with escape sequences" do
      assert {:ok, output} = DemoHandler.set_theme("monokai")
      assert output =~ "Theme set to Monokai"
    end

    test "solarized theme returns ok with escape sequences" do
      assert {:ok, output} = DemoHandler.set_theme("solarized")
      assert output =~ "Theme set to Solarized"
    end

    test "unknown theme returns error" do
      assert {:error, message} = DemoHandler.set_theme("unknown")
      assert message =~ "Unknown theme"
    end

    test "theme names are case insensitive" do
      assert {:ok, _} = DemoHandler.set_theme("DRACULA")
      assert {:ok, _} = DemoHandler.set_theme("Nord")
      assert {:ok, _} = DemoHandler.set_theme("MONOKAI")
    end
  end

  describe "welcome_message/0" do
    test "returns welcome message string" do
      message = DemoHandler.welcome_message()
      assert is_binary(message)
    end

    test "includes Raxol branding" do
      message = DemoHandler.welcome_message()
      # ASCII art banner uses box characters for "RAXOL"
      assert message =~ "raxol.io" or message =~ "Terminal Application Framework"
    end

    test "includes help hint" do
      message = DemoHandler.welcome_message()
      assert message =~ "help"
    end

    test "includes clear screen sequence at start" do
      message = DemoHandler.welcome_message()
      assert String.starts_with?(message, "\e[2J\e[H")
    end
  end
end
