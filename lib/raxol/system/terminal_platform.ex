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
  @spec get_terminal_capabilities() :: %{
          :name => String.t(),
          :version => String.t(),
          :features => list(),
          :colors => map(),
          :unicode => map(),
          :input => map(),
          :output => map()
        }
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

    features =
      add_256_color_feature(
        String.contains?(term, "256") ||
          term_program in ["iTerm.app", "vscode"],
        features
      )

    features =
      add_true_color_feature(
        term_program in ["iTerm.app", "vscode"] ||
          term_emulator == "JetBrains-JediTerm",
        features
      )

    features
  end

  defp detect_mouse_feature do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""

    has_mouse =
      term_program in ["iTerm.app", "vscode"] ||
        term_emulator == "JetBrains-JediTerm"

    feature_list(has_mouse, :mouse)
  end

  defp detect_title_feature do
    term_program = System.get_env("TERM_PROGRAM") || ""
    term_emulator = System.get_env("TERM_EMULATOR") || ""

    has_title =
      term_program in ["iTerm.app", "vscode", "Apple_Terminal"] ||
        term_emulator == "JetBrains-JediTerm"

    feature_list(has_title, :title)
  end

  defp detect_unicode_feature do
    feature_list(supports_unicode?(), :unicode)
  end

  defp detect_clipboard_feature do
    feature_list(supports_clipboard?(), :clipboard)
  end

  defp detect_bracketed_paste_feature do
    feature_list(supports_bracketed_paste?(), :bracketed_paste)
  end

  defp detect_focus_feature do
    feature_list(supports_focus?(), :focus)
  end

  # Private helper functions

  defp get_terminal_name do
    detect_terminal_by_env()
  end

  defp detect_terminal_by_env do
    case System.get_env("TERM_PROGRAM") do
      "iTerm.app" -> "iTerm2"
      "Apple_Terminal" -> "Terminal.app"
      _ -> detect_by_other_env_vars()
    end
  end

  defp detect_by_other_env_vars do
    detect_terminal_type(System.get_env("WT_SESSION") != nil)
  end

  defp detect_terminal_type(true), do: "Windows Terminal"

  defp detect_terminal_type(false) do
    case System.get_env("TERM") do
      "xterm-256color" -> "xterm"
      "screen-256color" -> "screen"
      term -> term || "unknown"
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
      true_color: :true_color in get_supported_features(),
      palette: get_color_palette(supports_256_colors?())
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
      mouse: :mouse in get_supported_features(),
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

  # Helper functions for refactored if statements
  defp add_256_color_feature(true, features), do: [:colors_256 | features]
  defp add_256_color_feature(false, features), do: features

  defp add_true_color_feature(true, features), do: [:true_color | features]
  defp add_true_color_feature(false, features), do: features

  defp feature_list(true, feature), do: [feature]
  defp feature_list(false, _feature), do: []

  defp get_color_palette(true), do: "xterm-256color"
  defp get_color_palette(false), do: "default"
end
