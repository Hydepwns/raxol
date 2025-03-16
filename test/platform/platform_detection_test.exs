defmodule Raxol.Test.Platform.PlatformDetectionTest do
  use ExUnit.Case, async: true

  alias Raxol.System.Platform

  describe "platform detection" do
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
  end
end 