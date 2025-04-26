defmodule Raxol.Terminal.ANSI.Parser do
  @moduledoc """
  ANSI escape sequence parser module.

  Provides comprehensive parsing for ANSI escape sequences, determining
  the type of sequence and extracting its parameters for processing.
  This is the main entry point for parsing all ANSI sequences.
  """

  # alias Raxol.Terminal.ANSI.State # Unused
  # alias Raxol.Terminal.ANSI.Actions # Unused
  # alias Raxol.Terminal.Cursor # Unused
  # alias Raxol.Terminal.ANSI.Sequences # Unused

  require Logger

  @doc """
  Parse a string containing ANSI escape sequences into tokens.

  This function scans through the input and returns a list of tokens, where each
  token is either a plain string or a parsed ANSI sequence.

  ## Parameters

  * `input` - The string containing ANSI escape sequences

  ## Returns

  A list of tokens where each token is either:
    - A binary string (plain text)
    - A tuple representing a parsed ANSI sequence

  ## Examples

      iex> Raxol.Terminal.ANSI.Parser.parse("Hello\e[31mWorld")
      ["Hello", {:text_attributes, [{:foreground_basic, 1}]}]
  """
  def parse(input) when is_binary(input) do
    # Pattern to match ANSI escape sequences
    pattern = ~r/\e\[[^\x40-\x7E]*[\x40-\x7E]|\e[\(\)][A-Z0-9]|\e][^\a]*\a/

    # Split the input into a list of tokens
    Regex.split(pattern, input, include_captures: true, trim: true)
    |> Enum.map(fn
      # If the token starts with an escape character, parse it as an ANSI sequence
      "\e" <> _ = sequence -> parse_sequence(sequence)
      # Otherwise, keep it as plain text
      text -> text
    end)
  end

  @doc """
  Parse an ANSI escape sequence and return its type and parameters.

  ## Parameters

  * `sequence` - The ANSI sequence to parse

  ## Returns

  Parsed sequence as a tuple of type and parameters or error
  """
  def parse_sequence(sequence) do
    cond do
      # Cursor movement sequences
      String.match?(sequence, ~r/^\e\[\d*[ABCDHFST]/) ->
        parse_cursor_sequence(sequence)

      # Color and text attribute sequences
      String.match?(sequence, ~r/^\e\[\d*(;\d+)*m/) ->
        parse_sgr_sequence(sequence)

      # Screen manipulation sequences
      String.match?(sequence, ~r/^\e\[\d*[JKL]/) ->
        parse_screen_sequence(sequence)

      # Mode setting sequences
      String.match?(sequence, ~r/^\e\[\?(\d+)(h|l)/) ->
        parse_mode_sequence(sequence)

      # Device status report sequences
      String.match?(sequence, ~r/^\e\[\d*n/) ->
        parse_device_status_sequence(sequence)

      # Character set sequences
      String.match?(sequence, ~r/^\e[\(\)][A-Z0-9]/) ->
        parse_charset_sequence(sequence)

      # OSC sequences for window title, etc.
      String.starts_with?(sequence, "\e]") ->
        parse_osc_sequence(sequence)

      # Unknown or unsupported sequence
      true ->
        {:unknown, sequence}
    end
  end

  defp parse_cursor_sequence(sequence) do
    # Example: \e[nA (cursor up n lines)
    case Regex.run(~r/^\e\[(\d*)(A|B|C|D|H|F|S|T)/, sequence,
           capture: :all_but_first
         ) do
      [n, "A"] ->
        n = parse_optional_number(n, 1)
        {:cursor_up, n}

      [n, "B"] ->
        n = parse_optional_number(n, 1)
        {:cursor_down, n}

      [n, "C"] ->
        n = parse_optional_number(n, 1)
        {:cursor_forward, n}

      [n, "D"] ->
        n = parse_optional_number(n, 1)
        {:cursor_backward, n}

      [coords, "H"] ->
        {row, col} = parse_coordinates(coords)
        {:cursor_move, row, col}

      [coords, "F"] ->
        {row, col} = parse_coordinates(coords)
        {:cursor_move, row, col}

      ["", "H"] ->
        # Default to home position (1,1)
        {:cursor_move, 1, 1}

      [_, "S"] ->
        {:cursor_save}

      [_, "T"] ->
        {:cursor_restore}

      _ ->
        {:error, "Invalid cursor sequence: #{sequence}"}
    end
  end

  defp parse_sgr_sequence(sequence) do
    # Example: \e[31;42;1m (red foreground, green background, bold)
    case Regex.run(~r/^\e\[([\d;]*)m/, sequence, capture: :all_but_first) do
      [""] ->
        # Empty parameter means reset all attributes
        {:reset_attributes}

      [params] ->
        params = String.split(params, ";")
        parse_sgr_params(params, [])
    end
  end

  defp parse_sgr_params([], acc), do: {:text_attributes, Enum.reverse(acc)}

  defp parse_sgr_params(["0" | rest], _acc) do
    # Reset attributes and start over
    parse_sgr_params(rest, [:reset])
  end

  defp parse_sgr_params([param | rest], acc) do
    case param do
      # Foreground colors 30-37, 90-97
      color when color >= "30" and color <= "37" ->
        color_code = String.to_integer(color) - 30
        parse_sgr_params(rest, [{:foreground_basic, color_code} | acc])

      color when color >= "90" and color <= "97" ->
        # Bright colors start at 8
        color_code = String.to_integer(color) - 90 + 8
        parse_sgr_params(rest, [{:foreground_basic, color_code} | acc])

      # Background colors 40-47, 100-107
      color when color >= "40" and color <= "47" ->
        color_code = String.to_integer(color) - 40
        parse_sgr_params(rest, [{:background_basic, color_code} | acc])

      color when color >= "100" and color <= "107" ->
        # Bright colors start at 8
        color_code = String.to_integer(color) - 100 + 8
        parse_sgr_params(rest, [{:background_basic, color_code} | acc])

      # 256-color and RGB color
      "38" ->
        {color_type, remaining} = parse_extended_color(rest)
        parse_sgr_params(remaining, [color_type | acc])

      "48" ->
        {color_type, remaining} = parse_extended_color(rest)
        parse_sgr_params(remaining, [color_type | acc])

      # Text attributes
      attr ->
        case parse_text_attribute(attr) do
          nil ->
            Logger.debug("Unknown SGR parameter: #{attr}")
            parse_sgr_params(rest, acc)

          attr_atom ->
            parse_sgr_params(rest, [attr_atom | acc])
        end
    end
  end

  defp parse_extended_color(["5", index | rest]) do
    # 256-color mode: \e[38;5;Nm or \e[48;5;Nm
    index = String.to_integer(index)

    if rest == [],
      do: {{:foreground_256, index}, []},
      else: {{:foreground_256, index}, rest}
  end

  defp parse_extended_color(["2", r, g, b | rest]) do
    # RGB color mode: \e[38;2;R;G;Bm or \e[48;2;R;G;Bm
    r = String.to_integer(r)
    g = String.to_integer(g)
    b = String.to_integer(b)

    if rest == [],
      do: {{:foreground_true, r, g, b}, []},
      else: {{:foreground_true, r, g, b}, rest}
  end

  defp parse_extended_color(params) do
    # Invalid format, skip
    Logger.debug("Invalid extended color format: #{inspect(params)}")
    {{:unknown_color, params}, []}
  end

  defp parse_text_attribute(attr) do
    case attr do
      "0" -> :reset
      "1" -> :bold
      "2" -> :faint
      "3" -> :italic
      "4" -> :underline
      "5" -> :blink
      "6" -> :rapid_blink
      "7" -> :inverse
      "8" -> :conceal
      "9" -> :strikethrough
      "22" -> :normal_intensity
      "23" -> :no_italic
      "24" -> :no_underline
      "25" -> :no_blink
      "27" -> :no_inverse
      "28" -> :no_conceal
      "29" -> :no_strikethrough
      _ -> nil
    end
  end

  defp parse_screen_sequence(sequence) do
    # Example: \e[2J (clear screen)
    case Regex.run(~r/^\e\[(\d*)(J|K|L)/, sequence, capture: :all_but_first) do
      [n, "J"] ->
        n = parse_optional_number(n, 0)
        {:clear_screen, n}

      [n, "K"] ->
        n = parse_optional_number(n, 0)
        {:clear_line, n}

      [n, "L"] ->
        n = parse_optional_number(n, 1)
        {:insert_line, n}

      _ ->
        {:error, "Invalid screen sequence: #{sequence}"}
    end
  end

  defp parse_mode_sequence(sequence) do
    # Example: \e[?25h (show cursor)
    case Regex.run(~r/^\e\[\?(\d+)([hl])/, sequence, capture: :all_but_first) do
      [mode, "h"] ->
        mode = String.to_integer(mode)
        {:set_mode, mode, true}

      [mode, "l"] ->
        mode = String.to_integer(mode)
        {:set_mode, mode, false}

      _ ->
        {:error, "Invalid mode sequence: #{sequence}"}
    end
  end

  defp parse_device_status_sequence(sequence) do
    # Example: \e[6n (request cursor position)
    case Regex.run(~r/^\e\[(\d*)n/, sequence, capture: :all_but_first) do
      [report_type] ->
        report_type = parse_optional_number(report_type, 0)
        {:device_status, report_type}

      _ ->
        {:error, "Invalid device status sequence: #{sequence}"}
    end
  end

  defp parse_charset_sequence(sequence) do
    # Example: \e(B (set G0 charset to US ASCII)
    case Regex.run(~r/^\e([\(\)])([A-Z0-9])/, sequence, capture: :all_but_first) do
      ["(", charset] ->
        {:designate_charset, 0, charset}

      [")", charset] ->
        {:designate_charset, 1, charset}

      _ ->
        {:error, "Invalid charset sequence: #{sequence}"}
    end
  end

  defp parse_osc_sequence(sequence) do
    # Example: \e]0;title\a (set window title)
    case Regex.run(~r/^\e\](\d+);(.*?)\a/, sequence, capture: :all_but_first) do
      [cmd, param] ->
        cmd = String.to_integer(cmd)
        {:osc, cmd, param}

      _ ->
        {:error, "Invalid OSC sequence: #{sequence}"}
    end
  end

  defp parse_optional_number("", default), do: default
  defp parse_optional_number(string, _default), do: String.to_integer(string)

  defp parse_coordinates(coords) do
    case String.split(coords, ";") do
      [row, col] ->
        {String.to_integer(row), String.to_integer(col)}

      [row] ->
        {String.to_integer(row), 1}

      [] ->
        {1, 1}
    end
  end
end
