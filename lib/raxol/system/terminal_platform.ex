defmodule Raxol.System.TerminalPlatform do
  @moduledoc """
  Terminal-specific platform features and compatibility checks.

  This module provides detailed information about terminal capabilities,
  feature support, and compatibility across different platforms and terminal emulators.
  """

  @type terminal_feature ::
          :true_color
          | :unicode
          | :mouse
          | :clipboard
          | :bracketed_paste
          | :focus
          | :title

  @doc """
  Returns detailed information about the current terminal's capabilities.

  ## Returns

  A map containing terminal capabilities including:

  * `:name` - Terminal name/type
  * `:version` - Terminal version if available
  * `:features` - List of supported features
  * `:colors` - Color support information
  * `:unicode` - Unicode support details
  * `:input` - Input capabilities
  * `:output` - Output capabilities

  ## Examples

      iex> TerminalPlatform.get_terminal_capabilities()
      %{
        name: "iTerm2",
        version: "3.5.0",
        features: [:true_color, :unicode, :mouse, :clipboard],
        colors: %{
          basic: true,
          true_color: true,
          palette: "default"
        },
        unicode: %{
          support: true,
          width: :ambiguous,
          emoji: true
        },
        input: %{
          mouse: true,
          bracketed_paste: true,
          focus: true
        },
        output: %{
          title: true,
          bell: true,
          alternate_screen: true
        }
      }
  """
  @spec get_terminal_capabilities() :: map()
  def get_terminal_capabilities do
    %{
      name: get_terminal_name(),
      version: get_terminal_version(),
      features: get_supported_features(),
      colors: get_color_capabilities(),
      unicode: get_unicode_capabilities(),
      input: get_input_capabilities(),
      output: get_output_capabilities()
    }
  end

  @doc """
  Checks if a specific terminal feature is supported.

  ## Parameters

  * `feature` - Feature to check for support

  ## Returns

  * `true` - Feature is supported
  * `false` - Feature is not supported

  ## Examples

      iex> TerminalPlatform.supports_feature?(:true_color)
      true
  """
  @spec supports_feature?(terminal_feature()) :: boolean()
  def supports_feature?(feature) do
    feature in get_supported_features()
  end

  @doc """
  Returns the list of all supported terminal features.

  ## Returns

  List of supported feature atoms.

  ## Examples

      iex> TerminalPlatform.get_supported_features()
      [:true_color, :unicode, :mouse, :clipboard]
  """
  @spec get_supported_features() :: list(terminal_feature())
  def get_supported_features do
    [
      detect_color_features(),
      detect_mouse_feature(),
      detect_title_feature(),
      detect_unicode_feature(),
      detect_clipboard_feature(),
      detect_bracketed_paste_feature(),
      detect_focus_feature()
    ]
    |> List.flatten()
  end

  defp detect_color_features do
    term = System.get_env("TERM") || ""
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""

    features = []
    features = if String.contains?(term, "256") || term_program in ["iTerm.app", "vscode"], do: [:colors_256 | features], else: features
    features = if term_program in ["iTerm.app", "vscode"] || term_emulator == "JetBrains-JediTerm", do: [:true_color | features], else: features
    features
  end

  defp detect_mouse_feature do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""
    if term_program in ["iTerm.app", "vscode"] || term_emulator == "JetBrains-JediTerm", do: [:mouse], else: []
  end

  defp detect_title_feature do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""
    if term_program in ["iTerm.app", "vscode", "Apple_Terminal"] || term_emulator == "JetBrains-JediTerm", do: [:title], else: []
  end

  defp detect_unicode_feature do
    if supports_unicode?(), do: [:unicode], else: []
  end

  defp detect_clipboard_feature do
    if supports_clipboard?(), do: [:clipboard], else: []
  end

  defp detect_bracketed_paste_feature do
    if supports_bracketed_paste?(), do: [:bracketed_paste], else: []
  end

  defp detect_focus_feature do
    if supports_focus?(), do: [:focus], else: []
  end

  # Private helper functions

  defp get_terminal_name do
    cond do
      System.get_env("TERM_PROGRAM") == "iTerm.app" -> "iTerm2"
      System.get_env("TERM_PROGRAM") == "Apple_Terminal" -> "Terminal.app"
      System.get_env("WT_SESSION") != nil -> "Windows Terminal"
      System.get_env("TERM") == "xterm-256color" -> "xterm"
      System.get_env("TERM") == "screen-256color" -> "screen"
      true -> System.get_env("TERM") || "unknown"
    end
  end

  defp get_terminal_version do
    case get_terminal_name() do
      "iTerm2" -> get_iterm_version()
      "Windows Terminal" -> get_windows_terminal_version()
      _ -> "unknown"
    end
  end

  defp get_color_capabilities do
    %{
      basic: true,
      true_color: supports_true_color?(),
      palette: if(supports_256_colors?(), do: "xterm-256color", else: "default")
    }
  end

  defp get_unicode_capabilities do
    %{
      support: supports_unicode?(),
      width: :ambiguous,
      emoji: supports_emoji?()
    }
  end

  defp get_input_capabilities do
    %{
      mouse: supports_mouse?(),
      bracketed_paste: supports_bracketed_paste?(),
      focus: supports_focus?()
    }
  end

  defp get_output_capabilities do
    %{
      title: supports_title?(),
      bell: true,
      alternate_screen: true
    }
  end

  defp get_iterm_version do
    case System.cmd("osascript", ["-e", "tell application \"iTerm\" to version"]) do
      {version, 0} -> String.trim(version)
      _ -> "unknown"
    end
  end

  defp get_windows_terminal_version do
    case System.cmd("wt", ["--version"]) do
      {version, 0} -> String.trim(version)
      _ -> "unknown"
    end
  end

  defp supports_true_color? do
    cond do
      System.get_env("COLORTERM") in ["truecolor", "24bit"] -> true
      System.get_env("TERM") in ["xterm-24bit", "iterm", "iTerm.app"] -> true
      System.get_env("TERM_PROGRAM") == "iTerm.app" -> true
      System.get_env("TERM_EMULATOR") == "JetBrains-JediTerm" -> true
      true -> false
    end
  end

  defp supports_unicode? do
    case System.get_env("LANG") do
      nil -> false
      lang -> String.contains?(lang, "UTF-8")
    end
  end

  defp supports_emoji? do
    supports_unicode?()
  end

  defp supports_mouse? do
    term = System.get_env("TERM") || ""
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""

    String.contains?(term, "xterm") ||
      term_program in ["iTerm.app", "vscode", "Apple_Terminal"] ||
      term_emulator == "JetBrains-JediTerm"
  end

  defp supports_bracketed_paste? do
    supports_mouse?()
  end

  defp supports_focus? do
    term = System.get_env("TERM") || ""
    term_program = System.get_env("TERM_PROGRAM") || ""

    String.contains?(term, "xterm") || term_program == "iTerm.app"
  end

  defp supports_title? do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""

    term_program in ["iTerm.app", "vscode", "Apple_Terminal"] ||
      term_emulator == "JetBrains-JediTerm"
  end

  defp supports_256_colors? do
    term = System.get_env("TERM") || ""
    term_program = System.get_env("TERM_PROGRAM") || ""

    String.contains?(term, "256") || term_program in ["iTerm.app", "vscode"]
  end

  defp supports_clipboard? do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_program in ["iTerm.app", "vscode"]
  end
end
