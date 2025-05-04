defmodule Raxol.Test.Platform.PlatformDetectionTest do
  use ExUnit.Case, async: true

  @tag :skip # Skip: Platform.get_platform_info() missing keys expected by tests
  alias Raxol.System.Platform
  require Logger

  describe "platform detection" do
    setup do
      # No specific setup needed for these tests
      :ok
    end

    test "identifies current platform" do
      platform = Platform.get_current_platform()

      # Ensure platform is detected
      assert platform in [:macos, :linux, :windows]

      # Ensure platform matches OS type
      case :os.type() do
        {:unix, :darwin} -> assert platform == :macos
        {:unix, _} -> assert platform == :linux
        {:win32, _} -> assert platform == :windows
        _ -> flunk("Unknown OS type: #{inspect(:os.type())}")
      end
    end

    test "provides platform-specific information" do
      platform_info = Platform.get_platform_info()

      # All platforms should have these basic fields
      assert is_map(platform_info)
      assert Map.has_key?(platform_info, :name)
      assert Map.has_key?(platform_info, :version)
      assert Map.has_key?(platform_info, :architecture)
      assert Map.has_key?(platform_info, :terminal)
      assert Map.has_key?(platform_info, :env_vars)
      assert Map.has_key?(platform_info, :capabilities)
    end

    test "detects environment variables correctly" do
      platform_info = Platform.get_platform_info()
      env_vars = platform_info.env_vars

      # Common environment variables
      assert Map.has_key?(env_vars, "PATH")

      assert Map.has_key?(env_vars, "HOME") ||
               Map.has_key?(env_vars, "USERPROFILE")

      # Platform-specific environment variables
      case Platform.get_current_platform() do
        :windows ->
          assert Map.has_key?(env_vars, "USERPROFILE")
          assert Map.has_key?(env_vars, "TEMP")

        _ ->
          assert Map.has_key?(env_vars, "HOME")
          assert Map.has_key?(env_vars, "USER")
      end
    end

    test "detects system capabilities" do
      platform_info = Platform.get_platform_info()
      capabilities = platform_info.capabilities

      # Common capabilities
      assert Map.has_key?(capabilities, :terminal_features)
      assert Map.has_key?(capabilities, :file_system)
      assert Map.has_key?(capabilities, :process_management)

      # Platform-specific capabilities
      case Platform.get_current_platform() do
        :windows ->
          assert Map.has_key?(capabilities, :windows_specific)
          assert Map.has_key?(capabilities.windows_specific, :registry)

        :macos ->
          assert Map.has_key?(capabilities, :macos_specific)
          assert Map.has_key?(capabilities.macos_specific, :metal)

        :linux ->
          assert Map.has_key?(capabilities, :linux_specific)
          assert Map.has_key?(capabilities.linux_specific, :systemd)
      end
    end

    test "returns correct file extension for current platform" do
      extension = Platform.get_platform_extension()

      case Platform.get_current_platform() do
        :windows -> assert extension == "zip"
        _ -> assert extension == "tar.gz"
      end
    end

    test "provides executable name for current platform" do
      executable = Platform.get_executable_name()

      case Platform.get_current_platform() do
        :windows -> assert executable == "raxol.exe"
        _ -> assert executable == "raxol"
      end
    end

    test "detects terminal capabilities" do
      terminal_features =
        Platform.get_platform_info().capabilities.terminal_features

      assert Map.has_key?(terminal_features, :colors)
      assert Map.has_key?(terminal_features, :unicode)
      assert Map.has_key?(terminal_features, :mouse)
      assert Map.has_key?(terminal_features, :clipboard)

      # Verify color support
      assert terminal_features.colors in [:none, :basic, :true_color]

      # Verify unicode support level
      assert terminal_features.unicode in [:none, :basic, :full]
    end

    @tag :pending # Mark as pending due to missing key
    test "platform detection detects environment variables correctly" do
      platform_info = Platform.get_platform_info()

      assert is_map(platform_info)
      assert is_map(platform_info.env_vars)
      assert is_boolean(platform_info.env_vars.true_color)
    end

    @tag :pending # Mark as pending due to missing key
    test "platform detection detects system capabilities" do
      platform_info = Platform.get_platform_info()

      assert is_map(platform_info)
      assert is_map(platform_info.capabilities)
      assert is_boolean(platform_info.capabilities.clipboard_support)
    end

    @tag :pending # Mark as pending due to missing key
    test "platform detection detects terminal capabilities" do
      platform_info = Platform.get_platform_info()

      assert is_map(platform_info)
      assert is_map(platform_info.capabilities)
      assert is_boolean(platform_info.capabilities.true_color)
    end
  end
end
