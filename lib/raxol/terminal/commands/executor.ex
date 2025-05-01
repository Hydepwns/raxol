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
        Logger.debug("Handling SGR (m) with params: #{inspect(params)}")
        # Use Enum.reduce to apply parameters sequentially
        new_style =
          Enum.reduce(params, emulator.style, fn param, current_style ->
            # Map SGR code to attribute atom or color application
            case param do
              # --- Basic Attributes ---
              0 -> TextFormatting.new() # Reset all attributes
              1 -> TextFormatting.apply_attribute(current_style, :bold)
              2 -> TextFormatting.apply_attribute(current_style, :faint)
              3 -> TextFormatting.apply_attribute(current_style, :italic)
              4 -> TextFormatting.apply_attribute(current_style, :underline)
              5 -> TextFormatting.apply_attribute(current_style, :blink) # Slow blink
              # 6 -> Fast blink (often same as slow)
              7 -> TextFormatting.apply_attribute(current_style, :reverse)
              8 -> TextFormatting.apply_attribute(current_style, :conceal)
              9 -> TextFormatting.apply_attribute(current_style, :strikethrough)
              # 10-19 Font selection (ignored for now)
              20 -> TextFormatting.apply_attribute(current_style, :fraktur) # ADDED Fraktur
              21 -> TextFormatting.apply_attribute(current_style, :double_underline)
              22 -> TextFormatting.apply_attribute(current_style, :normal_intensity)
              23 -> TextFormatting.apply_attribute(current_style, :no_italic_fraktur)
              # MODIFIED: Ensure 24 resets both single and double underline
              24 -> current_style |> TextFormatting.apply_attribute(:no_underline) |> Map.put(:double_underline, false)
              25 -> TextFormatting.apply_attribute(current_style, :no_blink)
              27 -> TextFormatting.apply_attribute(current_style, :no_reverse)
              28 -> TextFormatting.apply_attribute(current_style, :reveal)
              29 -> TextFormatting.apply_attribute(current_style, :no_strikethrough)

              # --- Basic Foreground Colors (30-37) ---
              30 -> TextFormatting.set_foreground(current_style, :black)
              31 -> TextFormatting.set_foreground(current_style, :red)
              32 -> TextFormatting.set_foreground(current_style, :green)
              33 -> TextFormatting.set_foreground(current_style, :yellow)
              34 -> TextFormatting.set_foreground(current_style, :blue)
              35 -> TextFormatting.set_foreground(current_style, :magenta)
              36 -> TextFormatting.set_foreground(current_style, :cyan)
              37 -> TextFormatting.set_foreground(current_style, :white)
              # 38 -> Extended colors (TODO)
              39 -> TextFormatting.apply_attribute(current_style, :default_fg)

              # --- Basic Background Colors (40-47) ---
              40 -> TextFormatting.set_background(current_style, :black)
              41 -> TextFormatting.set_background(current_style, :red)
              42 -> TextFormatting.set_background(current_style, :green)
              43 -> TextFormatting.set_background(current_style, :yellow)
              44 -> TextFormatting.set_background(current_style, :blue)
              45 -> TextFormatting.set_background(current_style, :magenta)
              46 -> TextFormatting.set_background(current_style, :cyan)
              47 -> TextFormatting.set_background(current_style, :white)
              # 48 -> Extended background colors (TODO)
              49 -> TextFormatting.apply_attribute(current_style, :default_bg)

              # --- Bright Foreground Colors (90-97) ---
              # TODO: Revisit if distinct bright colors are needed internally. Mapping to base colors for now.
              90 -> TextFormatting.set_foreground(current_style, :black) # Bright Black -> Black
              91 -> TextFormatting.set_foreground(current_style, :red) # Bright Red -> Red
              92 -> TextFormatting.set_foreground(current_style, :green) # Bright Green -> Green
              93 -> TextFormatting.set_foreground(current_style, :yellow) # Bright Yellow -> Yellow
              94 -> TextFormatting.set_foreground(current_style, :blue) # Bright Blue -> Blue
              95 -> TextFormatting.set_foreground(current_style, :magenta) # Bright Magenta -> Magenta
              96 -> TextFormatting.set_foreground(current_style, :cyan) # Bright Cyan -> Cyan
              97 -> TextFormatting.set_foreground(current_style, :white) # Bright White -> White

              # --- Bright Background Colors (100-107) ---
              100 -> TextFormatting.set_background(current_style, :black) # Bright Black -> Black
              101 -> TextFormatting.set_background(current_style, :red) # Bright Red -> Red
              102 -> TextFormatting.set_background(current_style, :green) # Bright Green -> Green
              103 -> TextFormatting.set_background(current_style, :yellow) # Bright Yellow -> Yellow
              104 -> TextFormatting.set_background(current_style, :blue) # Bright Blue -> Blue
              105 -> TextFormatting.set_background(current_style, :magenta) # Bright Magenta -> Magenta
              106 -> TextFormatting.set_background(current_style, :cyan) # Bright Cyan -> Cyan
              107 -> TextFormatting.set_background(current_style, :white) # Bright White -> White

              # Ignore other parameters for now
              _ -> current_style
            end
          end)
        # Update emulator state with the new style
        %{emulator | style: new_style}

      # 'H' - Cursor Position (CUP)
      ?H ->
        # Params: [row, col], default to 1,1
        # Use 1-based indices for get_param
        row = Parser.get_param(params, 1, 1)
        col = Parser.get_param(params, 2, 1)
        Logger.debug("Handling CUP (H) to row: #{row}, col: #{col}")
        # Convert to 0-based index for cursor manager
        new_cursor = CursorManager.move_to(emulator.cursor, col - 1, row - 1)
        %{emulator | cursor: new_cursor}

      # 'r' - Set Top and Bottom Margins (DECSTBM)
      ?r ->
        # Params: [top, bottom], default to 1, screen_height
        # Parameters are 1-based, get_param expects 1-based index
        top = Parser.get_param(params, 1, 1)
        # Get height from active buffer
        height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
        bottom = Parser.get_param(params, 2, height)

        # Validate: top < bottom and within screen bounds
        if top >= 1 and top < bottom and bottom <= height do
          Logger.debug("Handling DECSTBM (r) to top: #{top}, bottom: #{bottom}")
          # Store 0-based region
          %{emulator | scroll_region: {top - 1, bottom - 1}}
        else
          Logger.warning("Invalid DECSTBM params: top=#{top}, bottom=#{bottom}, height=#{height}")
          emulator
        end

      # 'h' - Set Mode (SM)
      # 'l' - Reset Mode (RM)
      final_byte when final_byte in [?h, ?l] ->
        action = if final_byte == ?h, do: :set, else: :reset
        # Check for DEC Private Mode marker ('?')
        if intermediates_buffer == "?" do
          Logger.debug("Handling DEC Mode #{action} (?#{inspect(params)}) ")
          # Delegate to ScreenModes module
          ScreenModes.handle_dec_private_mode(emulator, params, action)
        else
          Logger.debug("Handling ANSI Mode #{action} (#{inspect(params)}) ")
          # Delegate to ScreenModes module
          ScreenModes.handle_ansi_mode(emulator, params, action)
        end

      # \'J\' - Erase in Display (ED)
      ?J ->
        param = Parser.get_param(params, 0, 0)
        Logger.debug("Handling ED (J) with param: #{param}")
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
        Logger.debug("Handling EL (K) with param: #{param}")
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
        Logger.debug("Handling CUU (A) by #{count}")
        new_cursor = CursorManager.move_up(emulator.cursor, count)
        %{emulator | cursor: new_cursor}

      # \'B\' - Cursor Down (CUD)
      ?B ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CUD (B) by #{count}")
        # Need terminal height to constrain movement
        height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
        new_cursor = CursorManager.move_down(emulator.cursor, count, height)
        %{emulator | cursor: new_cursor}

      # \'C\' - Cursor Forward (CUF)
      ?C ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CUF (C) by #{count}")
        # Need terminal width to constrain movement
        width = ScreenBuffer.get_width(Emulator.get_active_buffer(emulator))
        new_cursor = CursorManager.move_right(emulator.cursor, count, width)
        %{emulator | cursor: new_cursor}

      # \'D\' - Cursor Backward (CUB)
      ?D ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CUB (D) by #{count}")
        new_cursor = CursorManager.move_left(emulator.cursor, count)
        %{emulator | cursor: new_cursor}

      # \'E\' - Cursor Next Line (CNL)
      ?E ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CNL (E) by #{count}")
        # Move down N lines to column 0
        height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
        new_cursor = CursorManager.move_down(emulator.cursor, count, height)
        new_cursor = %{new_cursor | col: 0}
        %{emulator | cursor: new_cursor}

      # \'F\' - Cursor Previous Line (CPL)
      ?F ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CPL (F) by #{count}")
        # Move up N lines to column 0
        new_cursor = CursorManager.move_up(emulator.cursor, count)
        new_cursor = %{new_cursor | col: 0}
        %{emulator | cursor: new_cursor}

      # \'G\' - Cursor Horizontal Absolute (CHA)
      ?G ->
        col = Parser.get_param(params, 0, 1)
        Logger.debug("Handling CHA (G) to col #{col}")
        # Move to column N (1-based) on the current row
        width = ScreenBuffer.get_width(Emulator.get_active_buffer(emulator))
        new_cursor = CursorManager.move_to_col(emulator.cursor, col - 1, width)
        %{emulator | cursor: new_cursor}

      # \'d\' - Vertical Line Position Absolute (VPA)
      ?d ->
        row = Parser.get_param(params, 0, 1)
        Logger.debug("Handling VPA (d) to row #{row}")
        # Move to row N (1-based) on the current column
        height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
        new_cursor = CursorManager.move_to_row(emulator.cursor, row - 1, height)
        %{emulator | cursor: new_cursor}

      # \'L\' - Insert Lines (IL)
      ?L ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling IL (L) with count #{count}")
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.insert_lines(active_buffer, emulator.cursor.row, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'M\' - Delete Lines (DL)
      ?M ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling DL (M) with count #{count}")
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.delete_lines(active_buffer, emulator.cursor.row, count, emulator.scroll_region)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'P\' - Delete Characters (DCH)
      ?P ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling DCH (P) with count #{count}")
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.delete_characters(active_buffer, emulator.cursor.row, emulator.cursor.col, count)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'@\' - Insert Characters (ICH)
      ?@ ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling ICH (@) with count #{count}")
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.insert_characters(active_buffer, emulator.cursor.row, emulator.cursor.col, count)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'S\' - Scroll Up (SU)
      ?S ->
        count = Parser.get_param(params, 0, 1)
        Logger.debug("Handling SU (S) by #{count}")
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
        Logger.debug("Handling SD (T) by #{count}")
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
        Logger.debug("Handling ECH (X) by #{count}")
        active_buffer = Emulator.get_active_buffer(emulator)
        new_buffer = ScreenBuffer.erase_characters(active_buffer, emulator.cursor.row, emulator.cursor.col, count)
        if emulator.active_buffer_type == :main do
          %{emulator | main_screen_buffer: new_buffer}
        else
          %{emulator | alternate_screen_buffer: new_buffer}
        end

      # \'c\' - Send Device Attributes (Primary DA)
      ?c ->
        param = Parser.get_param(params, 0, 0)
        Logger.debug("Handling DA (c) with param: #{param}")
        # Respond only to primary DA request (param 0)
        if param == 0 do
          # Basic VT102 response: "I am a VT102"
          response = "\e[?6c"
          Logger.debug("DA response: #{inspect(response)}")
          %{emulator | output_buffer: emulator.output_buffer <> response}
        else
          Logger.warning("Ignoring non-primary DA request (param: #{param})")
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
            # Get 1-based row/col
            {col, row} = CursorManager.get_position(emulator.cursor)
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

      # TODO: Add other CSI commands
      _ ->
        # Handle cases where 'q' is received without the space intermediate if needed
        # Or just fall through to the general unhandled case
        Logger.debug(
          "[Commands.Executor] Unhandled CSI command: " <>
            "params=#{inspect(params_buffer)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}"
        )
        # Return unchanged emulator for unhandled commands
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

              # --- Add other OSC handlers here ---
              # OSC 4 (Colors), OSC 7 (CWD), OSC 52 (Clipboard) etc.

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

    Logger.warning("Unhandled DCS command.")
    emulator
  end
end
