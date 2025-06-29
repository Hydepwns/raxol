defmodule Raxol.Terminal.ANSI.ExtendedSequences do
  import Raxol.Guards

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
  @type attribute ::
          :bold
          | :faint
          | :italic
          | :underline
          | :blink
          | :rapid_blink
          | :inverse
          | :conceal
          | :strikethrough
          | :normal_intensity
          | :no_italic
          | :no_underline
          | :no_blink
          | :no_inverse
          | :no_conceal
          | :no_strikethrough
          | :foreground
          | :background
          | :foreground_basic
          | :background_basic

  # --- Public API ---

  @doc """
  Processes extended SGR (Select Graphic Rendition) parameters.
  Supports:
  - Extended colors (90-97, 100-107)
  - True color (24-bit RGB)
  - Additional attributes
  """
  @spec process_extended_sgr(list(String.t()), ScreenBuffer.t()) ::
          ScreenBuffer.t()
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
  @spec process_true_color(String.t(), String.t(), ScreenBuffer.t()) ::
          ScreenBuffer.t()
  def process_true_color(type, color_str, buffer) do
    try do
      {r, g, b} = parse_true_color(color_str)

      style =
        case type do
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
        ScreenBuffer.write_char(buffer, 0, 0, char, buffer.default_style)
      else
        # For invalid Unicode, don't write anything, leaving the cell unchanged
        # This means get_char will return the original content (likely nil or space)
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
        "?1049h" -> %{buffer | alternate_screen: true}
        "?1049l" -> %{buffer | alternate_screen: false}
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

  @attribute_map %{
    "1" => {:bold, true},
    "2" => {:faint, true},
    "3" => {:italic, true},
    "4" => {:underline, true},
    "5" => {:blink, true},
    "6" => {:rapid_blink, true},
    "7" => {:inverse, true},
    "8" => {:conceal, true},
    "9" => {:strikethrough, true},
    "22" => {[:bold, :faint], false},
    "23" => {:italic, false},
    "24" => {:underline, false},
    "25" => {[:blink, :rapid_blink], false},
    "27" => {:inverse, false},
    "28" => {:conceal, false},
    "29" => {:strikethrough, false},
    "39" => {:foreground, nil},
    "49" => {:background, nil}
  }

  defp process_sgr_param(param, buffer) do
    cond do
      extended_color?(param) -> process_extended_color(param, buffer)
      true_color?(param) -> process_true_color_param(param, buffer)
      true -> process_attribute(param, buffer)
    end
  end

  defp extended_color?(param) do
    (param >= "90" and param <= "97") or (param >= "100" and param <= "107")
  end

  defp true_color?(param) do
    String.starts_with?(param, ["38;2;", "48;2;"])
  end

  defp process_extended_color(param, buffer) do
    color = String.to_integer(param)
    {type, value} = calculate_extended_color(color)
    style = Map.put(buffer.default_style, type, value)
    %{buffer | default_style: style}
  end

  defp calculate_extended_color(color) when color >= 100 do
    {:background, color - 100 + 8}
  end

  defp calculate_extended_color(color) do
    {:foreground, color - 90 + 8}
  end

  defp process_true_color_param(param, buffer) do
    [type, _color_space | rest] = String.split(param, ";")
    process_true_color(type, Enum.join(rest, ";"), buffer)
  end

  defp process_attribute(param, buffer) do
    case Map.get(@attribute_map, param) do
      {attr, value} -> update_style(buffer, attr, value)
      nil -> buffer
    end
  end

  defp update_style(buffer, attr, value) when atom?(attr) do
    %{buffer | default_style: Map.put(buffer.default_style, attr, value)}
  end

  defp update_style(buffer, attrs, value) when list?(attrs) do
    style = Enum.reduce(attrs, buffer.default_style, &Map.put(&2, &1, value))
    %{buffer | default_style: style}
  end

  defp parse_true_color(color_str) do
    [r, g, b] = String.split(color_str, ";") |> Enum.map(&String.to_integer/1)
    {r, g, b}
  end
end
