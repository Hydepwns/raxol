defmodule Raxol.Terminal.Escape.Parsers.CSIParser do
  @moduledoc """
  Parser for CSI (Control Sequence Introducer) escape sequences.

  CSI sequences are introduced by ESC [ and contain various terminal control commands
  for cursor movement, text formatting, screen manipulation, etc.
  """

  alias Raxol.Terminal.Escape.Parsers.BaseParser

  @doc """
  Parses a CSI sequence after the ESC [ prefix.

  ## Parameters
    - input: The input string after ESC [

  ## Returns
    - `{:ok, command, remaining}` - Successfully parsed command
    - `{:incomplete, input}` - Input is incomplete, need more data
    - `{:error, reason, input}` - Parse error
  """
  @spec parse(String.t()) ::
          {:ok, term(), String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse(input) when is_binary(input) do
    parse_csi_body(input, "", "")
  end

  # Private parsing functions

  defp parse_csi_body(<<??, rest::binary>>, "", "") do
    # DEC Private Mode prefix - treat ? as intermediate
    parse_csi_body(rest, "", "?")
  end

  defp parse_csi_body(<<char, rest::binary>>, params, intermediates) do
    cond do
      BaseParser.parameter?(char) ->
        # Accumulate parameter bytes (0-9, ;, etc.)
        parse_csi_body(rest, params <> <<char>>, intermediates)

      BaseParser.intermediate?(char) ->
        # Accumulate intermediate bytes
        parse_csi_body(rest, params, intermediates <> <<char>>)

      BaseParser.final?(char) ->
        # Final byte found, decode the sequence
        command = decode_csi(<<char>>, params, intermediates)
        {:ok, command, rest}

      true ->
        # Invalid character in CSI sequence
        {:error, :invalid_csi_character, <<char, rest::binary>>}
    end
  end

  defp parse_csi_body("", _params, _intermediates) do
    {:incomplete, ""}
  end

  # CSI command decoding

  defp decode_csi("A", params, "") do
    # Cursor Up
    count = parse_count(params, 1)
    {:cursor_move, :up, count}
  end

  defp decode_csi("B", params, "") do
    # Cursor Down
    count = parse_count(params, 1)
    {:cursor_move, :down, count}
  end

  defp decode_csi("C", params, "") do
    # Cursor Forward/Right
    count = parse_count(params, 1)
    {:cursor_move, :right, count}
  end

  defp decode_csi("D", params, "") do
    # Cursor Back/Left
    count = parse_count(params, 1)
    {:cursor_move, :left, count}
  end

  defp decode_csi("E", params, "") do
    # Cursor Next Line
    count = parse_count(params, 1)
    {:cursor_next_line, count}
  end

  defp decode_csi("F", params, "") do
    # Cursor Previous Line
    count = parse_count(params, 1)
    {:cursor_prev_line, count}
  end

  defp decode_csi("G", params, "") do
    # Cursor Horizontal Absolute
    col = parse_count(params, 1)
    {:cursor_horizontal_absolute, max(col - 1, 0)}
  end

  defp decode_csi("H", params, "") do
    # Cursor Position
    {row, col} = parse_position(params)
    {:cursor_position, {row, col}}
  end

  defp decode_csi("J", params, "") do
    # Erase in Display
    mode = parse_erase_mode(params)
    {:erase_display, mode}
  end

  defp decode_csi("K", params, "") do
    # Erase in Line
    mode = parse_erase_mode(params)
    {:erase_line, mode}
  end

  defp decode_csi("L", params, "") do
    # Insert Lines
    count = parse_count(params, 1)
    {:insert_lines, count}
  end

  defp decode_csi("M", params, "") do
    # Delete Lines
    count = parse_count(params, 1)
    {:delete_lines, count}
  end

  defp decode_csi("P", params, "") do
    # Delete Characters
    count = parse_count(params, 1)
    {:delete_chars, count}
  end

  defp decode_csi("S", params, "") do
    # Scroll Up
    count = parse_count(params, 1)
    {:scroll_up, count}
  end

  defp decode_csi("T", params, "") do
    # Scroll Down
    count = parse_count(params, 1)
    {:scroll_down, count}
  end

  defp decode_csi("X", params, "") do
    # Erase Characters
    count = parse_count(params, 1)
    {:erase_chars, count}
  end

  defp decode_csi("d", params, "") do
    # Line Position Absolute
    row = parse_count(params, 1)
    {:cursor_row, row}
  end

  defp decode_csi("f", params, "") do
    # Horizontal and Vertical Position (same as H)
    {row, col} = parse_position(params)
    {:cursor_position, {row, col}}
  end

  defp decode_csi("g", params, "") do
    # Tab Clear
    mode = parse_tab_clear_mode(params)
    {:tab_clear, mode}
  end

  defp decode_csi("h", params, "") do
    # Set Mode
    parse_set_mode(params, true)
  end

  defp decode_csi("l", params, "") do
    # Reset Mode
    parse_set_mode(params, false)
  end

  defp decode_csi("m", params, "") do
    # Select Graphic Rendition (SGR)
    {:sgr, params}
  end

  defp decode_csi("n", params, "") do
    # Device Status Report
    code = parse_count(params, 0)
    {:device_status_report, code}
  end

  defp decode_csi("r", params, "") do
    # Set Scrolling Region
    {top, bottom} = parse_position(params)
    {:set_scroll_region, {top, bottom}}
  end

  defp decode_csi("s", _params, "") do
    # Save Cursor Position
    {:save_cursor}
  end

  defp decode_csi("u", _params, "") do
    # Restore Cursor Position
    {:restore_cursor}
  end

  defp decode_csi("h", params, "?") do
    # Set DEC Private Mode
    parse_dec_mode(params, true)
  end

  defp decode_csi("l", params, "?") do
    # Reset DEC Private Mode
    parse_dec_mode(params, false)
  end

  defp decode_csi("@", params, "") do
    # Insert Characters
    count = parse_count(params, 1)
    {:insert_chars, count}
  end

  defp decode_csi(final, params, intermediates) do
    # Unknown CSI sequence
    BaseParser.log_unknown_sequence("CSI", intermediates <> params <> final)
    {:unknown_csi, final, params, intermediates}
  end

  # Helper functions for parsing parameters

  defp parse_count("", default), do: default

  defp parse_count(params, default) do
    case BaseParser.parse_int(params) do
      nil -> default
      n when n > 0 -> n
      _ -> default
    end
  end

  defp parse_position("") do
    {0, 0}
  end

  defp parse_position(params) do
    case String.split(params, ";") do
      [row_str] ->
        row = parse_count(row_str, 1)
        {max(row - 1, 0), 0}

      [row_str, col_str] ->
        row = parse_count(row_str, 1)
        col = parse_count(col_str, 1)
        {max(row - 1, 0), max(col - 1, 0)}

      _ ->
        {0, 0}
    end
  end

  defp parse_erase_mode(""), do: :to_end
  defp parse_erase_mode("0"), do: :to_end
  defp parse_erase_mode("1"), do: :to_beginning
  defp parse_erase_mode("2"), do: :all
  defp parse_erase_mode("3"), do: :all_and_scrollback
  defp parse_erase_mode(_), do: :to_end

  defp parse_tab_clear_mode(""), do: :current
  defp parse_tab_clear_mode("0"), do: :current
  defp parse_tab_clear_mode("3"), do: :all
  defp parse_tab_clear_mode(_), do: :current

  defp parse_set_mode(params, value) do
    case BaseParser.parse_int(params) do
      nil -> {:set_mode, :standard, 0, value}
      mode -> {:set_mode, :standard, mode, value}
    end
  end

  defp parse_dec_mode(params, value) do
    case BaseParser.parse_int(params) do
      nil -> {:set_mode, :dec_private, 0, value}
      mode -> {:set_mode, :dec_private, mode, value}
    end
  end
end
