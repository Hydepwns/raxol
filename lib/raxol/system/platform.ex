defmodule Raxol.System.Platform do
  @moduledoc """
  Platform-specific functionality and detection for Raxol.
  
  This module handles detection of the current platform, providing platform-specific
  information, and managing platform-dependent operations.
  """

  @doc """
  Returns the current platform as an atom.
  
  ## Returns
  
  * `:macos` - macOS (Darwin)
  * `:linux` - Linux variants
  * `:windows` - Windows
  * `:unknown` - Unrecognized platform
  
  ## Examples
  
      iex> Platform.get_current_platform()
      :macos
  """
  @spec get_current_platform() :: atom()
  def get_current_platform do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, _} -> :linux
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end
  
  @doc """
  Returns the platform name as a string.
  
  ## Returns
  
  * `"macos"` - macOS (Darwin)
  * `"linux"` - Linux variants
  * `"windows"` - Windows
  * `"unknown"` - Unrecognized platform
  
  ## Examples
  
      iex> Platform.get_platform_name()
      "macos"
  """
  @spec get_platform_name() :: String.t()
  def get_platform_name do
    case get_current_platform() do
      :macos -> "macos"
      :linux -> "linux"
      :windows -> "windows"
      _ -> "unknown"
    end
  end
  
  @doc """
  Returns the file extension for the current platform.
  
  ## Returns
  
  * `"zip"` - Windows platforms
  * `"tar.gz"` - Unix platforms (macOS, Linux)
  
  ## Examples
  
      iex> Platform.get_platform_extension()
      "tar.gz"
  """
  @spec get_platform_extension() :: String.t()
  def get_platform_extension do
    case get_current_platform() do
      :windows -> "zip"
      _ -> "tar.gz"
    end
  end
  
  @doc """
  Returns the executable name for the current platform.
  
  ## Returns
  
  * `"raxol.exe"` - Windows platforms
  * `"raxol"` - Unix platforms (macOS, Linux)
  
  ## Examples
  
      iex> Platform.get_executable_name()
      "raxol"
  """
  @spec get_executable_name() :: String.t()
  def get_executable_name do
    case get_current_platform() do
      :windows -> "raxol.exe"
      _ -> "raxol"
    end
  end
  
  @doc """
  Gathers detailed information about the current platform.
  
  ## Returns
  
  A map containing platform details including:
  
  * `:name` - Platform name (e.g., "macOS", "Linux", "Windows")
  * `:version` - OS version if available
  * `:architecture` - CPU architecture (e.g., "x86_64", "arm64")
  * `:terminal` - Current terminal information if available
  
  ## Examples
  
      iex> Platform.get_platform_info()
      %{
        name: "macOS",
        version: "12.6",
        architecture: "arm64",
        terminal: "iTerm.app"
      }
  """
  @spec get_platform_info() :: map()
  def get_platform_info do
    platform = get_current_platform()
    
    # Base info map
    info = %{
      name: platform,
      version: get_os_version(),
      architecture: get_architecture(),
      terminal: get_terminal_info()
    }
    
    # Add platform-specific fields
    case platform do
      :macos -> Map.merge(info, get_macos_info())
      :linux -> Map.merge(info, get_linux_info())
      :windows -> Map.merge(info, get_windows_info())
      _ -> info
    end
  end
  
  @doc """
  Detects if the feature is supported on the current platform.
  
  ## Parameters
  
  * `feature` - Feature name as an atom (e.g., `:true_color`, `:unicode`, `:mouse`)
  
  ## Returns
  
  * `true` - Feature is supported on the current platform
  * `false` - Feature is not supported or support is uncertain
  
  ## Examples
  
      iex> Platform.supports_feature?(:true_color)
      true
  """
  @spec supports_feature?(atom()) :: boolean()
  def supports_feature?(feature) do
    case {get_current_platform(), feature} do
      # Features fully supported across all platforms
      {_, :keyboard} -> true
      {_, :basic_colors} -> true
      
      # Platform-specific feature support
      {:macos, :true_color} -> true
      {:macos, :unicode} -> true
      {:macos, :mouse} -> true
      {:macos, :clipboard} -> true
      
      {:linux, :true_color} -> true
      {:linux, :unicode} -> true
      {:linux, :mouse} -> true
      {:linux, :clipboard} -> detect_linux_clipboard_support()
      
      {:windows, :true_color} -> detect_windows_true_color()
      {:windows, :unicode} -> detect_windows_unicode()
      {:windows, :mouse} -> true
      {:windows, :clipboard} -> true
      
      # Default for unknown features/platforms
      {_, _} -> false
    end
  end
  
  # Private helper functions
  
  defp get_os_version do
    case get_current_platform() do
      :macos -> get_macos_version()
      :linux -> get_linux_version()
      :windows -> get_windows_version()
      _ -> "unknown"
    end
  end
  
  defp get_architecture do
    :erlang.system_info(:system_architecture)
    |> List.to_string()
    |> String.split("-")
    |> List.first()
  end
  
  defp get_terminal_info do
    System.get_env("TERM") || "unknown"
  end
  
  # Platform-specific information gathering
  
  defp get_macos_info do
    %{
      is_apple_silicon: is_apple_silicon?(),
      terminal_app: detect_macos_terminal()
    }
  end
  
  defp get_linux_info do
    %{
      distribution: detect_linux_distribution(),
      is_wsl: is_wsl?(),
      is_wayland: is_wayland?()
    }
  end
  
  defp get_windows_info do
    %{
      is_windows_terminal: is_windows_terminal?(),
      console_type: detect_windows_console_type()
    }
  end
  
  # Platform version detection
  
  defp get_macos_version do
    case System.cmd("sw_vers", ["-productVersion"], stderr_to_stdout: true) do
      {version, 0} -> String.trim(version)
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
  
  defp get_linux_version do
    case File.read("/etc/os-release") do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find_value("unknown", fn line ->
          with [key, value] <- String.split(line, "=", parts: 2),
               true <- String.trim(key) == "VERSION_ID" do
            String.trim(value, "\"")
          else
            _ -> false
          end
        end)
      _ -> "unknown"
    end
  end
  
  defp get_windows_version do
    case System.cmd("cmd", ["/c", "ver"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("[")
        |> List.last()
        |> String.trim_trailing("]")
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
  
  # Platform-specific detection helpers
  
  defp is_apple_silicon? do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("uname", ["-m"], stderr_to_stdout: true) do
          {"arm64\n", 0} -> true
          _ -> false
        end
      _ -> false
    end
  rescue
    _ -> false
  end
  
  defp detect_macos_terminal do
    # Try to determine the specific terminal app being used
    cond do
      System.get_env("TERM_PROGRAM") == "iTerm.app" -> "iTerm2"
      System.get_env("TERM_PROGRAM") == "Apple_Terminal" -> "Terminal.app"
      System.get_env("TERM_PROGRAM") == "vscode" -> "VS Code"
      System.get_env("KITTY_WINDOW_ID") != nil -> "Kitty"
      System.get_env("ALACRITTY_LOG") != nil -> "Alacritty"
      true -> "unknown"
    end
  end
  
  defp detect_linux_distribution do
    cond do
      File.exists?("/etc/debian_version") -> "Debian/Ubuntu"
      File.exists?("/etc/redhat-release") -> "RHEL/Fedora/CentOS"
      File.exists?("/etc/arch-release") -> "Arch"
      File.exists?("/etc/SuSE-release") -> "SuSE"
      File.exists?("/etc/alpine-release") -> "Alpine"
      true -> "unknown"
    end
  end
  
  defp is_wsl? do
    File.exists?("/proc/sys/kernel/osrelease") &&
      case File.read("/proc/sys/kernel/osrelease") do
        {:ok, content} -> String.contains?(content, "Microsoft") || String.contains?(content, "WSL")
        _ -> false
      end
  end
  
  defp is_wayland? do
    System.get_env("WAYLAND_DISPLAY") != nil
  end
  
  defp is_windows_terminal? do
    System.get_env("WT_SESSION") != nil
  end
  
  defp detect_windows_console_type do
    cond do
      System.get_env("WT_SESSION") != nil -> "Windows Terminal"
      System.get_env("TERM_PROGRAM") == "vscode" -> "VS Code"
      System.get_env("CMDER_ROOT") != nil -> "Cmder"
      System.get_env("PROMPT") != nil && String.contains?(System.get_env("PROMPT") || "", "$P$G") -> "Command Prompt"
      System.get_env("PSModulePath") != nil -> "PowerShell"
      true -> "unknown"
    end
  end
  
  defp detect_linux_clipboard_support do
    case System.cmd("which", ["xclip"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ ->
        case System.cmd("which", ["wl-copy"], stderr_to_stdout: true) do
          {_, 0} -> true
          _ -> false
        end
    end
  rescue
    _ -> false
  end
  
  defp detect_windows_true_color do
    windows_terminal? = is_windows_terminal?()
    
    # Windows Terminal supports true color
    # For other terminals, check COLORTERM
    windows_terminal? || System.get_env("COLORTERM") == "truecolor"
  end
  
  defp detect_windows_unicode do
    # Windows Terminal and WSL have better unicode support than native cmd/powershell
    is_windows_terminal?() || is_wsl?() || System.get_env("TERM") == "xterm-256color"
  end
end 