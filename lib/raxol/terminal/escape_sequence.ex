defmodule Raxol.Terminal.EscapeSequence do
  @moduledoc """
  Handles parsing of ANSI escape sequences and other control sequences.

  This module provides functions for parsing ANSI escape sequences
  into structured data representing terminal commands.
  """

  require Logger

  # --- Public API ---

  @doc """
  Parses an input string, potentially containing an escape sequence.

  Returns:
    * `{:ok, command_data, remaining_input}` if a complete sequence is parsed.
    * `{:incomplete, remaining_input}` if the input is potentially part of a sequence but incomplete.
    * `{:error, :invalid_sequence, remaining_input}` if the sequence is malformed.
    * `{:error, :not_escape_sequence, input}` if the input doesn't start with ESC.

  `command_data` is a tuple representing the parsed command, e.g.:
    * `{:cursor_position, {row, col}}`
    * `{:cursor_move, :up, count}`
    * `{:set_mode, :dec_private, mode_code, boolean_value}`
    * `{:set_mode, :standard, mode_code, boolean_value}`
    * `{:designate_charset, target_g_set, charset_atom}`
    * `{:invoke_charset, target_g_set}`
    * etc.
  """
  @spec parse(String.t()) ::
          {:ok, term(), String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse(<<"\e", rest::binary>>) do
    parse_after_esc(rest)
  end

  def parse(input) do
    {:error, :not_escape_sequence, input}
  end

  # --- Private Parsing Logic ---

  # After initial ESC
  defp parse_after_esc(<<"[", rest::binary>>) do
    # Control Sequence Introducer
    parse_csi(rest)
  end

  defp parse_after_esc(<<char, rest::binary>>) when char in [?(, ?), ?*, ?+] do
    # Select Character Set (Designate G0-G3)
    parse_scs(char, rest)
  end

  defp parse_after_esc(<<"~", rest::binary>>) do
    # LS1R - Invoke G1 into GR
    {:ok, {:invoke_charset_gr, :g1}, rest}
  end

  defp parse_after_esc(<<"}", rest::binary>>) do
    # LS2R - Invoke G2 into GR
    {:ok, {:invoke_charset_gr, :g2}, rest}
  end

  defp parse_after_esc(<<"|", rest::binary>>) do
    # LS3R - Invoke G3 into GR
    {:ok, {:invoke_charset_gr, :g3}, rest}
  end

  defp parse_after_esc(<<"n", rest::binary>>) do
    # LS2 - Invoke G2 into GL
    {:ok, {:invoke_charset_gl, :g2}, rest}
  end

  defp parse_after_esc(<<"o", rest::binary>>) do
    # LS3 - Invoke G3 into GL
    {:ok, {:invoke_charset_gl, :g3}, rest}
  end

  # TODO: Add other ESC sequences (RIS, OSC, etc.)
  defp parse_after_esc(<<_c, _rest::binary>> = unknown) do
    # Consider single char ESC sequences like ESC D, E, M, 7, 8 etc.
    Logger.debug("Unknown sequence after ESC: \e#{unknown}")
    {:error, :unknown_sequence, unknown}
  end

  defp parse_after_esc("") do
    {:incomplete, ""}
  end

  # Parses SCS sequences (Designate Character Set)
  # ESC ( C -> Designate G0 as Charset C
  # ESC ) C -> Designate G1 as Charset C
  # ESC * C -> Designate G2 as Charset C
  # ESC + C -> Designate G3 as Charset C
  defp parse_scs(designator_char, <<charset_code, rest::binary>>) do
    target_g_set = designate_char_to_gset(designator_char)
    charset_atom = charset_code_to_atom(charset_code)

    if charset_atom do
      {:ok, {:designate_charset, target_g_set, charset_atom}, rest}
    else
      Logger.debug("Unknown charset code in SCS: #{charset_code}")
      {:error, :invalid_sequence, <<charset_code, rest::binary>>}
    end
  end

  defp parse_scs(_designator_char, "") do
    {:incomplete, ""}
  end

  # Helper for SCS
  defp designate_char_to_gset(?() do
    :g0
  end

  defp designate_char_to_gset(?)) do
    :g1
  end

  defp designate_char_to_gset(?*) do
    :g2
  end

  defp designate_char_to_gset(?+) do
    :g3
  end

  # Default case for unknown
  defp designate_char_to_gset(_) do
    nil
  end

  # Helper for SCS - Map character code byte to charset atom
  # Reference: https://vt100.net/docs/vt510-rm/SCS.html
  defp charset_code_to_atom(?B) do
    :us_ascii
  end

  defp charset_code_to_atom(?0) do
    :dec_special_graphics
  end

  # UK National
  defp charset_code_to_atom(?A) do
    :uk
  end

  # Not DEC Special Graphics
  defp charset_code_to_atom(?<) do
    :dec_supplemental
  end

  defp charset_code_to_atom(?>) do
    :dec_technical
  end

  # Add other national/standard charsets as needed (French, German, etc.)
  # Unknown/unsupported
  defp charset_code_to_atom(_) do
    nil
  end

  # Parses CSI sequences (Control Sequence Introducer)
  # Format: CSI P... I... F
  # P: Parameters (numeric, separated by ;)
  # I: Intermediate bytes (optional)
  # F: Final byte (determines command)
  defp parse_csi(data) do
    Logger.debug("Parsing CSI data: #{inspect(data)}")
    # First try DEC private format: CSI ? P... F
    case Regex.run(~r/^\?([\d;]*)([hl])/, data, capture: :all_but_first) do
      [params_str, final_byte] ->
        # --- DEBUGGING: Force error return for ?3h ---
        # if params_str == "3" and final_byte == "h" do
        #   params = parse_params(params_str)
        #   prefix_len = 1 + String.length(params_str) + String.length(final_byte)
        #   remaining = String.slice(data, prefix_len..-1)
        #   dispatch_result = dispatch_csi_dec_private(params, final_byte, remaining)
        #
        #   {:error,
        #    :debug_dec_private_match,
        #    %{input: data, params_str: params_str, final_byte: final_byte, parsed_params: params, dispatch_result: dispatch_result}
        #   }
        # else
        # --- Original Logic ---
        Logger.debug(
          "Matched DEC Private: params_str=#{inspect(params_str)}, final_byte=#{inspect(final_byte)}"
        )

        params = parse_params(params_str)
        Logger.debug("Parsed DEC Private params: #{inspect(params)}")

        # Calculate the length of the matched prefix ('?' + params + final byte)
        prefix_len =
          1 + String.length(params_str) + String.length(final_byte)

        remaining = String.slice(data, prefix_len..-1)
        result = dispatch_csi_dec_private(params, final_byte, remaining)
        Logger.debug("Result from dispatch_csi_dec_private: #{inspect(result)}")
        # Return the result
        result

      # --- End Original Logic ---
      # end

      # If DEC private fails, try standard CSI format: CSI P... F
      _ ->
        Logger.debug("DEC Private did not match, trying standard CSI.")
        # Regex captures: 1=params, 2=final byte
        case Regex.run(~r/^([\d;]*)((?:[@A-Z]|[\\[\\^_`a-z{}~]))/, data,
               capture: :all_but_first
             ) do
          [params_str, final_byte] when final_byte != "" ->
            Logger.debug(
              "Matched Standard CSI: params_str=#{inspect(params_str)}, final_byte=#{inspect(final_byte)}"
            )

            params = parse_params(params_str)
            # Calculate the length of the matched prefix (params + final byte)
            prefix_len = String.length(params_str) + String.length(final_byte)
            remaining = String.slice(data, prefix_len..-1)
            result = dispatch_csi(params, final_byte, remaining)
            Logger.debug("Result from dispatch_csi: #{inspect(result)}")
            result

          # If DEC private also fails, check for incompleteness or invalid sequence
          _ ->
            # TODO: Consider other potential intermediate characters or formats here if needed

            # Check if it *could* be a valid sequence start (numeric/param chars, optional ?, optional final)
            if String.match?(data, ~r/^[\d;?]*[@A-Za-z~]?$/) do
              # Return empty string as remaining for incomplete
              {:incomplete, ""}
            else
              Logger.debug(
                "Invalid or unsupported CSI sequence fragment: #{inspect(data)}"
              )

              {:error, :invalid_sequence, data}
            end
        end
    end
  end

  # Restore local parsing functions
  # Parse numeric parameters, defaulting to nil for empty strings
  defp parse_params(""), do: []

  defp parse_params(params_str) do
    params_str
    |> String.split(";", trim: true)
    |> Enum.map(fn
      # Empty param means default (often 1, depends on command)
      "" -> nil
      num_str -> elem(Integer.parse(num_str), 0)
    end)
  end

  # Helper to get a parameter value or default
  # Adjusted to handle potential nil from parse_params
  defp param_at(params, index, default) do
    case Enum.at(params, index) do
      # Covers both out-of-bounds and explicitly parsed nil ("")
      nil -> default
      val -> val
    end
  end

  # Dispatch based on final byte for standard CSI sequences
  defp dispatch_csi(params, final_byte, remaining) do
    # Logger.debug("Dispatch CSI: #{inspect(params)}, #{inspect(final_byte)}")
    case final_byte do
      "H" ->
        dispatch_csi_cursor_position(params, remaining)

      "f" ->
        dispatch_csi_cursor_position(params, remaining)

      "A" ->
        dispatch_csi_cursor_move(params, :up, remaining)

      "B" ->
        dispatch_csi_cursor_move(params, :down, remaining)

      "C" ->
        dispatch_csi_cursor_move(params, :right, remaining)

      "D" ->
        dispatch_csi_cursor_move(params, :left, remaining)

      "E" ->
        dispatch_csi_cursor_next_line(params, remaining)

      "F" ->
        dispatch_csi_cursor_prev_line(params, remaining)

      "G" ->
        dispatch_csi_cursor_horizontal_absolute(params, remaining)

      "J" ->
        dispatch_csi_erase_display(params, remaining)

      "K" ->
        dispatch_csi_erase_line(params, remaining)

      "S" ->
        dispatch_csi_scroll(params, :up, remaining)

      "T" ->
        dispatch_csi_scroll(params, :down, remaining)

      "m" ->
        dispatch_csi_set_graphic_rendition(params, remaining)

      "n" ->
        dispatch_csi_device_status_report(params, remaining)

      "r" ->
        dispatch_csi_set_scroll_region(params, remaining)

      "h" ->
        dispatch_csi_set_mode(params, :standard, true, remaining)

      "l" ->
        dispatch_csi_set_mode(params, :standard, false, remaining)

      "s" ->
        dispatch_csi_save_cursor(params, remaining)

      "u" ->
        dispatch_csi_restore_cursor(params, remaining)

      _ ->
        dispatch_csi_unknown(params, final_byte, remaining)
    end
  end

  # Cursor Position
  defp dispatch_csi_cursor_position(params, remaining) do
    row = param_at(params, 0, 1)
    col = param_at(params, 1, 1)
    {:ok, {:cursor_position, {max(0, row - 1), max(0, col - 1)}}, remaining}
  end

  # Cursor Move
  defp dispatch_csi_cursor_move(params, direction, remaining) do
    count = param_at(params, 0, 1)
    {:ok, {:cursor_move, direction, count}, remaining}
  end

  # Cursor Next Line
  defp dispatch_csi_cursor_next_line(params, remaining) do
    count = param_at(params, 0, 1)
    {:ok, {:cursor_next_line, count}, remaining}
  end

  # Cursor Previous Line
  defp dispatch_csi_cursor_prev_line(params, remaining) do
    count = param_at(params, 0, 1)
    {:ok, {:cursor_prev_line, count}, remaining}
  end

  # Cursor Horizontal Absolute
  defp dispatch_csi_cursor_horizontal_absolute(params, remaining) do
    col = param_at(params, 0, 1)
    {:ok, {:cursor_horizontal_absolute, max(0, col - 1)}, remaining}
  end

  # Erase in Display
  defp dispatch_csi_erase_display(params, remaining) do
    mode = param_at(params, 0, 0)
    {:ok, {:erase_display, mode}, remaining}
  end

  # Erase in Line
  defp dispatch_csi_erase_line(params, remaining) do
    mode = param_at(params, 0, 0)
    {:ok, {:erase_line, mode}, remaining}
  end

  # Scroll
  defp dispatch_csi_scroll(params, direction, remaining) do
    count = param_at(params, 0, 1)
    {:ok, {:scroll, direction, count}, remaining}
  end

  # Set Graphic Rendition
  defp dispatch_csi_set_graphic_rendition(params, remaining) do
    {:ok, {:set_graphic_rendition, params}, remaining}
  end

  # Device Status Report
  defp dispatch_csi_device_status_report(params, remaining) do
    code = param_at(params, 0, 0)

    case code do
      5 -> {:ok, {:device_status_report, :status}, remaining}
      6 -> {:ok, {:device_status_report, :cursor_position}, remaining}
      _ -> {:error, :invalid_sequence, remaining}
    end
  end

  # Set Scroll Region
  defp dispatch_csi_set_scroll_region(params, remaining) do
    top = param_at(params, 0, 1)
    bottom = param_at(params, 1, nil)
    top_0 = max(0, top - 1)

    case bottom do
      nil ->
        {:ok, {:set_scroll_region, nil}, remaining}

      b ->
        {:ok, {:set_scroll_region, {top_0, max(top_0, b - 1)}}, remaining}
    end
  end

  # Set Mode
  defp dispatch_csi_set_mode(params, mode, set?, remaining) do
    # Default mode code might vary, but common default is nil/0
    mode_code = param_at(params, 0, 0)

    if mode_code do
      {:ok, {:set_mode, mode, mode_code, set?}, remaining}
    else
      Logger.warning(
        "Set/Reset Mode sequence missing mode code: #{mode} #{Enum.join(params, ";")}"
      )

      {:error, :invalid_sequence, remaining}
    end
  end

  # Save Cursor
  # Mark params as unused
  defp dispatch_csi_save_cursor(_params, remaining) do
    {:ok, {:dec_save_cursor, nil}, remaining}
  end

  # Restore Cursor
  # Mark params as unused
  defp dispatch_csi_restore_cursor(_params, remaining) do
    {:ok, {:dec_restore_cursor, nil}, remaining}
  end

  # Unknown standard CSI
  # Mark params as unused
  defp dispatch_csi_unknown(_params, final_byte, remaining) do
    Logger.debug("Unknown standard CSI sequence: CSI ... #{final_byte}")
    {:error, :unknown_sequence, final_byte <> remaining}
  end

  # Dispatch based on final byte for DEC Private sequences (CSI ? ...)
  defp dispatch_csi_dec_private(params, final_byte, remaining) do
    mode_code = param_at(params, 0, nil)

    action =
      case final_byte do
        "h" -> true
        "l" -> false
      end

    {:ok, {:set_mode, :dec_private, mode_code, action}, remaining}
  end

  # --- Removed old process_* functions ---
  # def process_cursor_movement(...)
  # def process_cursor_style(...)
  # def process_terminal_mode(...)
  # def parse_sequence(...) # Replaced by parse/1
end
