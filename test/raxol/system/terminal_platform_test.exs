defmodule Raxol.System.TerminalPlatformTest do
  use ExUnit.Case, async: true
  alias Raxol.System.TerminalPlatform

  describe "get_terminal_capabilities/0" do
    test "returns a map with all expected keys" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :name)
      assert Map.has_key?(capabilities, :version)
      assert Map.has_key?(capabilities, :features)
      assert Map.has_key?(capabilities, :colors)
      assert Map.has_key?(capabilities, :unicode)
      assert Map.has_key?(capabilities, :input)
      assert Map.has_key?(capabilities, :output)
    end

    test "features list contains only supported features" do
      features = TerminalPlatform.get_supported_features()

      assert is_list(features)
      assert Enum.all?(features, &is_atom/1)

      assert Enum.all?(
               features,
               &(&1 in [
                   :colors_256,
                   :true_color,
                   :unicode,
                   :mouse,
                   :clipboard,
                   :bracketed_paste,
                   :focus,
                   :title
                 ])
             )
    end
  end

  describe "supports_feature?/1" do
    test "returns boolean for valid features" do
      assert is_boolean(TerminalPlatform.supports_feature?(:true_color))
      assert is_boolean(TerminalPlatform.supports_feature?(:unicode))
      assert is_boolean(TerminalPlatform.supports_feature?(:mouse))
      assert is_boolean(TerminalPlatform.supports_feature?(:clipboard))
      assert is_boolean(TerminalPlatform.supports_feature?(:bracketed_paste))
      assert is_boolean(TerminalPlatform.supports_feature?(:focus))
      assert is_boolean(TerminalPlatform.supports_feature?(:title))
    end

    test "feature support matches capabilities list" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      features = capabilities.features

      assert TerminalPlatform.supports_feature?(:true_color) ==
               :true_color in features

      assert TerminalPlatform.supports_feature?(:unicode) ==
               :unicode in features

      assert TerminalPlatform.supports_feature?(:mouse) == :mouse in features

      assert TerminalPlatform.supports_feature?(:clipboard) ==
               :clipboard in features

      assert TerminalPlatform.supports_feature?(:bracketed_paste) ==
               :bracketed_paste in features

      assert TerminalPlatform.supports_feature?(:focus) == :focus in features
      assert TerminalPlatform.supports_feature?(:title) == :title in features
    end
  end

  describe "get_supported_features/0" do
    test "returns a list of supported features" do
      features = TerminalPlatform.get_supported_features()

      assert is_list(features)
      assert Enum.all?(features, &is_atom/1)

      assert Enum.all?(
               features,
               &(&1 in [
                   :colors_256,
                   :true_color,
                   :unicode,
                   :mouse,
                   :clipboard,
                   :bracketed_paste,
                   :focus,
                   :title
                 ])
             )
    end

    test "matches features in capabilities" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert is_list(capabilities.features)
      assert capabilities.features == TerminalPlatform.get_supported_features()
    end
  end

  describe "color capabilities" do
    test "reports basic color support" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert capabilities.colors.basic == true
    end

    test "reports true color support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.colors.true_color ==
               TerminalPlatform.supports_feature?(:true_color)
    end

    test "has valid color palette" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert capabilities.colors.palette in ["default", "xterm-256color"]
    end
  end

  describe "unicode capabilities" do
    test "reports unicode support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.unicode.support ==
               TerminalPlatform.supports_feature?(:unicode)
    end

    test "has valid unicode width" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert capabilities.unicode.width in [:ambiguous, :narrow, :wide]
    end

    test "reports emoji support" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert is_boolean(capabilities.unicode.emoji)
    end
  end

  describe "input capabilities" do
    test "reports mouse support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.input.mouse ==
               TerminalPlatform.supports_feature?(:mouse)
    end

    test "reports bracketed paste support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.input.bracketed_paste ==
               TerminalPlatform.supports_feature?(:bracketed_paste)
    end

    test "reports focus support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.input.focus ==
               TerminalPlatform.supports_feature?(:focus)
    end
  end

  describe "output capabilities" do
    test "reports title support consistently" do
      capabilities = TerminalPlatform.get_terminal_capabilities()

      assert capabilities.output.title ==
               TerminalPlatform.supports_feature?(:title)
    end

    test "reports basic output features" do
      capabilities = TerminalPlatform.get_terminal_capabilities()
      assert capabilities.output.bell == true
      assert capabilities.output.alternate_screen == true
    end
  end
end
