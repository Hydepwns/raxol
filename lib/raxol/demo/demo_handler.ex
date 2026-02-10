defmodule Raxol.Demo.DemoHandler do
  @moduledoc """
  Generates demo content for the terminal showcase.
  Produces ANSI-formatted output demonstrating Raxol's capabilities.
  """

  alias Raxol.Demo.CommandWhitelist

  # ANSI escape code prefix
  @esc "\e["
  @reset "\e[0m"

  @doc """
  Returns help text with available commands.
  """
  @spec help() :: {:ok, String.t()}
  def help do
    header =
      "#{@esc}1;36m" <>
        "╔══════════════════════════════════════════════════════════════╗\r\n" <>
        "║                    Raxol Terminal Demo                       ║\r\n" <>
        "╚══════════════════════════════════════════════════════════════╝#{@reset}\r\n\r\n" <>
        "#{@esc}1mAvailable Commands:#{@reset}\r\n"

    commands =
      CommandWhitelist.available_commands()
      |> Enum.map(fn {cmd, desc} ->
        "  #{@esc}33m#{String.pad_trailing(cmd, 18)}#{@reset} #{desc}"
      end)
      |> Enum.join("\r\n")

    footer = "\r\n\r\n#{@esc}2mType a command and press Enter#{@reset}"

    {:ok, header <> commands <> footer <> "\r\n"}
  end

  @doc """
  Displays ANSI color palette (16, 256, and truecolor).
  """
  @spec demo_colors() :: {:ok, String.t()}
  def demo_colors do
    output =
      "#{@esc}1;35m━━━ ANSI Color Palette ━━━#{@reset}\r\n\r\n" <>
        "#{@esc}1m16 Standard Colors:#{@reset}\r\n" <>
        standard_colors() <>
        "\r\n\r\n#{@esc}1m256 Color Palette (sample):#{@reset}\r\n" <>
        color_256_sample() <>
        "\r\n\r\n#{@esc}1mTruecolor Gradient:#{@reset}\r\n" <>
        truecolor_gradient() <>
        "\r\n\r\n#{@esc}1mText Styles:#{@reset}\r\n" <>
        text_styles() <>
        "\r\n"

    {:ok, output}
  end

  @doc """
  Displays UI component gallery.
  """
  @spec demo_components() :: {:ok, String.t()}
  def demo_components do
    output =
      "#{@esc}1;35m━━━ UI Component Gallery ━━━#{@reset}\r\n\r\n" <>
        "#{@esc}1mButtons:#{@reset}\r\n" <>
        render_buttons() <>
        "\r\n\r\n#{@esc}1mProgress Bars:#{@reset}\r\n" <>
        render_progress_bars() <>
        "\r\n\r\n#{@esc}1mTable:#{@reset}\r\n" <>
        render_table() <>
        "\r\n\r\n#{@esc}1mBox Drawing:#{@reset}\r\n" <>
        render_box() <>
        "\r\n"

    {:ok, output}
  end

  @doc """
  Displays animation capabilities (static representation).
  """
  @spec demo_animation() :: {:ok, String.t()}
  def demo_animation do
    output =
      "#{@esc}1;35m━━━ Animation Capabilities ━━━#{@reset}\r\n\r\n" <>
        "#{@esc}1mSpinner Styles:#{@reset}\r\n" <>
        render_spinners() <>
        "\r\n\r\n#{@esc}1mProgress Animation:#{@reset}\r\n" <>
        render_animated_progress() <>
        "\r\n\r\n#{@esc}1mTyping Effect:#{@reset}\r\n" <>
        render_typing_effect() <>
        "\r\n\r\n#{@esc}2mNote: Full animations run in Raxol applications#{@reset}\r\n"

    {:ok, output}
  end

  @doc """
  Displays VT100/ANSI escape sequence demo.
  """
  @spec demo_emulation() :: {:ok, String.t()}
  def demo_emulation do
    output =
      "#{@esc}1;35m━━━ Terminal Emulation ━━━#{@reset}\r\n\r\n" <>
        "#{@esc}1mCursor Movement:#{@reset}\r\n" <>
        "#{@esc}2m\\e[nA#{@reset} Move up n    #{@esc}2m\\e[nB#{@reset} Move down n\r\n" <>
        "#{@esc}2m\\e[nC#{@reset} Move right n #{@esc}2m\\e[nD#{@reset} Move left n\r\n\r\n" <>
        "#{@esc}1mScreen Control:#{@reset}\r\n" <>
        "#{@esc}2m\\e[2J#{@reset} Clear screen  #{@esc}2m\\e[K#{@reset} Clear to EOL\r\n" <>
        "#{@esc}2m\\e[s#{@reset}  Save cursor   #{@esc}2m\\e[u#{@reset} Restore cursor\r\n\r\n" <>
        "#{@esc}1mText Attributes:#{@reset}\r\n" <>
        "#{@esc}1mBold#{@reset}  #{@esc}3mItalic#{@reset}  #{@esc}4mUnderline#{@reset}  #{@esc}9mStrike#{@reset}  #{@esc}7mReverse#{@reset}\r\n\r\n" <>
        "#{@esc}1mSupported Standards:#{@reset}\r\n" <>
        "  * VT100, VT220, VT320 escape sequences\r\n" <>
        "  * ANSI X3.64 control codes\r\n" <>
        "  * xterm 256-color and truecolor extensions\r\n" <>
        "  * Unicode and UTF-8 text rendering\r\n"

    {:ok, output}
  end

  @doc """
  Sets terminal theme (returns theme-specific escape codes).
  """
  @spec set_theme(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def set_theme(name) do
    case String.downcase(name) do
      "dracula" ->
        {:ok,
         "\e[48;2;40;42;54m\e[38;2;248;248;242m\e[2J\e[HTheme set to Dracula\r\n\e[0m"}

      "nord" ->
        {:ok,
         "\e[48;2;46;52;64m\e[38;2;216;222;233m\e[2J\e[HTheme set to Nord\r\n\e[0m"}

      "monokai" ->
        {:ok,
         "\e[48;2;39;40;34m\e[38;2;248;248;242m\e[2J\e[HTheme set to Monokai\r\n\e[0m"}

      "solarized" ->
        {:ok,
         "\e[48;2;0;43;54m\e[38;2;131;148;150m\e[2J\e[HTheme set to Solarized\r\n\e[0m"}

      _ ->
        {:error,
         "Unknown theme: #{name}. Available: dracula, nord, monokai, solarized"}
    end
  end

  @doc """
  Returns welcome message for new sessions.
  """
  @spec welcome_message() :: String.t()
  def welcome_message do
    "\e[2J\e[H#{@esc}1;36m" <>
      " ██████╗  █████╗ ██╗  ██╗ ██████╗ ██╗\r\n" <>
      " ██╔══██╗██╔══██╗╚██╗██╔╝██╔═══██╗██║\r\n" <>
      " ██████╔╝███████║ ╚███╔╝ ██║   ██║██║\r\n" <>
      " ██╔══██╗██╔══██║ ██╔██╗ ██║   ██║██║\r\n" <>
      " ██║  ██║██║  ██║██╔╝ ██╗╚██████╔╝███████╗\r\n" <>
      " ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝\r\n" <>
      "#{@reset}\r\n" <>
      "#{@esc}1mTerminal Application Framework for Elixir#{@reset}\r\n" <>
      "#{@esc}2mhttps://raxol.io#{@reset}\r\n\r\n" <>
      "Type #{@esc}33mhelp#{@reset} for available commands.\r\n\r\n"
  end

  # Private helper functions

  defp standard_colors do
    normal =
      0..7
      |> Enum.map(fn n -> "#{@esc}48;5;#{n}m   #{@reset}" end)
      |> Enum.join("")

    bright =
      8..15
      |> Enum.map(fn n -> "#{@esc}48;5;#{n}m   #{@reset}" end)
      |> Enum.join("")

    "    #{normal}\r\n    #{bright}"
  end

  defp color_256_sample do
    rows =
      for row <- 0..5 do
        cols =
          for col <- 0..35 do
            n = 16 + row * 36 + col
            "#{@esc}48;5;#{n}m #{@reset}"
          end
          |> Enum.join("")

        "    #{cols}"
      end

    Enum.join(rows, "\r\n")
  end

  defp truecolor_gradient do
    gradient =
      0..59
      |> Enum.map(fn i ->
        r = round(255 * i / 59)
        g = round(255 * (59 - i) / 59)
        b = 128
        "#{@esc}48;2;#{r};#{g};#{b}m #{@reset}"
      end)
      |> Enum.join("")

    "    #{gradient}"
  end

  defp text_styles do
    "    #{@esc}1mBold#{@reset} #{@esc}2mDim#{@reset} #{@esc}3mItalic#{@reset} " <>
      "#{@esc}4mUnderline#{@reset} #{@esc}5mBlink#{@reset} #{@esc}7mReverse#{@reset} #{@esc}9mStrike#{@reset}\r\n" <>
      "    #{@esc}31mRed#{@reset} #{@esc}32mGreen#{@reset} #{@esc}33mYellow#{@reset} " <>
      "#{@esc}34mBlue#{@reset} #{@esc}35mMagenta#{@reset} #{@esc}36mCyan#{@reset}"
  end

  defp render_buttons do
    "    #{@esc}44;97m [ Submit ] #{@reset}  #{@esc}42;97m [ OK ] #{@reset}  " <>
      "#{@esc}41;97m [ Cancel ] #{@reset}  #{@esc}100;97m [ Disabled ] #{@reset}"
  end

  defp render_progress_bars do
    "    #{@esc}32m████████████████████#{@esc}90m░░░░░░░░░░#{@reset} 67%\r\n" <>
      "    #{@esc}34m██████████████████████████████#{@reset} 100%\r\n" <>
      "    #{@esc}33m█████#{@esc}90m░░░░░░░░░░░░░░░░░░░░░░░░░#{@reset} 17%"
  end

  defp render_table do
    "    #{@esc}90m┌──────────┬──────────┬──────────┐#{@reset}\r\n" <>
      "    #{@esc}90m│#{@reset} #{@esc}1mName#{@reset}     #{@esc}90m│#{@reset} #{@esc}1mStatus#{@reset}   #{@esc}90m│#{@reset} #{@esc}1mVersion#{@reset}  #{@esc}90m│#{@reset}\r\n" <>
      "    #{@esc}90m├──────────┼──────────┼──────────┤#{@reset}\r\n" <>
      "    #{@esc}90m│#{@reset} Phoenix  #{@esc}90m│#{@reset} #{@esc}32m● Active#{@reset} #{@esc}90m│#{@reset} 1.7.14   #{@esc}90m│#{@reset}\r\n" <>
      "    #{@esc}90m│#{@reset} LiveView #{@esc}90m│#{@reset} #{@esc}32m● Active#{@reset} #{@esc}90m│#{@reset} 0.20.17  #{@esc}90m│#{@reset}\r\n" <>
      "    #{@esc}90m│#{@reset} Raxol    #{@esc}90m│#{@reset} #{@esc}33m◐ Beta#{@reset}   #{@esc}90m│#{@reset} 0.1.0    #{@esc}90m│#{@reset}\r\n" <>
      "    #{@esc}90m└──────────┴──────────┴──────────┘#{@reset}"
  end

  defp render_box do
    "    #{@esc}36m╔════════════════════════════╗#{@reset}\r\n" <>
      "    #{@esc}36m║  Raxol supports Unicode    ║#{@reset}\r\n" <>
      "    #{@esc}36m║  box-drawing characters    ║#{@reset}\r\n" <>
      "    #{@esc}36m╚════════════════════════════╝#{@reset}"
  end

  defp render_spinners do
    "    ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏   Dots\r\n" <>
      "    ◐ ◓ ◑ ◒           Circle\r\n" <>
      "    ▁ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅   Bounce\r\n" <>
      "    ← ↖ ↑ ↗ → ↘ ↓ ↙   Arrow"
  end

  defp render_animated_progress do
    "    #{@esc}32m▓▓▓▓▓▓▓▓▓▓#{@esc}33m▒▒#{@esc}90m░░░░░░░░░░░░░░░░░░#{@reset} Loading..."
  end

  defp render_typing_effect do
    "    #{@esc}32m>#{@reset} Hello, world!#{@esc}5m▌#{@reset}"
  end
end
