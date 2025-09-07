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
    remaining = String.slice(data, prefix_len..-1//1)

    case mode_code do
      nil ->
        BaseParser.log_invalid_sequence("DEC Private CSI", data)
        {:error, :invalid_sequence, remaining}

      code ->
        {:ok, {:set_mode, :dec_private, code, action}, remaining}
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
    case Regex.run(~r/^([\d;]*)((?:[@A-Z]|[\\[\\^_`a-z{}~]))/, data,
           capture: :all_but_first
         ) do
      [params_str, final_byte] when final_byte != "" ->
        params = BaseParser.parse_params(params_str)
        prefix_len = String.length(params_str) + String.length(final_byte)
        remaining = String.slice(data, prefix_len..-1//1)
        dispatch_csi(params, final_byte, remaining)

      _ ->
        case BaseParser.valid_sequence_start?(data) do
          true ->
            {:incomplete, ""}

          false ->
            BaseParser.log_invalid_sequence("CSI", data)
            {:error, :invalid_sequence, data}
        end
    end
  end

  # --- CSI Command Dispatch ---

  defp dispatch_csi_cursor_position(params, remaining) do
    row = BaseParser.param_at(params, 0, 1)
    col = BaseParser.param_at(params, 1, 1)
    {:ok, {:cursor_position, {max(0, row - 1), max(0, col - 1)}}, remaining}
  end

  defp csi_dispatch_map do
    cursor_commands()
    |> Map.merge(movement_commands())
    |> Map.merge(display_commands())
    |> Map.merge(mode_commands())
    |> Map.merge(misc_commands())
  end

  defp cursor_commands do
    %{
      "H" => {:cursor_position, &dispatch_csi_cursor_position/2},
      "f" => {:cursor_position, &dispatch_csi_cursor_position/2},
      "G" => {:simple, &dispatch_csi_cursor_horizontal_absolute/2},
      "s" => {:simple, &dispatch_csi_save_cursor/2},
      "u" => {:simple, &dispatch_csi_restore_cursor/2}
    }
  end

  defp movement_commands do
    %{
      "A" => {:cursor_move, &dispatch_csi_cursor_move/3, :up},
      "B" => {:cursor_move, &dispatch_csi_cursor_move/3, :down},
      "C" => {:cursor_move, &dispatch_csi_cursor_move/3, :right},
      "D" => {:cursor_move, &dispatch_csi_cursor_move/3, :left},
      "E" => {:simple, &dispatch_csi_cursor_next_line/2},
      "F" => {:simple, &dispatch_csi_cursor_prev_line/2}
    }
  end

  defp display_commands do
    %{
      "J" => {:simple, &dispatch_csi_erase_display/2},
      "K" => {:simple, &dispatch_csi_erase_line/2},
      "L" => {:simple, &dispatch_csi_insert_line/2},
      "M" => {:simple, &dispatch_csi_delete_line/2},
      "S" => {:scroll, &dispatch_csi_scroll/3, :up},
      "T" => {:scroll, &dispatch_csi_scroll/3, :down},
      "m" => {:simple, &dispatch_csi_set_graphic_rendition/2},
      "n" => {:simple, &dispatch_csi_device_status_report/2},
      "r" => {:simple, &dispatch_csi_set_scroll_region/2}
    }
  end

  defp mode_commands do
    %{
      "h" => {:mode, &dispatch_csi_set_mode/4, true},
      "l" => {:mode, &dispatch_csi_set_mode/4, false}
    }
  end

  defp misc_commands do
    %{
      "~" => {:special_sequence, &dispatch_csi_special_sequence/2}
    }
  end

  defp dispatch_csi(params, final_byte, remaining) do
    # DEBUG output removed

    case csi_dispatch_map()[final_byte] do
      nil ->
        # DEBUG output removed
        dispatch_csi_unknown(params, final_byte, remaining)

      {:simple, handler} ->
        # DEBUG: dispatch_csi routing to simple handler for final_byte=#{inspect(final_byte)}

        handler.(params, remaining)

      {:cursor_position, handler} ->
        # DEBUG: dispatch_csi routing to cursor_position handler for final_byte=#{inspect(final_byte)}

        handler.(params, remaining)

      {:cursor_move, handler, direction} ->
        # DEBUG: dispatch_csi routing to cursor_move handler for final_byte=#{inspect(final_byte)}

        handler.(params, direction, remaining)

      {:scroll, handler, direction} ->
        # DEBUG: dispatch_csi routing to scroll handler for final_byte=#{inspect(final_byte)}

        handler.(params, direction, remaining)

      {:mode, handler, set?} ->
        # DEBUG: dispatch_csi routing to mode handler for final_byte=#{inspect(final_byte)}

        handler.(params, :standard, set?, remaining)

      {:special_sequence, handler} ->
        # DEBUG: dispatch_csi routing to special_sequence handler for final_byte=#{inspect(final_byte)}

        handler.(params, remaining)
    end
  end

  # --- CSI Command Handlers ---

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

    # DEBUG: dispatch_csi_cursor_horizontal_absolute called with params=#{inspect(params)}, col=#{inspect(col)}

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

  defp dispatch_csi_insert_line(params, remaining) do
    lines = BaseParser.param_at(params, 0, 1)
    {:ok, {:insert_line, lines}, remaining}
  end

  defp dispatch_csi_delete_line(params, remaining) do
    lines = BaseParser.param_at(params, 0, 1)
    {:ok, {:delete_line, lines}, remaining}
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

    case mode_code do
      nil ->
        BaseParser.log_invalid_sequence("CSI Set Mode", remaining)
        {:error, :invalid_sequence, remaining}

      code ->
        {:ok, {:set_mode, mode, code, set?}, remaining}
    end
  end

  defp dispatch_csi_save_cursor(_params, remaining) do
    {:ok, {:dec_save_cursor, nil}, remaining}
  end

  defp dispatch_csi_restore_cursor(_params, remaining) do
    {:ok, {:dec_restore_cursor, nil}, remaining}
  end

  defp dispatch_csi_special_sequence(params, remaining) do
    code = BaseParser.param_at(params, 0, nil)

    case code do
      200 ->
        # Bracketed paste start
        {:ok, {:bracketed_paste_start}, remaining}

      201 ->
        # Bracketed paste end
        {:ok, {:bracketed_paste_end}, remaining}

      _ ->
        BaseParser.log_unknown_sequence("CSI Special", "#{inspect(code)}~")
        {:error, :unknown_sequence, remaining}
    end
  end

  defp dispatch_csi_unknown(_params, final_byte, remaining) do
    BaseParser.log_unknown_sequence("CSI", final_byte <> remaining)
    {:error, :unknown_sequence, final_byte <> remaining}
  end
end
