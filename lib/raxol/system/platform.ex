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

  ## Examples

      iex> Platform.get_current_platform()
      :macos
  """
  def get_current_platform do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, _} -> :linux
      {:win32, _} -> :windows
    end
  end

  @doc """
  Returns the platform name as a string.

  ## Returns

  * `"macos"` - macOS (Darwin)
  * `"linux"` - Linux variants
  * `"windows"` - Windows

  ## Examples

      iex> Platform.get_platform_name()
      "macos"
  """
  def get_platform_name do
    case get_current_platform() do
      :macos -> "macos"
      :linux -> "linux"
      :windows -> "windows"
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
    end
  end

  @doc """
  Detects if the feature is supported on the current platform.

  ## Parameters

  * `feature` - Feature name as an atom (e.g., `:true_color`, `:unicode`, `:mouse`, `:kitty_graphics`)

  ## Returns

  * `true` - Feature is supported on the current platform
  * `false` - Feature is not supported or support is uncertain

  ## Examples

      iex> Platform.supports_feature?(:true_color)
      true

      iex> Platform.supports_feature?(:kitty_graphics)
      false
  """
  def supports_feature?(feature) do
    case feature do
      # Features fully supported across all platforms
      :keyboard ->
        true

      :basic_colors ->
        true

      # Graphics protocol features
      feature
      when feature in [:kitty_graphics, :sixel_graphics, :iterm2_graphics] ->
        detect_graphics_protocol_support(feature)

      # Platform-specific features
      feature when feature in [:true_color, :unicode, :mouse, :clipboard] ->
        platform_supports_feature?(get_current_platform(), feature)

      _ ->
        false
    end
  end

  defp platform_supports_feature?(platform, feature) do
    case platform do
      :macos -> macos_supports_feature?(feature)
      :linux -> linux_supports_feature?(feature)
      :windows -> windows_supports_feature?(feature)
    end
  end

  defp macos_supports_feature?(feature) do
    feature in [:true_color, :unicode, :mouse, :clipboard]
  end

  defp linux_supports_feature?(feature) do
    case feature do
      :clipboard -> detect_linux_clipboard_support()
      _ -> feature in [:true_color, :unicode, :mouse]
    end
  end

  defp windows_supports_feature?(feature) do
    case feature do
      :true_color -> detect_windows_true_color()
      :unicode -> detect_windows_unicode()
      _ -> feature in [:mouse, :clipboard]
    end
  end

  # Private helper functions

  defp get_os_version do
    case get_current_platform() do
      :macos -> get_macos_version()
      :linux -> get_linux_version()
      :windows -> get_windows_version()
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
      apple_silicon: apple_silicon?(),
      terminal_app: detect_macos_terminal()
    }
  end

  defp get_linux_info do
    %{
      distribution: detect_linux_distribution(),
      wsl: wsl?(),
      wayland: wayland?()
    }
  end

  defp get_windows_info do
    %{
      windows_terminal: windows_terminal?(),
      console_type: detect_windows_console_type()
    }
  end

  # Platform version detection

  defp get_macos_version do
    case Raxol.Core.ErrorHandling.safe_call(&run_sw_vers/0) do
      {:ok, result} -> result
      {:error, _} -> "unknown"
    end
  end

  defp run_sw_vers do
    case System.cmd("sw_vers", ["-productVersion"], stderr_to_stdout: true) do
      {version, 0} -> String.trim(version)
      _ -> "unknown"
    end
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

      _ ->
        "unknown"
    end
  end

  defp get_windows_version do
    case Raxol.Core.ErrorHandling.safe_call(&run_windows_ver/0) do
      {:ok, result} -> result
      {:error, _} -> "unknown"
    end
  end

  defp run_windows_ver do
    case System.cmd("cmd", ["/c", "ver"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("[")
        |> List.last()
        |> String.trim_trailing("]")

      _ ->
        "unknown"
    end
  end

  @doc """
  Detects which graphics protocols are supported by the current terminal.

  ## Returns

  A map with graphics protocol support information:

  * `:kitty_graphics` - boolean indicating Kitty graphics protocol support
  * `:sixel_graphics` - boolean indicating Sixel graphics support
  * `:iterm2_graphics` - boolean indicating iTerm2 inline images support
  * `:terminal_type` - detected terminal type atom
  * `:capabilities` - map of additional detected capabilities

  ## Examples

      iex> Platform.detect_graphics_support()
      %{
        kitty_graphics: true,
        sixel_graphics: false,
        iterm2_graphics: false,
        terminal_type: :kitty,
        capabilities: %{max_image_size: 100_000_000}
      }
  """
  def detect_graphics_support do
    terminal_type = detect_terminal_type()

    %{
      kitty_graphics: detect_graphics_protocol_support(:kitty_graphics),
      sixel_graphics: detect_graphics_protocol_support(:sixel_graphics),
      iterm2_graphics: detect_graphics_protocol_support(:iterm2_graphics),
      terminal_type: terminal_type,
      capabilities: detect_terminal_capabilities(terminal_type)
    }
  end

  # Graphics protocol detection
  defp detect_graphics_protocol_support(:kitty_graphics) do
    case detect_terminal_type() do
      :kitty -> true
      :wezterm -> check_wezterm_kitty_support()
      :iterm2 -> check_iterm2_kitty_support()
      :alacritty -> check_alacritty_kitty_support()
      _ -> false
    end
  end

  defp detect_graphics_protocol_support(:sixel_graphics) do
    case detect_terminal_type() do
      :xterm -> check_xterm_sixel_support()
      :mintty -> true
      :mlterm -> true
      :wezterm -> true
      :foot -> true
      _ -> check_environment_sixel_support()
    end
  end

  defp detect_graphics_protocol_support(:iterm2_graphics) do
    case detect_terminal_type() do
      :iterm2 -> true
      _ -> false
    end
  end

  defp detect_terminal_type do
    case {
      System.get_env("TERM"),
      System.get_env("TERM_PROGRAM"),
      System.get_env("KITTY_WINDOW_ID"),
      System.get_env("WEZTERM_EXECUTABLE"),
      System.get_env("ALACRITTY_LOG")
    } do
      {"xterm-kitty", _, _, _, _} ->
        :kitty

      {_, _, kitty_id, _, _} when not is_nil(kitty_id) ->
        :kitty

      {_, _, _, wezterm, _} when not is_nil(wezterm) ->
        :wezterm

      {"wezterm", _, _, _, _} ->
        :wezterm

      {_, "iTerm.app", _, _, _} ->
        :iterm2

      {_, _, _, _, alacritty} when not is_nil(alacritty) ->
        :alacritty

      {"alacritty", _, _, _, _} ->
        :alacritty

      {term, _, _, _, _} when not is_nil(term) ->
        detect_terminal_from_term(term)

      _ ->
        :unknown
    end
  end

  defp detect_terminal_from_term(term) do
    cond do
      String.contains?(term, "xterm") -> :xterm
      String.contains?(term, "screen") -> :screen
      String.contains?(term, "tmux") -> :tmux
      String.contains?(term, "foot") -> :foot
      String.contains?(term, "mlterm") -> :mlterm
      term == "mintty" -> :mintty
      String.starts_with?(term, "st-") -> :st
      true -> :unknown
    end
  end

  defp detect_terminal_capabilities(:kitty) do
    %{
      # 100MB
      max_image_size: 100_000_000,
      supports_animation: true,
      supports_transparency: true,
      supports_chunked_transmission: true,
      max_image_width: 10_000,
      max_image_height: 10_000
    }
  end

  defp detect_terminal_capabilities(:wezterm) do
    %{
      # 50MB
      max_image_size: 50_000_000,
      supports_animation: true,
      supports_transparency: true,
      supports_chunked_transmission: true,
      max_image_width: 8192,
      max_image_height: 8192
    }
  end

  defp detect_terminal_capabilities(:iterm2) do
    %{
      # 10MB
      max_image_size: 10_000_000,
      supports_animation: false,
      supports_transparency: true,
      supports_chunked_transmission: false,
      max_image_width: 2048,
      max_image_height: 2048
    }
  end

  defp detect_terminal_capabilities(:xterm) do
    %{
      # 1MB (Sixel)
      max_image_size: 1_000_000,
      supports_animation: false,
      supports_transparency: false,
      supports_chunked_transmission: false,
      max_image_width: 1024,
      max_image_height: 1024
    }
  end

  defp detect_terminal_capabilities(_) do
    %{
      max_image_size: 0,
      supports_animation: false,
      supports_transparency: false,
      supports_chunked_transmission: false,
      max_image_width: 0,
      max_image_height: 0
    }
  end

  # Terminal-specific graphics support detection
  defp check_wezterm_kitty_support do
    # WezTerm supports Kitty graphics protocol since v20220408
    case System.get_env("WEZTERM_VERSION") do
      # Assume recent version
      nil -> true
      version -> version >= "20220408"
    end
  end

  defp check_iterm2_kitty_support do
    # iTerm2 has limited Kitty graphics protocol support since 3.5
    case System.get_env("TERM_PROGRAM_VERSION") do
      nil ->
        false

      version ->
        check_version_major_gte(version, 3)
    end
  end

  defp check_version_major_gte(version, min_major) do
    case String.split(version, ".") do
      [major | _] when is_binary(major) ->
        case Integer.parse(major) do
          {maj_num, _} -> maj_num >= min_major
          _ -> false
        end

      _ ->
        false
    end
  end

  defp check_alacritty_kitty_support do
    # Alacritty currently does not support Kitty graphics protocol
    false
  end

  defp check_xterm_sixel_support do
    # Check if xterm was compiled with Sixel support
    case System.get_env("XTERM_VERSION") do
      nil ->
        # Unknown version - check environment for Sixel indicators
        check_environment_sixel_support()

      version ->
        # Sixel support added in xterm 334+
        case Integer.parse(version) do
          {num, _} when num >= 334 ->
            true

          {_num, _} ->
            # Version < 334, but still check environment variables
            check_environment_sixel_support()

          _ ->
            # Unparseable version, check environment
            check_environment_sixel_support()
        end
    end
  end

  defp check_environment_sixel_support do
    # Check TERM environment for Sixel indicators
    term = System.get_env("TERM", "")

    String.contains?(term, "sixel") or
      System.get_env("COLORTERM") == "sixel"
  end

  # Platform-specific detection helpers

  defp apple_silicon? do
    case Raxol.Core.ErrorHandling.safe_call(&check_apple_silicon_arch/0) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  defp check_apple_silicon_arch do
    case :os.type() do
      {:unix, :darwin} ->
        check_arm64_architecture()

      _ ->
        false
    end
  end

  defp check_arm64_architecture do
    case System.cmd("uname", ["-m"], stderr_to_stdout: true) do
      {"arm64\n", 0} -> true
      _ -> false
    end
  end

  defp detect_macos_terminal do
    # Try to determine the specific terminal app being used
    case {System.get_env("TERM_PROGRAM"), System.get_env("KITTY_WINDOW_ID"),
          System.get_env("ALACRITTY_LOG")} do
      {"iTerm.app", _, _} -> "iTerm2"
      {"Apple_Terminal", _, _} -> "Terminal.app"
      {"vscode", _, _} -> "VS Code"
      {_, kitty_id, _} when kitty_id != nil -> "Kitty"
      {_, _, alacritty_log} when alacritty_log != nil -> "Alacritty"
      _ -> "unknown"
    end
  end

  defp detect_linux_distribution do
    case {File.exists?("/etc/debian_version"),
          File.exists?("/etc/redhat-release"),
          File.exists?("/etc/arch-release"), File.exists?("/etc/SuSE-release"),
          File.exists?("/etc/alpine-release")} do
      {true, _, _, _, _} -> "Debian/Ubuntu"
      {_, true, _, _, _} -> "RHEL/Fedora/CentOS"
      {_, _, true, _, _} -> "Arch"
      {_, _, _, true, _} -> "SuSE"
      {_, _, _, _, true} -> "Alpine"
      _ -> "unknown"
    end
  end

  defp wsl? do
    File.exists?("/proc/sys/kernel/osrelease") &&
      case File.read("/proc/sys/kernel/osrelease") do
        {:ok, content} ->
          String.contains?(content, "Microsoft") ||
            String.contains?(content, "WSL")

        _ ->
          false
      end
  end

  defp wayland? do
    System.get_env("WAYLAND_DISPLAY") != nil
  end

  defp windows_terminal? do
    System.get_env("WT_SESSION") != nil
  end

  defp detect_windows_console_type do
    case {System.get_env("WT_SESSION"), System.get_env("TERM_PROGRAM"),
          System.get_env("CMDER_ROOT"), System.get_env("PROMPT"),
          System.get_env("PSModulePath")} do
      {wt, _, _, _, _} when wt != nil ->
        "Windows Terminal"

      {_, "vscode", _, _, _} ->
        "VS Code"

      {_, _, cmder, _, _} when cmder != nil ->
        "Cmder"

      {_, _, _, prompt, _} when prompt != nil ->
        case String.contains?(prompt, "$P$G") do
          true -> "Command Prompt"
          false -> determine_by_psmodule(System.get_env("PSModulePath"))
        end

      {_, _, _, _, psmodule} when psmodule != nil ->
        "PowerShell"

      _ ->
        "unknown"
    end
  end

  defp determine_by_psmodule(nil), do: "unknown"
  defp determine_by_psmodule(_psmodule), do: "PowerShell"

  defp detect_linux_clipboard_support do
    case Raxol.Core.ErrorHandling.safe_call(&check_linux_clipboard_tools/0) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  defp check_linux_clipboard_tools do
    case System.cmd("which", ["xclip"], stderr_to_stdout: true) do
      {_, 0} ->
        true

      _ ->
        check_wayland_clipboard_tool()
    end
  end

  defp check_wayland_clipboard_tool do
    case System.cmd("which", ["wl-copy"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp detect_windows_true_color do
    windows_terminal? = windows_terminal?()

    # Windows Terminal supports true color
    # For other terminals, check COLORTERM
    windows_terminal? || System.get_env("COLORTERM") == "truecolor"
  end

  defp detect_windows_unicode do
    # Windows 10+ has native VT100/Unicode support
    # Windows Terminal and WSL have even better unicode support
    windows_terminal?() || wsl?() ||
      System.get_env("TERM") == "xterm-256color" ||
      windows_10_or_later?()
  end

  defp windows_10_or_later? do
    case get_windows_version() do
      "unknown" ->
        # Assume Windows 10+ if version detection fails
        true

      version ->
        # Parse version string like "10.0.19045.2006"
        check_windows_version_major(version, 10)
    end
  end

  defp check_windows_version_major(version, min_major) do
    case String.split(version, ".") do
      [major | _] when is_binary(major) ->
        case Integer.parse(major) do
          {maj_num, _} -> maj_num >= min_major
          _ -> true
        end

      _ ->
        true
    end
  end
end
