defmodule Raxol.Terminal.Escape.Parsers.CSIParser do
  @moduledoc """
  Parser for Control Sequence Introducer (CSI) escape sequences.

  Handles sequences in the format:
  - CSI P... I... F
  Where:
  - P: Parameters (numeric, separated by ;)
  - I: Intermediate bytes (optional)
  - F: Final byte (determines command)

  Also handles DEC Private sequences (CSI ? P... F)
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Escape.Parsers.BaseParser

  @doc """
  Parses a CSI sequence.
  Returns {:ok, command, remaining} or {:incomplete, remaining} or {:error, reason, remaining}
  """
  @spec parse(String.t()) ::
          {:ok, term(), String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse(data) do
    # First try DEC private format: CSI ? P... F
    case Regex.run(~r/^\?([\d;]*)([hl])/, data, capture: :all_but_first) do
      [params_str, final_byte] ->
        parse_dec_private(params_str, final_byte, data)

      # If DEC private fails, try standard CSI format: CSI P... F
      _ ->
        parse_standard_csi(data)
    end
  end

  @doc """
  Parses a DEC Private CSI sequence.
  """
  @spec parse_dec_private(String.t(), String.t(), String.t()) ::
          {:ok, {:set_mode, :dec_private, integer(), boolean()}, String.t()}
          | {:error, atom(), String.t()}
  def parse_dec_private(params_str, final_byte, data) do
    params = BaseParser.parse_params(params_str)
    mode_code = BaseParser.param_at(params, 0, nil)
    action = final_byte == "h"

    prefix_len = 1 + String.length(params_str) + String.length(final_byte)
    remaining = String.slice(data, prefix_len..-1)

    if mode_code do
      {:ok, {:set_mode, :dec_private, mode_code, action}, remaining}
    else
      BaseParser.log_invalid_sequence("DEC Private CSI", data)
      {:error, :invalid_sequence, remaining}
    end
  end

  @doc """
  Parses a standard CSI sequence.
  """
  @spec parse_standard_csi(String.t()) ::
          {:ok, term(), String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse_standard_csi(data) do
    case Regex.run(~r/^([\d;]*)((?:[@A-Z]|[\\[\\^_`a-z{}~]))/, data, capture: :all_but_first) do
      [params_str, final_byte] when final_byte != "" ->
        params = BaseParser.parse_params(params_str)
        prefix_len = String.length(params_str) + String.length(final_byte)
        remaining = String.slice(data, prefix_len..-1)
        dispatch_csi(params, final_byte, remaining)

      _ ->
        if BaseParser.valid_sequence_start?(data) do
          {:incomplete, ""}
        else
          BaseParser.log_invalid_sequence("CSI", data)
          {:error, :invalid_sequence, data}
        end
    end
  end

  # --- CSI Command Dispatch ---

  defp dispatch_csi(params, final_byte, remaining) do
    case final_byte do
      "H" -> dispatch_csi_cursor_position(params, remaining)
      "f" -> dispatch_csi_cursor_position(params, remaining)
      "A" -> dispatch_csi_cursor_move(params, :up, remaining)
      "B" -> dispatch_csi_cursor_move(params, :down, remaining)
      "C" -> dispatch_csi_cursor_move(params, :right, remaining)
      "D" -> dispatch_csi_cursor_move(params, :left, remaining)
      "E" -> dispatch_csi_cursor_next_line(params, remaining)
      "F" -> dispatch_csi_cursor_prev_line(params, remaining)
      "G" -> dispatch_csi_cursor_horizontal_absolute(params, remaining)
      "J" -> dispatch_csi_erase_display(params, remaining)
      "K" -> dispatch_csi_erase_line(params, remaining)
      "S" -> dispatch_csi_scroll(params, :up, remaining)
      "T" -> dispatch_csi_scroll(params, :down, remaining)
      "m" -> dispatch_csi_set_graphic_rendition(params, remaining)
      "n" -> dispatch_csi_device_status_report(params, remaining)
      "r" -> dispatch_csi_set_scroll_region(params, remaining)
      "h" -> dispatch_csi_set_mode(params, :standard, true, remaining)
      "l" -> dispatch_csi_set_mode(params, :standard, false, remaining)
      "s" -> dispatch_csi_save_cursor(params, remaining)
      "u" -> dispatch_csi_restore_cursor(params, remaining)
      _ -> dispatch_csi_unknown(params, final_byte, remaining)
    end
  end

  # --- CSI Command Handlers ---

  defp dispatch_csi_cursor_position(params, remaining) do
    row = BaseParser.param_at(params, 0, 1)
    col = BaseParser.param_at(params, 1, 1)
    {:ok, {:cursor_position, {max(0, row - 1), max(0, col - 1)}}, remaining}
  end

  defp dispatch_csi_cursor_move(params, direction, remaining) do
    count = BaseParser.param_at(params, 0, 1)
    {:ok, {:cursor_move, direction, count}, remaining}
  end

  defp dispatch_csi_cursor_next_line(params, remaining) do
    count = BaseParser.param_at(params, 0, 1)
    {:ok, {:cursor_next_line, count}, remaining}
  end

  defp dispatch_csi_cursor_prev_line(params, remaining) do
    count = BaseParser.param_at(params, 0, 1)
    {:ok, {:cursor_prev_line, count}, remaining}
  end

  defp dispatch_csi_cursor_horizontal_absolute(params, remaining) do
    col = BaseParser.param_at(params, 0, 1)
    {:ok, {:cursor_horizontal_absolute, max(0, col - 1)}, remaining}
  end

  defp dispatch_csi_erase_display(params, remaining) do
    mode = BaseParser.param_at(params, 0, 0)
    {:ok, {:erase_display, mode}, remaining}
  end

  defp dispatch_csi_erase_line(params, remaining) do
    mode = BaseParser.param_at(params, 0, 0)
    {:ok, {:erase_line, mode}, remaining}
  end

  defp dispatch_csi_scroll(params, direction, remaining) do
    count = BaseParser.param_at(params, 0, 1)
    {:ok, {:scroll, direction, count}, remaining}
  end

  defp dispatch_csi_set_graphic_rendition(params, remaining) do
    {:ok, {:set_graphic_rendition, params}, remaining}
  end

  defp dispatch_csi_device_status_report(params, remaining) do
    code = BaseParser.param_at(params, 0, 0)

    case code do
      5 -> {:ok, {:device_status_report, :status}, remaining}
      6 -> {:ok, {:device_status_report, :cursor_position}, remaining}
      _ -> {:error, :invalid_sequence, remaining}
    end
  end

  defp dispatch_csi_set_scroll_region(params, remaining) do
    top = BaseParser.param_at(params, 0, 1)
    bottom = BaseParser.param_at(params, 1, nil)
    top_0 = max(0, top - 1)

    case bottom do
      nil -> {:ok, {:set_scroll_region, nil}, remaining}
      b -> {:ok, {:set_scroll_region, {top_0, max(top_0, b - 1)}}, remaining}
    end
  end

  defp dispatch_csi_set_mode(params, mode, set?, remaining) do
    mode_code = BaseParser.param_at(params, 0, 0)

    if mode_code do
      {:ok, {:set_mode, mode, mode_code, set?}, remaining}
    else
      BaseParser.log_invalid_sequence("CSI Set Mode", remaining)
      {:error, :invalid_sequence, remaining}
    end
  end

  defp dispatch_csi_save_cursor(_params, remaining) do
    {:ok, {:dec_save_cursor, nil}, remaining}
  end

  defp dispatch_csi_restore_cursor(_params, remaining) do
    {:ok, {:dec_restore_cursor, nil}, remaining}
  end

  defp dispatch_csi_unknown(_params, final_byte, remaining) do
    BaseParser.log_unknown_sequence("CSI", final_byte <> remaining)
    {:error, :unknown_sequence, final_byte <> remaining}
  end
end
