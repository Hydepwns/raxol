defmodule Raxol.Terminal.ANSI.ExtendedSequences do
  @moduledoc """
  Handles extended ANSI sequences and provides improved integration with the screen buffer.
  This module adds support for:
  - Extended SGR attributes (90-97, 100-107)
  - True color support (24-bit RGB)
  - Unicode handling
  - Terminal state management
  - Improved cursor control
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.{Monitor}

  # --- Types ---

  @type color :: {0..255, 0..255, 0..255} | 0..255
  @type attribute :: :bold | :faint | :italic | :underline | :blink | :rapid_blink |
                    :inverse | :conceal | :strikethrough | :normal_intensity |
                    :no_italic | :no_underline | :no_blink | :no_inverse |
                    :no_conceal | :no_strikethrough | :foreground | :background |
                    :foreground_basic | :background_basic

  # --- Public API ---

  @doc """
  Processes extended SGR (Select Graphic Rendition) parameters.
  Supports:
  - Extended colors (90-97, 100-107)
  - True color (24-bit RGB)
  - Additional attributes
  """
  @spec process_extended_sgr(list(String.t()), ScreenBuffer.t()) :: ScreenBuffer.t()
  def process_extended_sgr(params, buffer) do
    try do
      Enum.reduce(params, buffer, &process_sgr_param/2)
    rescue
      e ->
        Monitor.record_error("", "Extended SGR error: #{inspect(e)}", %{
          params: params,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        buffer
    end
  end

  @doc """
  Processes true color sequences (24-bit RGB).
  """
  @spec process_true_color(String.t(), String.t(), ScreenBuffer.t()) :: ScreenBuffer.t()
  def process_true_color(type, color_str, buffer) do
    try do
      {r, g, b} = parse_true_color(color_str)
      style = case type do
        "38" -> %{buffer.default_style | foreground: {r, g, b}}
        "48" -> %{buffer.default_style | background: {r, g, b}}
        _ -> buffer.default_style
      end
      %{buffer | default_style: style}
    rescue
      e ->
        Monitor.record_error("", "True color error: #{inspect(e)}", %{
          type: type,
          color: color_str,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        buffer
    end
  end

  @doc """
  Handles Unicode character sequences.
  """
  @spec process_unicode(String.t(), ScreenBuffer.t()) :: ScreenBuffer.t()
  def process_unicode(char, buffer) do
    try do
      # Validate Unicode character
      if String.valid?(char) do
        # Process the character with current style
        ScreenBuffer.write_char(buffer, char, buffer.default_style)
      else
        buffer
      end
    rescue
      e ->
        Monitor.record_error("", "Unicode error: #{inspect(e)}", %{
          char: char,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        buffer
    end
  end

  @doc """
  Processes terminal state changes.
  """
  @spec process_terminal_state(String.t(), ScreenBuffer.t()) :: ScreenBuffer.t()
  def process_terminal_state(state, buffer) do
    try do
      case state do
        "?25h" -> %{buffer | cursor_visible: true}
        "?25l" -> %{buffer | cursor_visible: false}
        "?47h" -> %{buffer | alternate_screen: true}
        "?47l" -> %{buffer | alternate_screen: false}
        "?1049h" -> %{buffer | alternate_screen_buffer: true}
        "?1049l" -> %{buffer | alternate_screen_buffer: false}
        _ -> buffer
      end
    rescue
      e ->
        Monitor.record_error("", "Terminal state error: #{inspect(e)}", %{
          state: state,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        buffer
    end
  end

  # --- Private Implementation ---

  defp process_sgr_param(param, buffer) do
    case param do
      # Extended foreground colors (90-97)
      color when color >= "90" and color <= "97" ->
        style = %{buffer.default_style | foreground: String.to_integer(color) - 90 + 8}
        %{buffer | default_style: style}

      # Extended background colors (100-107)
      color when color >= "100" and color <= "107" ->
        style = %{buffer.default_style | background: String.to_integer(color) - 100 + 8}
        %{buffer | default_style: style}

      # True color sequences
      "38;2;" <> rest ->
        process_true_color("38", rest, buffer)
      "48;2;" <> rest ->
        process_true_color("48", rest, buffer)

      # Additional attributes
      "1" -> %{buffer | default_style: %{buffer.default_style | bold: true}}
      "2" -> %{buffer | default_style: %{buffer.default_style | faint: true}}
      "3" -> %{buffer | default_style: %{buffer.default_style | italic: true}}
      "4" -> %{buffer | default_style: %{buffer.default_style | underline: true}}
      "5" -> %{buffer | default_style: %{buffer.default_style | blink: true}}
      "6" -> %{buffer | default_style: %{buffer.default_style | rapid_blink: true}}
      "7" -> %{buffer | default_style: %{buffer.default_style | inverse: true}}
      "8" -> %{buffer | default_style: %{buffer.default_style | conceal: true}}
      "9" -> %{buffer | default_style: %{buffer.default_style | strikethrough: true}}
      "22" -> %{buffer | default_style: %{buffer.default_style | bold: false, faint: false}}
      "23" -> %{buffer | default_style: %{buffer.default_style | italic: false}}
      "24" -> %{buffer | default_style: %{buffer.default_style | underline: false}}
      "25" -> %{buffer | default_style: %{buffer.default_style | blink: false, rapid_blink: false}}
      "27" -> %{buffer | default_style: %{buffer.default_style | inverse: false}}
      "28" -> %{buffer | default_style: %{buffer.default_style | conceal: false}}
      "29" -> %{buffer | default_style: %{buffer.default_style | strikethrough: false}}
      "39" -> %{buffer | default_style: %{buffer.default_style | foreground: nil}}
      "49" -> %{buffer | default_style: %{buffer.default_style | background: nil}}
      _ -> buffer
    end
  end

  defp parse_true_color(color_str) do
    [r, g, b] = String.split(color_str, ";") |> Enum.map(&String.to_integer/1)
    {r, g, b}
  end
end
