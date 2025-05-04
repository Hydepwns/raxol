defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc """
  Executes parsed terminal commands (CSI, OSC, DCS).

  This module takes parsed command details and the current emulator state,
  and returns the updated emulator state after applying the command's effects.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.System.Clipboard
  alias Raxol.Terminal.ANSI.SixelGraphics
  require Logger

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  TODO: Implement the actual logic for handling various CSI commands.
  This likely involves pattern matching on the final_byte and intermediates,
  parsing parameters, and calling specific handler functions (e.g., from
  Modes, Screen, Cursor modules).
  """
  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    # Parse parameters
    params = Parser.parse_params(params_buffer)

    # Dispatch based on final byte
    case final_byte do
      # 'm' - Select Graphic Rendition (SGR)
      ?m ->
        # Process parameters statefully to handle multi-param codes (38, 48)
        new_style = process_sgr_params(params, emulator.style)
        # Update emulator state with the new style
        %{emulator | style: new_style}

      # 'H' - Cursor Position (CUP)
      ?H ->
        # Params: [row, col], default to 1,1
        # FIX: Use 0-based indices for get_param
        row = Parser.get_param(params, 0, 1)
        col = Parser.get_param(params, 1, 1)
        # Convert to 0-based index for cursor manager
        new_cursor = CursorManager.move_to(emulator.cursor, col - 1, row - 1)
        %{emulator | cursor: new_cursor}

      # 'r' - Set Top and Bottom Margins (DECSTBM)
      ?r ->
        # Params: [top, bottom], default to 1, screen_height
        # Parameters are 1-based, get_param expects 0-based index
        top = Parser.get_param(params, 0, 1)
        # Get height from active buffer
        height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
        bottom = Parser.get_param(params, 1, height)

        # Validate: top < bottom and within screen bounds
        if top >= 1 and top < bottom and bottom <= height do
          # Store 0-based region
          %{emulator | scroll_region: {top - 1, bottom - 1}}
        else
          emulator
        end

      # 'h' - Set Mode (SM)
      # 'l' - Reset Mode (RM)
      final_byte when final_byte in [?h, ?l] ->
        action = if final_byte == ?h, do: :set, else: :reset
        # Check for DEC Private Mode marker ('?')
        if intermediates_buffer == "?" do
          ScreenModes.handle_dec_private_mode(emulator, {hd(params), action})
        else
          ScreenModes.handle_ansi_mode(emulator, params, action)
        end

      # \'J\' - Erase in Display (ED)
      ?J ->
        param = Parser.get_param(params, 0, 0)
        # Delegate to ScreenBuffer
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.erase_in_display(active_buffer, param, emulator.cursor)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'K\' - Erase in Line (EL)
      ?K ->
        param = Parser.get_param(params, 0, 0)
        # Delegate to ScreenBuffer
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.erase_in_line(active_buffer, param, emulator.cursor)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'A\' - Cursor Up (CUU)
      ?A ->
        count = Parser.get_param(params, 0, 1)
        new_cursor = CursorManager.move_up(emulator.cursor, count)
        %{emulator | cursor: new_cursor}

      # \'B\' - Cursor Down (CUD)
      ?B ->
        count = Parser.get_param(params, 0, 1)
        # Need terminal height to constrain movement
        active_buffer = Emulator.get_active_buffer(emulator)
        height = ScreenBuffer.get_height(active_buffer)
        {current_col, current_row} = emulator.cursor.position
        new_row = min(current_row + count, height - 1) # Calculate new row, clamp to bounds
        new_cursor = CursorManager.move_to(emulator.cursor, current_col, new_row)
        %{emulator | cursor: new_cursor}

      # \'C\' - Cursor Forward (CUF)
      ?C ->
        count = Parser.get_param(params, 0, 1)
        # Need terminal width to constrain movement
        active_buffer = Emulator.get_active_buffer(emulator)
        width = ScreenBuffer.get_width(active_buffer)
        {current_col, current_row} = emulator.cursor.position
        new_col = min(current_col + count, width - 1) # Calculate new col, clamp to bounds
        new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
        %{emulator | cursor: new_cursor}

      # \'D\' - Cursor Backward (CUB)
      ?D ->
        count = Parser.get_param(params, 0, 1)
        # Calculate new col, clamp to bounds
        {current_col, current_row} = emulator.cursor.position
        new_col = max(current_col - count, 0)
        new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
        %{emulator | cursor: new_cursor}

      # \'E\' - Cursor Next Line (CNL)
      ?E ->
        count = Parser.get_param(params, 0, 1)
        # Move down N lines to column 0
        active_buffer = Emulator.get_active_buffer(emulator)
        height = ScreenBuffer.get_height(active_buffer)
        {_current_col, current_row} = emulator.cursor.position
        new_row = min(current_row + count, height - 1) # Calculate new row, clamp to bounds
        new_cursor = CursorManager.move_to(emulator.cursor, 0, new_row)
        %{emulator | cursor: new_cursor}

      # \'F\' - Cursor Previous Line (CPL)
      ?F ->
        count = Parser.get_param(params, 0, 1)
        # Move up N lines to column 0
        {_current_col, current_row} = emulator.cursor.position
        new_row = max(current_row - count, 0) # Calculate new row, clamp to bounds
        new_cursor = CursorManager.move_to(emulator.cursor, 0, new_row)
        %{emulator | cursor: new_cursor}

      # \'G\' - Cursor Horizontal Absolute (CHA)
      ?G ->
        col = Parser.get_param(params, 0, 1)
        # Move to column N (1-based) on the current row
        active_buffer = Emulator.get_active_buffer(emulator)
        width = ScreenBuffer.get_width(active_buffer)
        {_current_col, current_row} = emulator.cursor.position
        new_col = min(max(col - 1, 0), width - 1) # Calculate new col (0-based), clamp
        new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
        %{emulator | cursor: new_cursor}

      # \'d\' - Vertical Line Position Absolute (VPA)
      ?d ->
        row = Parser.get_param(params, 0, 1)
        # Move to row N (1-based) on the current column
        active_buffer = Emulator.get_active_buffer(emulator)
        height = ScreenBuffer.get_height(active_buffer)
        {current_col, _current_row} = emulator.cursor.position
        new_row = min(max(row - 1, 0), height - 1) # Calculate new row (0-based), clamp
        new_cursor = CursorManager.move_to(emulator.cursor, current_col, new_row)
        %{emulator | cursor: new_cursor}

      # \'L\' - Insert Lines (IL)
      ?L ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        {_current_col, current_row} = emulator.cursor.position # Destructure position
        new_buffer = ScreenBuffer.insert_lines(active_buffer, current_row, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'M\' - Delete Lines (DL)
      ?M ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        {_current_col, current_row} = emulator.cursor.position # Destructure position
        new_buffer = ScreenBuffer.delete_lines(active_buffer, current_row, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'P\' - Delete Characters (DCH)
      ?P ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        {current_col, current_row} = emulator.cursor.position # Destructure position
        # FIX: Pass position as {col, row} tuple
        new_buffer = ScreenBuffer.delete_characters(active_buffer, {current_col, current_row}, count)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'@\' - Insert Characters (ICH)
      ?@ ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        {current_col, current_row} = emulator.cursor.position # Destructure position
        # FIX: Pass position as {col, row} tuple and include current style
        new_buffer = ScreenBuffer.insert_characters(active_buffer, {current_col, current_row}, count, emulator.style)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'S\' - Scroll Up (SU)
      ?S ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.scroll_up(active_buffer, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'T\' - Scroll Down (SD)
      ?T ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.scroll_down(active_buffer, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'X\' - Erase Character (ECH)
      ?X ->
        count = Parser.get_param(params, 0, 1)
        active_buffer = Emulator.get_active_buffer(emulator)
        {current_col, current_row} = emulator.cursor.position # Destructure position
        # Use alias ScreenBuffer
        new_buffer = ScreenBuffer.erase_characters(active_buffer, current_row, current_col, count)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # 'c' - Send Device Attributes (DA)
      ?c ->
        # Determine if it's Primary or Secondary DA based on intermediate
        is_secondary_da = (intermediates_buffer == ">")
        param = Parser.get_param(params, 0, 0)

        # Only respond if param is 0
        if param == 0 do
          if is_secondary_da do
            # Secondary DA (> 0 c) Response
            response = "\e[>0;0;0c" # Placeholder version/cartridge
            %{emulator | output_buffer: emulator.output_buffer <> response}
          else
            # Primary DA (0 c) Response
            response = "\e[?6c" # VT102 ID
            %{emulator | output_buffer: emulator.output_buffer <> response}
          end
        else
          # Ignore non-zero parameters for DA
          emulator
        end

      # \'n\' - Device Status Report (DSR)
      ?n ->
        param = Parser.get_param(params, 0, 0)
        Logger.debug("Handling DSR (n) with param: #{param}")
        response = case param do
          # Status report: Respond OK
          5 -> "\e[0n"
          # Cursor position report
          6 ->
            # Get 1-based row/col using direct access
            {col, row} = emulator.cursor.position
            "\e[#{row + 1};#{col + 1}R"
          # Unknown DSR request
          _ ->
            Logger.warning("Unknown DSR request: #{param}")
            ""
        end

        if response != "" do
          Logger.debug("DSR response: #{inspect(response)}")
          %{emulator | output_buffer: emulator.output_buffer <> response}
        else
          emulator
        end

      # \'q\' - Set cursor style (DECSCUSR, requires space intermediate)
      ?q when intermediates_buffer == " " ->
        param = Parser.get_param(params, 0, 1) # Default to 1 (blinking block)
        Logger.debug("Handling DECSCUSR ( q) with param: #{param}")
        new_style = case param do
          0 -> :blinking_block
          1 -> :blinking_block
          2 -> :steady_block
          3 -> :blinking_underline
          4 -> :steady_underline
          5 -> :blinking_bar
          6 -> :steady_bar
          _ ->
            Logger.warning("Unknown DECSCUSR param: #{param}, defaulting to blinking block")
            :blinking_block # Default to blinking block for unknown params
        end
        %{emulator | cursor_style: new_style}

      # Unhandled CSI
      _ ->
        Logger.warning(
          "Unhandled CSI sequence: params=#{inspect(params_buffer)}, " <>
            "intermediates=#{inspect(intermediates_buffer)}, final=#{<<final_byte>>}"
        )
        emulator
    end
  end

  @doc """
  Executes an OSC (Operating System Command).

  Params: `command_string` (the content between OSC and ST).
  """
  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Logger.debug("Executing OSC command: #{inspect(command_string)}")

    case String.split(command_string, ";", parts: 2) do
      # Ps ; Pt format
      [ps_str, pt] ->
        case Integer.parse(ps_str) do
          {ps_code, ""} ->
            # Dispatch based on Ps parameter code
            case ps_code do
              # OSC 0: Set Icon Name and Window Title
              # OSC 2: Set Window Title
              0 ->
                Logger.debug("OSC 0/2: Set Window Title to '#{pt}'")
                %{emulator | window_title: pt}

              2 ->
                Logger.debug("OSC 0/2: Set Window Title to '#{pt}'")
                %{emulator | window_title: pt}

              # OSC 8: Hyperlink
              # Params: id=<id>;<key>=<value>...
              # URI: target URI
              # Example: OSC 8;id=myLink;key=val;file:///tmp ST
              8 ->
                case String.split(pt, ";", parts: 2) do
                  # We expect params;uri
                  [params_str, uri] ->
                    Logger.debug(
                      "OSC 8: Hyperlink: URI='#{uri}', Params='#{params_str}'"
                    )
                    # TODO: Optionally parse params (e.g., id=...)
                    # For now, just store the URI if needed for rendering later
                    # %{emulator | current_hyperlink_url: uri}
                    emulator # Not storing hyperlink state currently

                  # Handle cases with missing params: OSC 8;;uri ST (common)
                  # Or just uri without params: OSC 8;uri ST (allowed?)
                  # Treat as just URI for now if only one part
                  [uri] ->
                     Logger.debug("OSC 8: Hyperlink: URI='#{uri}', No Params")
                     emulator # Not storing hyperlink state currently

                  # Handle malformed OSC 8
                  _ ->
                    Logger.warning("Malformed OSC 8 sequence: '#{command_string}'")
                    emulator
                end

              # OSC 4: Set/Query Color Palette
              # Format: OSC 4 ; c ; spec ST
              # c = color index (0-255)
              # spec = color specification (e.g., rgb:RR/GG/BB or #RRGGBB)
              # Format: OSC 4 ; c ; ? ST (Query color)
              4 ->
                parse_osc4(emulator, pt)

              # OSC 7: Set/Query Current Working Directory URL
              # Format: OSC 7 ; url ST (url usually file://hostname/path)
              # Format: OSC 7 ; ? ST (Query CWD - not standard?)
              7 ->
                # OSC 7: Current Working Directory
                # Pt format: file://hostname/path or just /path
                uri = pt
                Logger.info("OSC 7: Reported CWD: #{uri}")
                # TODO: Store CWD in state or emit event if needed?
                # For now, just acknowledge by logging.
                emulator

              # OSC 52: Set/Query Clipboard Data (primary/clipboard selections)
              # Format: OSC 52 ; c ; d ST (Set clipboard)
              # c = selection (c=clipboard, p=primary, s=secondary, 0-7=cut buffers)
              # d = base64 encoded data
              # Format: OSC 52 ; c ; ? ST (Query clipboard)
              52 ->
                case String.split(pt, ";", parts: 2) do
                  # Set clipboard: "c;DATA_BASE64"
                  [selection_char, data_base64] when selection_char in ["c", "p"] and data_base64 != "?" ->
                    case Base.decode64(data_base64) do
                      {:ok, data_str} ->
                        Logger.debug("OSC 52: Set Clipboard (#{selection_char}): '#{data_str}'")
                        # Use alias Raxol.System.Clipboard
                        Clipboard.put(data_str)
                        # TODO: Need to decide which selection (p/c) Clipboard.put targets or if it needs options.
                        emulator
                      :error ->
                        Logger.warning("OSC 52: Failed to decode base64 data: '#{data_base64}'")
                        emulator
                    end

                  # Query clipboard: "c;?"
                  [selection_char, "?"] when selection_char in ["c", "p"] ->
                    Logger.debug("OSC 52: Query Clipboard (#{selection_char})")
                    # TODO: Read from appropriate selection (p/c)
                    # Use alias Raxol.System.Clipboard
                    case Clipboard.get() do
                      {:ok, content} ->
                        response_data = Base.encode64(content)
                        response = "\e]52;#{selection_char};#{response_data}\e\\"
                        Logger.debug("OSC 52: Response: #{inspect(response)}")
                        %{emulator | output_buffer: emulator.output_buffer <> response}
                      {:error, reason} ->
                        Logger.warning("OSC 52: Failed to get clipboard: #{inspect(reason)}")
                        emulator
                    end

                  _ ->
                    Logger.warning("Malformed OSC 52 sequence: '#{command_string}'")
                    emulator
                end

              _ ->
                Logger.warning(
                  "Unhandled OSC command code: #{ps_code}, String: '#{command_string}'"
                )
                emulator
            end

          # Failed to parse Ps as integer
          _ ->
            Logger.warning(
              "Invalid OSC command code: '#{ps_str}', String: '#{command_string}'"
            )
            emulator
        end

      # Handle OSC sequences with no parameters (e.g., some color requests)
      # Or potentially malformed sequences
      _ ->
        Logger.warning(
          "Unhandled or malformed OSC sequence format: '#{command_string}'"
        )
        emulator
    end
  end

  @doc """
  Executes a DCS (Device Control String) command.

  Params: `params_buffer`, `intermediates_buffer`, `data_string` (content between DCS and ST).
  """
  @spec execute_dcs_command(Emulator.t(), String.t(), String.t(), non_neg_integer(), String.t()) ::
          Emulator.t()
  def execute_dcs_command(emulator, params_buffer, intermediates_buffer, final_byte, data_string) do
    # Parse parameters (similar to CSI)
    params = Parser.parse_params(params_buffer)

    Logger.debug(
      "Executing DCS command: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}, data_len=#{byte_size(data_string)}"
    )

    # --- Dispatch based on params/intermediates/final byte ---
    # Example: DCS ! | text ST (DECRQSS - Request Status String)
    # Example: DCS $ q Pt ST (DECRQMANSI - Request ANSI mode)
    # Example: DCS + q Pt ST (DECRQXMLSS - Request XML setting)
    # Example: DCS = <num> s (DECSCL - Set Conformance Level) - needs final byte 's'
    # Example: DCS <params> q ST (DECGraphics - Sixel/ReGIS) - needs final byte 'q'

    # TODO: Implement specific DCS handlers based on the sequence identified
    # For now, just log and return the unchanged state.

    case {intermediates_buffer, final_byte} do
      # DECRQSS (Request Status String): DCS ! | Pt ST
      {"!", ?|} -> # Using final byte | as marker
        requested_status = data_string # Assuming data_string contains the requested status identifier
        Logger.debug("DCS DECRQSS: Request status '#{requested_status}'")

        # Query the emulator state and format the response
        case requested_status do
          # SGR - Graphics Rendition Combination
          "m" ->
            # Format: P1$r<Ps>m   (Ps is semicolon-separated SGR codes)
            # Example: SGR state = bold, fg=red -> Ps = "1;31"
            # Correct field name is likely emulator.current_attributes -> NO, use emulator.style
            sgr_params = format_sgr_params(emulator.style)
            response_payload = "#{sgr_params}m"
            send_dcs_response(emulator, "1", requested_status, response_payload)

          # DECSTBM - Set Top and Bottom Margins
          "r" ->
            # Format: P1$r<Pt>;<Pb>r (Pt=top, Pb=bottom)
            # Use the field directly: emulator.scroll_region
            {top, bottom} = emulator.scroll_region || {0, ScreenBuffer.get_height(Emulator.get_active_buffer(emulator)) - 1} # Provide default if nil
            # Convert 0-based internal to 1-based external
            response_payload = "#{top + 1};#{bottom + 1}r"
            send_dcs_response(emulator, "1", requested_status, response_payload)

          # DECSCUSR - Set Cursor Style
          " q" ->
            # Format: P1$r<Ps> q (Ps=cursor style code)
            # Use alias: Manager
            cursor_style_code = Manager.get_style_code(emulator.cursor_style) # Pass cursor_style atom
            response_payload = "#{cursor_style_code} q"
            send_dcs_response(emulator, "1", requested_status, response_payload)

          # TODO: Add more DECRQSS handlers (e.g., DECSLPP, DECSLRM, etc.)
          _ ->
            Logger.warning("DECRQSS: Unsupported status request '#{requested_status}'")
            # Respond with P0$r (invalid/unsupported request)
            send_dcs_response(emulator, "0", requested_status, "")
        end

      # Sixel Graphics: DCS <params> q <data> ST
      # The parser should ideally handle Sixel data streaming separately.
      {_intermediates, ?q} ->
        Logger.debug("DCS Sixel Graphics (Params: #{inspect(params)}, Data Length: #{byte_size(data_string)})")
        # TODO: Pass data_string to the SixelGraphics module/parser state machine
        # This likely involves updating the main Parser state, not direct execution here.
        # Potential call: SixelGraphics.handle_data(emulator.sixel_state, data_string)
        Logger.warning("Sixel DCS handling stubbed in Executor. Data should be handled by Parser/SixelGraphics.")
        emulator

      # Unhandled DCS
      _ ->
        Logger.warning("Unhandled DCS command: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}")
        emulator
    end

    # Logger.warning("Unhandled DCS command.") # Replaced by case statement
    # emulator
  end

  # ============================================================================
  # == Helper Functions
  # ============================================================================

  # --- SGR Processing Helper ---

  # Recursive helper to process SGR parameters
  @spec process_sgr_params(list(integer() | nil), TextFormatting.style_t()) :: TextFormatting.style_t()
  # Base case: Empty list means all params processed, return the final style
  # Reset (0) is handled within the recursive step.
  defp process_sgr_params([], style), do: style

  defp process_sgr_params([param | rest_params], style) do
    # Treat nil parameter as 0 (reset)
    actual_param = param || 0
    # Logger.debug("[process_sgr_params] Processing param: #{inspect(param)} -> #{actual_param}, Style IN: #{inspect(style)}")

    # Use actual_param for the case statement
    next_style =
      case actual_param do
        # --- Basic Attributes & Resets ---
        0 -> TextFormatting.new() # Reset all attributes
        1 -> TextFormatting.apply_attribute(style, :bold) # Bold
        2 -> TextFormatting.apply_attribute(style, :faint) # Faint
        3 -> TextFormatting.apply_attribute(style, :italic)
        4 -> TextFormatting.apply_attribute(style, :underline)
        5 -> TextFormatting.apply_attribute(style, :blink) # Slow blink
        6 -> TextFormatting.apply_attribute(style, :blink) # Fast blink (treat same as slow)
        7 -> TextFormatting.apply_attribute(style, :reverse)
        8 -> TextFormatting.apply_attribute(style, :conceal)
        9 -> TextFormatting.apply_attribute(style, :strikethrough)
        # 10-19 Font selection (ignored for now)
        20 -> TextFormatting.apply_attribute(style, :fraktur)
        21 -> TextFormatting.apply_attribute(style, :double_underline)
        22 -> TextFormatting.apply_attribute(style, :normal_intensity) # Not bold, not faint
        23 -> TextFormatting.apply_attribute(style, :no_italic_fraktur) # Not italic, not fraktur
        # Correctly reset single/double underline
        24 -> TextFormatting.apply_attribute(style, :no_underline)
        25 -> TextFormatting.apply_attribute(style, :no_blink)
        # Add missing reset codes
        27 -> TextFormatting.apply_attribute(style, :no_reverse)
        28 -> TextFormatting.apply_attribute(style, :reveal) # Not concealed
        29 -> TextFormatting.apply_attribute(style, :no_strikethrough)

        # --- Basic Foreground Colors (30-37) & Default (39) ---
        param when param >= 30 and param <= 37 ->
          color = index_to_basic_color(param - 30)
          TextFormatting.set_foreground(style, color)
        39 ->
          TextFormatting.apply_attribute(style, :default_fg)

        # --- Basic Background Colors (40-47) & Default (49) ---
        param when param >= 40 and param <= 47 ->
          color = index_to_basic_color(param - 40)
          TextFormatting.set_background(style, color)
        49 ->
          TextFormatting.apply_attribute(style, :default_bg)

        # --- Bright Foreground Colors (90-97) ---
        # Also apply bold attribute for bright colors
        param when param >= 90 and param <= 97 ->
          color = index_to_basic_color(param - 90)
          style |> TextFormatting.set_foreground(color) |> TextFormatting.apply_attribute(:bold)

        # --- Bright Background Colors (100-107) ---
        param when param >= 100 and param <= 107 ->
          color = index_to_basic_color(param - 100)
          style |> TextFormatting.set_background(color)

        # --- Extended Colors (38, 48) --- Need stateful handling within this function
        # TODO: Re-implement stateful parsing for 38/48 here if needed
        # Currently, this recursive version won't handle multi-param codes like 38;2;r;g;b correctly
        # It will process 38, then try to process 2, then r, etc. individually.

        # Fallback for unknown/ignored SGR codes
        unknown ->
          Logger.debug("Ignoring unknown SGR parameter: #{unknown}")
          style
      end
    # Logger.debug("[process_sgr_params] Style OUT: #{inspect(next_style)}")

    # Recursively process remaining parameters
    process_sgr_params(rest_params, next_style)
  end

  # Helper to map basic color indices (0-7) to atoms
  defp index_to_basic_color(index) do
    [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    |> Enum.at(index)
  end

  # --- OSC 4 Helpers ---

  @spec parse_osc4(Emulator.t(), String.t()) :: Emulator.t()
  defp parse_osc4(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      [c_str, spec_or_query] ->
        case Integer.parse(c_str) do
          {color_index, ""} when color_index >= 0 and color_index <= 255 ->
            handle_osc4_color(emulator, color_index, spec_or_query)
          _ ->
            Logger.warning("OSC 4: Invalid color index '#{c_str}'")
            emulator
        end
      _ ->
        Logger.warning("OSC 4: Malformed parameter string '#{pt}'")
        emulator
    end
  end

  @spec handle_osc4_color(Emulator.t(), integer(), String.t()) :: Emulator.t()
  defp handle_osc4_color(emulator, color_index, "?") do
    # Query color
    Logger.debug("OSC 4: Query color index #{color_index}")
    # TODO: Query default palette if not in dynamic map?
    # For now, default to black if not set.
    {r, g, b} = Map.get(emulator.color_palette, color_index, {0, 0, 0})

    # Format response as rgb:RRRR/GGGG/BBBB (adjust range if needed)
    # Assuming {r,g,b} are 0-255, xterm expects 0-65535, so scale up.
    r_scaled = Integer.to_string(div(r * 65535, 255), 16)
    g_scaled = Integer.to_string(div(g * 65535, 255), 16)
    b_scaled = Integer.to_string(div(b * 65535, 255), 16)
    spec_response = "rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}"

    response_str = "\e]4;#{color_index};#{spec_response}\e\\"
    Logger.debug("OSC 4: Response: #{inspect(response_str)}")
    %{emulator | output_buffer: emulator.output_buffer <> response_str}
  end

  defp handle_osc4_color(emulator, color_index, spec) do
    # Set color
    case parse_color_spec(spec) do
      {:ok, {r, g, b}} ->
        Logger.debug("OSC 4: Set color index #{color_index} to {#{r}, #{g}, #{b}}")
        new_palette = Map.put(emulator.color_palette, color_index, {r, g, b})
        %{emulator | color_palette: new_palette}
      {:error, reason} ->
        Logger.warning("OSC 4: Invalid color spec '#{spec}': #{reason}")
        emulator
    end
  end

  @spec parse_color_spec(String.t()) :: {:ok, {r :: integer, g :: integer, b :: integer}} | {:error, String.t()}
  defp parse_color_spec(spec) do
    cond do
      # rgb:RR/GG/BB (hex, 1-4 digits per component)
      String.starts_with?(spec, "rgb:") ->
        case String.split(String.trim_leading(spec, "rgb:"), "/", parts: 3) do
          [r_hex, g_hex, b_hex] ->
            with {:ok, r} <- parse_hex_component(r_hex),
                 {:ok, g} <- parse_hex_component(g_hex),
                 {:ok, b} <- parse_hex_component(b_hex) do
              {:ok, {r, g, b}}
            else
              _ -> {:error, "invalid rgb: component(s)"}
            end
          _ -> {:error, "invalid rgb: format"}
        end

      # #RRGGBB (hex, 2 digits)
      String.starts_with?(spec, "#") and byte_size(spec) == 7 ->
        r_hex = String.slice(spec, 1..2)
        g_hex = String.slice(spec, 3..4)
        b_hex = String.slice(spec, 5..6)
        with {r, ""} <- Integer.parse(r_hex, 16),
             {g, ""} <- Integer.parse(g_hex, 16),
             {b, ""} <- Integer.parse(b_hex, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RRGGBB hex value(s)"}
        end

      # #RGB (hex, 1 digit - scale R*17, G*17, B*17)
      String.starts_with?(spec, "#") and byte_size(spec) == 4 ->
        r1 = String.slice(spec, 1..1)
        g1 = String.slice(spec, 2..2)
        b1 = String.slice(spec, 3..3)
        with {r, ""} <- Integer.parse(r1 <> r1, 16),
             {g, ""} <- Integer.parse(g1 <> g1, 16),
             {b, ""} <- Integer.parse(b1 <> b1, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RGB hex value(s)"}
        end

      true ->
        {:error, "unsupported format"}
    end
  end

  # Parses hex color component (1-4 digits), scales to 0-255
  @spec parse_hex_component(String.t()) :: {:ok, integer()} | :error
  defp parse_hex_component(hex_str) do
    len = byte_size(hex_str)
    if len >= 1 and len <= 4 do
      case Integer.parse(hex_str, 16) do
        {val, ""} ->
          # Scale to 0-255. Max value is 0xFFFF (65535).
          scaled_val = round(val * 255 / 65535)
          # Alternative: simple bit shift approximation?
          # scaled_val = val >>> (len * 4 - 8) # if len > 2 ?
          {:ok, max(0, min(255, scaled_val))}
        _ -> :error
      end
    else
      :error
    end
  end

  # --- DCS Response Helper ---

  defp send_dcs_response(emulator, validity, _requested_status, response_payload) do
    # Format: DCS <validity> ! | <response_payload> ST
    # Note: The original request (e.g., "m") is NOT part of the standard response payload format P...$r...
    # The payload itself contains the terminating character (m, r, q, etc.)
    response_str = "\\eP#{validity}!|#{response_payload}\\e\\\\"
    Logger.debug("Sending DCS Response: #{inspect(response_str)}")
    %{emulator | output_buffer: emulator.output_buffer <> response_str}
  end

  # --- SGR Formatting Helper for DECRQSS ---
  defp format_sgr_params(attrs) do
    # Reconstruct SGR parameters from current attributes map
    # Note: Order might matter for some terminals. Reset (0) should be handled.
    # This is a simplified example.
    params = []
    params = if attrs.bold, do: [1 | params], else: params
    params = if attrs.italic, do: [3 | params], else: params
    params = if attrs.underline, do: [4 | params], else: params
    params = if attrs.inverse, do: [7 | params], else: params
    # Add foreground color
    params = case attrs.fg do
      {:ansi, n} when n >= 0 and n <= 7 -> [30 + n | params]
      {:ansi, n} when n >= 8 and n <= 15 -> [90 + (n - 8) | params]
      {:color_256, n} -> [38, 5, n | params]
      {:rgb, r, g, b} -> [38, 2, r, g, b | params]
      :default -> params
    end
    # Add background color
    params = case attrs.bg do
      {:ansi, n} when n >= 0 and n <= 7 -> [40 + n | params]
      {:ansi, n} when n >= 8 and n <= 15 -> [100 + (n - 8) | params]
      {:color_256, n} -> [48, 5, n | params]
      {:rgb, r, g, b} -> [48, 2, r, g, b | params]
      :default -> params
    end

    # Handle reset case (if no attributes set, send 0)
    if params == [] do
      "0"
    else
      Enum.reverse(params) |> Enum.map_join(&Integer.to_string/1, ";")
    end
  end
end
