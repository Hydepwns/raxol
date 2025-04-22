defmodule Raxol.Terminal.CommandExecutor do
  @moduledoc """
  Handles the execution of parsed CSI, OSC, and DCS sequences.
  Receives emulator state and sequence details, returns updated emulator state.
  """

  # For Emulator.t type spec
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Cursor.Movement
  alias Raxol.Terminal.Cursor.Style
  alias Raxol.Terminal.ScreenModes
  alias Raxol.Terminal.TextFormatting
  # Needed for CAN/SUB constants
  # alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.CharacterSets

  require Logger
  require Raxol.Terminal.TextFormatting
  require Raxol.Terminal.ScreenModes
  require Raxol.Terminal.CharacterSets

  # --- Sequence Executors ---

  # Note: All functions receive the full Emulator.t state as the first argument

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
    # Parse the raw param string buffer into a list of integers/nil
    params = parse_params(params_buffer)
    # Use intermediates_buffer directly
    intermediates = intermediates_buffer

    # Assign the result of the case statement to new_emulator
    new_emulator =
      case {final_byte, intermediates} do
        # SGR - Select Graphic Rendition
        # Corrected pattern
        {?m, ""} ->
          # Params can be empty (CSI m), which defaults to [0]
          sgr_params = if params == [], do: [0], else: params
          handle_sgr(emulator, sgr_params)

        # --- Scrolling ---
        # SU - Scroll Up
        # Corrected pattern
        {?S, ""} ->
          # Default to 1
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)

          new_active_buffer =
            ScreenBuffer.scroll_up(active_buffer, count)

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # SD - Scroll Down
        # Corrected pattern
        {?T, ""} ->
          # Default to 1
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)

          new_active_buffer =
            ScreenBuffer.scroll_down(
              active_buffer,
              count
            )

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # --- Scrolling Region ---
        # DECSTBM - Set Top and Bottom Margins
        # Corrected pattern
        {?r, ""} ->
          # IO.inspect({:inside_csi_r_start, params, emulator.screen_buffer, emulator.cursor}, label: "DEBUG_R") # DEBUG ADD
          active_buffer = Emulator.get_active_buffer(emulator)
          height = ScreenBuffer.get_height(active_buffer)

          # IO.inspect({:inside_csi_r_after_height, height}, label: "DEBUG_R") # DEBUG ADD
          [top, bottom] =
            case params do
              # Handle CSI r -> default (1, height)
              [] -> [1, height]
              # Should not happen with map defaults, but safe
              [nil] -> [1, height]
              [t] -> [t, height]
              [nil, b] -> [1, b]
              # Handle CSI top ; bottom r
              [t, b] -> [t, b]
              # Handle more than 2 params - take the first two
              [t, b | _] -> [t, b]
            end

          # Ensure top < bottom and within screen bounds (1 to height)
          # Clamp values and ensure top < bottom.
          # Terminals often reset region if top >= bottom.
          clamped_top = max(1, min(top, height))
          clamped_bottom = max(1, min(bottom, height))

          if clamped_top >= clamped_bottom do
            Logger.debug(
              "DECSTBM: Invalid region (#{top}, #{bottom}), resetting to full screen."
            )

            # Reset scroll region and move cursor home
            # IO.inspect({:inside_csi_r_invalid_before_move, emulator.cursor}, label: "DEBUG_R") # DEBUG ADD
            cursor_after_move = Manager.move_to(emulator.cursor, 1, 1)

            # IO.inspect({:inside_csi_r_invalid_after_move, cursor_after_move}, label: "DEBUG_R") # DEBUG ADD
            %{emulator | scroll_region: nil, cursor: cursor_after_move}
          else
            # Store region as 0-based {top, bottom} (inclusive)
            Logger.debug(
              "DECSTBM: Setting scroll region to {#{clamped_top - 1}, #{clamped_bottom - 1}} (0-based)"
            )

            # Set the scroll region but leave the cursor position unchanged.
            %{
              emulator
              | scroll_region: {clamped_top - 1, clamped_bottom - 1}
            }
          end

        # --- DEC Private Mode Set/Reset ---
        # DECSET - Set Mode
        # Corrected pattern
        {?h, "?"} ->
          handle_dec_private_mode(emulator, params, :set)

        # Corrected pattern
        {?h, ""} ->
          handle_ansi_mode(emulator, params, :set)

        # DECRST - Reset Mode
        # Corrected pattern
        {?l, "?"} ->
          handle_dec_private_mode(emulator, params, :reset)

        # Corrected pattern
        {?l, ""} ->
          handle_ansi_mode(emulator, params, :reset)

        # --- Cursor Movement ---
        # CUU - Cursor Up
        {?A, ""} ->
          count = List.first(params || [1])

          %{
            emulator
            | cursor: Movement.move_up(emulator.cursor, count)
          }

        # CUD - Cursor Down
        {?B, ""} ->
          count = List.first(params || [1])

          %{
            emulator
            | cursor: Movement.move_down(emulator.cursor, count)
          }

        # CUF - Cursor Forward
        {?C, ""} ->
          count = List.first(params || [1])

          %{
            emulator
            | cursor: Movement.move_right(emulator.cursor, count)
          }

        # CUB - Cursor Back
        {?D, ""} ->
          count = List.first(params || [1])

          %{
            emulator
            | cursor: Movement.move_left(emulator.cursor, count)
          }

        # CUP - Cursor Position
        {?H, ""} ->
          [row, col] =
            case params do
              [] -> [1, 1]
              [r] -> [r, 1]
              [r, c | _] -> [r, c]
            end

          # Get dimensions from the active buffer
          active_buffer = Emulator.get_active_buffer(emulator)
          height = ScreenBuffer.get_height(active_buffer)
          width = ScreenBuffer.get_width(active_buffer)
          zero_based_row = max(0, min(height - 1, (row || 1) - 1))
          zero_based_col = max(0, min(width - 1, (col || 1) - 1))

          %{
            emulator
            | cursor:
                Manager.move_to(emulator.cursor, zero_based_col, zero_based_row)
          }

        # ED - Erase Display
        # Corrected pattern
        {?J, ""} ->
          handle_ed(emulator, List.first(params || [0]))

        # EL - Erase Line
        # Corrected pattern
        {?K, ""} ->
          handle_el(emulator, List.first(params || [0]))

        # ICH - Insert Character
        # CSI n @
        {?@, ""} ->
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)
          {x, y} = emulator.cursor.position

          new_active_buffer =
            ScreenBuffer.insert_characters(
              active_buffer,
              {x, y},
              count,
              # Use current style for inserted spaces
              emulator.cursor.style
            )

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # IL - Insert Line
        # CSI n L
        {?L, ""} ->
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)
          {_x, y} = emulator.cursor.position

          new_active_buffer =
            ScreenBuffer.insert_lines(
              active_buffer,
              y,
              count,
              emulator.scroll_region
            )

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # DCH - Delete Character
        # CSI n P
        {?P, ""} ->
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)
          {x, y} = emulator.cursor.position

          new_active_buffer =
            ScreenBuffer.delete_characters(
              active_buffer,
              {x, y},
              count
            )

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # DL - Delete Line
        # CSI n M
        {?M, ""} ->
          count = List.first(params || [1])
          active_buffer = Emulator.get_active_buffer(emulator)
          {_x, y} = emulator.cursor.position

          new_active_buffer =
            ScreenBuffer.delete_lines(
              active_buffer,
              y,
              count,
              emulator.scroll_region
            )

          Emulator.update_active_buffer(emulator, new_active_buffer)

        # --- Terminal Information ---
        # DA - Device Attributes
        # Primary DA: CSI c or CSI 0 c
        {?c, ""} ->
          # Parameter 0 or no parameter requests Primary DA
          if params == [] or params == [0] do
            # Respond with basic VT102 attributes (e.g., VT100 with Advanced Video Option)
            # Response: ESC [ ? 6 c
            response = "\e[?6c"
            Logger.debug("DA Primary received, responding with: #{response}")
            %{emulator | output_buffer: emulator.output_buffer <> response}
          else
            Logger.warning(
              "Unhandled Primary DA parameters: #{inspect(params)}"
            )

            emulator
          end

        # Secondary DA: CSI > c or CSI > 0 c
        {?c, ">"} ->
          # Parameter 0 or no parameter requests Secondary DA
          if params == [] or params == [0] do
            # Respond with a basic xterm-like response (Type 0, Version 0, Patch 0)
            # Response: ESC [ > 0 ; 0 ; 0 c
            response = "\e[>0;0;0c"
            Logger.debug("DA Secondary received, responding with: #{response}")
            %{emulator | output_buffer: emulator.output_buffer <> response}
          else
            Logger.warning(
              "Unhandled Secondary DA parameters: #{inspect(params)}"
            )

            emulator
          end

        # DSR - Device Status Report
        {?n, ""} ->
          case params do
            # CSI 5 n - Status Report Request
            [5] ->
              # Respond with "OK" (no malfunctions)
              response = "\e[0n"
              Logger.debug("DSR 5n received, responding with: #{response}")
              %{emulator | output_buffer: emulator.output_buffer <> response}

            # CSI 6 n - Report Cursor Position (CPR)
            [6] ->
              # Get 0-based cursor position
              {x, y} = emulator.cursor.position
              # Convert to 1-based for report
              row = y + 1
              col = x + 1
              # Format response: ESC [ <row> ; <col> R
              response = "\e[#{row};#{col}R"
              Logger.debug("DSR 6n received, responding with: #{response}")
              %{emulator | output_buffer: emulator.output_buffer <> response}

            # Others (e.g., CSI ? 15 n - Printer status report)
            _ ->
              Logger.warning("Unhandled DSR parameter(s): #{inspect(params)}")
              emulator
          end

        # DECSCUSR - Set Cursor Style
        # CSI Ps SP q
        # Note the space intermediate
        {?q, " "} ->
          # Default to 1 if no param
          handle_decscusr(emulator, List.first(params || [1]))

        # --- Character Set Selection (SCS) ---
        # These are handled by the Parser state machine, not CSI executor.
        # GZD4 (Select G0 Character Set)
        # Default to ASCII 'B'
        # {?(, ""} ->  # REMOVED
        #  CharacterSets.designate_g0(emulator, List.first(params || [?B])) # REMOVED
        #
        # G1D4 (Select G1 Character Set)
        # {?), ""} -> # REMOVED
        #  CharacterSets.designate_g1(emulator, List.first(params || [?B])) # REMOVED
        #
        # G2D4 (Select G2 Character Set)
        # {?*, ""} -> # REMOVED
        #  CharacterSets.designate_g2(emulator, List.first(params || [?B])) # REMOVED
        #
        # G3D4 (Select G3 Character Set)
        # {?+, ""} -> # REMOVED
        #  CharacterSets.designate_g3(emulator, List.first(params || [?B])) # REMOVED

        # --- Other ---
        # Add more CSI command handlers here...

        _ ->
          Logger.warning(
            "Unhandled CSI sequence: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}'"
          )

          # Return unchanged state for unhandled sequences
          emulator
      end

    # Return the result
    new_emulator
  end

  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Logger.debug("Executing OSC: String='#{command_string}'")

    # Parse the command string: Ps ; Pt ST
    # Ps is the command code (0, 2, 8, etc.)
    case String.split(command_string, ";", parts: 2) do
      [ps_str, pt] when ps_str != "" ->
        case Integer.parse(ps_str) do
          {ps_code, ""} ->
            # Dispatch based on the numeric code
            case ps_code do
              # Set icon name and window title
              0 ->
                Logger.info("OSC 0: Set icon/window title to: '#{pt}'")
                %{emulator | window_title: pt, icon_name: pt}

              # Set icon name
              1 ->
                Logger.info("OSC 1: Set icon name to: '#{pt}'")
                %{emulator | icon_name: pt}

              # Set window title
              2 ->
                Logger.info("OSC 2: Set window title to: '#{pt}'")
                %{emulator | window_title: pt}

              # Hyperlink: OSC 8 ; params ; uri ST
              8 ->
                case String.split(pt, ";", parts: 2) do
                  [params, uri] ->
                    Logger.info(
                      "OSC 8: Hyperlink: URI='#{uri}', Params='#{params}'"
                    )

                    # TODO: Optionally parse params (e.g., id=...)
                    %{emulator | current_hyperlink_url: uri}

                  # Handle cases with missing params: OSC 8 ; ; uri ST (common)
                  ["", uri] ->
                    Logger.info("OSC 8: Hyperlink: URI='#{uri}', Params=EMPTY")
                    %{emulator | current_hyperlink_url: uri}

                  # Handle malformed OSC 8
                  _ ->
                    Logger.warning(
                      "Malformed OSC 8 sequence: '#{command_string}'"
                    )

                    emulator
                end

              # Add other OSC commands here (e.g., colors, notifications)
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

  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte,
        payload
      ) do
    # Parse the raw param string buffer
    params = parse_params(params_buffer)
    # Use intermediates_buffer directly
    intermediates = intermediates_buffer

    Logger.debug(
      "Executing DCS: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}', Payload(len=#{String.length(payload)})"
    )

    # Dispatch based on params/intermediates/final_byte
    # Match on final_byte first
    case {final_byte, intermediates} do
      # Sixel Graphics (DECGRA) - ESC P P1 ; P2 ; P3 q <payload> ESC \
      # P1 = pixel aspect ratio (ignored), P2 = background color mode (ignored), P3 = horizontal grid size (ignored)
      {?q, _intermediates} ->
        handle_sixel_graphics(emulator, payload)

      # TODO: Add other DCS handlers (e.g., User-Defined Keys - DECDLD, Terminal Reports - DECRQSS)

      _ ->
        Logger.warning(
          "Unhandled DCS sequence: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}'"
        )

        emulator
    end
  end

  # --- Command Handlers ---

  # Sixel Graphics Handler
  @spec handle_sixel_graphics(Emulator.t(), String.t()) :: Emulator.t()
  def handle_sixel_graphics(emulator, payload) do
    # TODO: Implement Sixel parsing and rendering to screen buffer.
    # This likely requires an external library (e.g., NIF bindings for libsixel) or a pure Elixir implementation.
    Logger.warning(
      "Sixel graphics received (payload length: #{String.length(payload)}), but Sixel decoding is NOT IMPLEMENTED."
    )

    # TODO: Implement Sixel parsing and rendering to screen buffer
    # Could involve calling an external library or a dedicated Elixir parser.
    # Return unchanged state for now
    emulator
  end

  # ANSI Mode Handler (SM/RM)
  @spec handle_ansi_mode(Emulator.t(), list(integer() | nil), :set | :reset) ::
          Emulator.t()
  def handle_ansi_mode(emulator, params_list, action) do
    # If params_list is empty, behavior is undefined/ignored by most terminals
    Enum.reduce(params_list, emulator, fn param_code, acc_emulator ->
      # Ignore nil parameters in the list (e.g., from CSI ; h)
      if is_nil(param_code) do
        acc_emulator
      else
        bool_value = action == :set

        case param_code do
          # Insert Mode (IRM)
          4 ->
            Logger.debug(
              "ANSI Mode #{action}: 4 (Insert Mode IRM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :irm_insert,
                    bool_value
                  )
            }

          # Linefeed/Newline Mode (LNM)
          20 ->
            Logger.debug(
              "ANSI Mode #{action}: 20 (Linefeed/Newline LNM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :lnm_linefeed_newline,
                    bool_value
                  )
            }

          # Add other ANSI standard modes (e.g., Keyboard Action Mode - KAM)
          _ ->
            Logger.warning("Unhandled ANSI mode #{action} code: #{param_code}")
            acc_emulator
        end
      end
    end)
  end

  # DEC Private Mode Handler (DECSET/DECRST)
  @spec handle_dec_private_mode(
          Emulator.t(),
          list(integer() | nil),
          :set | :reset
        ) :: Emulator.t()
  def handle_dec_private_mode(emulator, params_list, action) do
    # If params_list is empty, behavior is undefined/ignored by most terminals
    Enum.reduce(params_list, emulator, fn param_code, acc_emulator ->
      # Ignore nil parameters in the list (e.g., from CSI ? ; h)
      if is_nil(param_code) do
        acc_emulator
      else
        bool_value = action == :set

        case param_code do
          # Cursor Keys Mode (DECCKM)
          1 ->
            Logger.debug(
              "DEC Mode #{action}: 1 (Cursor Keys DECCKM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :decckm_cursor_keys,
                    bool_value
                  )
            }

          # Mode 4 (Insert/Replace Mode - DECSM/DECRM) is handled by ANSI mode 4 (IRM)
          # DEC mode 4 is often related to smooth scrolling, but we map CSI 4 h/l to IRM.
          # Screen Mode (DECSCNM) - Reverse video
          5 ->
            Logger.debug(
              "DEC Mode #{action}: 5 (Screen Mode DECSCNM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :decscnm_screen,
                    bool_value
                  )
            }

          # Origin Mode (DECOM)
          6 ->
            Logger.debug(
              "DEC Mode #{action}: 6 (Origin Mode DECOM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :decom_origin,
                    bool_value
                  )
            }

          # Autowrap Mode (DECAWM)
          7 ->
            Logger.debug(
              "DEC Mode #{action}: 7 (Autowrap DECAWM) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :decawm_autowrap,
                    bool_value
                  )
            }

          # 25 -> Cursor Visible (DECTCEM)
          25 ->
            Logger.debug(
              "DEC Mode #{action}: 25 (Cursor Visible DECTCEM) -> #{bool_value}"
            )

            # Calculate new_cursor first
            new_cursor =
              if bool_value do
                Style.show(acc_emulator.cursor)
              else
                Style.hide(acc_emulator.cursor)
              end

            # Return the updated emulator
            %{acc_emulator | cursor: new_cursor}

          # 1000 -> Send Mouse X & Y on button press.
          # 1002 -> Use Cell Motion Mouse Tracking.
          # 1003 -> Use All Motion Mouse Tracking.
          # 1004 -> Send FocusIn/FocusOut events.
          # 1005 -> UTF8 Mouse Mode.
          # 1006 -> SGR Mouse Mode.
          # 1007 -> Alternate Scroll Mode (seems less common).
          # 1015 -> urxvt Mouse Mode.
          # 1016 -> SGR PixelMode Mouse.
          # Mouse tracking modes
          1000..1016 ->
            Logger.debug(
              "DEC Mode #{action}: #{param_code} (Mouse Tracking) -> #{bool_value}"
            )

            # Store the state, actual handling might be elsewhere (e.g., UI layer)
            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :"mouse_#{param_code}",
                    bool_value
                  )
            }

          # Use Alternate Screen Buffer
          1047 ->
            Logger.debug(
              "DEC Mode #{action}: 1047 (Alternate Screen Buffer) -> #{bool_value}"
            )

            # Set mode (h)
            # Reset mode (l)
            if bool_value do
              # Switch to alternate buffer and clear it
              emulator_switched = %{
                acc_emulator
                | active_buffer_type: :alternate
              }

              alt_buffer = Emulator.get_active_buffer(emulator_switched)
              cleared_alt_buffer = ScreenBuffer.clear(alt_buffer)

              Emulator.update_active_buffer(
                emulator_switched,
                cleared_alt_buffer
              )
            else
              # Switch back to main buffer
              %{acc_emulator | active_buffer_type: :main}
            end

          # Save cursor as in DECSC
          1048 ->
            Logger.debug(
              "DEC Mode #{action}: 1048 (Save/Restore Cursor) -> #{bool_value}"
            )

            # Set mode (h) - Save
            # Reset mode (l) - Restore
            if bool_value do
              Emulator.handle_decsc(acc_emulator)
            else
              Emulator.handle_decrc(acc_emulator)
            end

          # Save cursor as in DECSC and use Alternate Screen Buffer
          1049 ->
            Logger.debug(
              "DEC Mode #{action}: 1049 (Alt Screen + Save/Restore Cursor) -> #{bool_value}"
            )

            # Set mode (h) - Save, Switch, Clear
            # Reset mode (l) - Switch, Restore
            if bool_value do
              # 1. Save state
              emulator_saved = Emulator.handle_decsc(acc_emulator)
              # 2. Switch to alternate buffer
              emulator_switched = %{
                emulator_saved
                | active_buffer_type: :alternate
              }

              # 3. Clear alternate buffer
              alt_buffer = Emulator.get_active_buffer(emulator_switched)
              cleared_alt_buffer = ScreenBuffer.clear(alt_buffer)

              Emulator.update_active_buffer(
                emulator_switched,
                cleared_alt_buffer
              )
            else
              # 1. Switch back to main buffer
              emulator_switched = %{acc_emulator | active_buffer_type: :main}
              # 2. Restore state
              Emulator.handle_decrc(emulator_switched)
            end

          # Set bracketed paste mode
          2004 ->
            Logger.debug(
              "DEC Mode #{action}: 2004 (Bracketed Paste) -> #{bool_value}"
            )

            %{
              acc_emulator
              | mode_state:
                  ScreenModes.switch_mode(
                    acc_emulator.mode_state,
                    :bracketed_paste,
                    bool_value
                  )
            }

          # Add other DEC private modes...
          _ ->
            Logger.warning(
              "Unhandled DEC private mode #{action} code: ?#{param_code}"
            )

            acc_emulator
        end
      end
    end)
  end

  # SGR - Select Graphic Rendition Handler
  @spec handle_sgr(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_sgr(emulator, params) do
    # Process parameters sequentially, updating the style
    Enum.reduce(params, emulator, fn param, acc_emulator ->
      current_style = acc_emulator.style

      case param do
        # Reset / Normal
        0 ->
          %{acc_emulator | style: TextFormatting.new()}

        # Bold or increased intensity
        1 ->
          %{acc_emulator | style: %{current_style | bold: true}}

        # Faint (decreased intensity)
        2 ->
          # Assuming TextFormatting map has :faint field (or treat as non-bold)
          # %{acc_emulator | style: %{current_style | faint: true}}
          # Treat as non-bold for now
          %{acc_emulator | style: %{current_style | bold: false}}

        # Italic
        3 ->
          %{acc_emulator | style: %{current_style | italic: true}}

        # Underline - Single
        4 ->
          %{
            acc_emulator
            | style: %{current_style | underline: true, double_underline: false}
          }

        # Blink - Slow
        5 ->
          %{acc_emulator | style: %{current_style | blink: true}}

        # Blink - Rapid (Treat same as slow blink)
        6 ->
          %{acc_emulator | style: %{current_style | blink: true}}

        # Reverse video
        7 ->
          %{acc_emulator | style: %{current_style | reverse: true}}

        # Conceal
        8 ->
          %{acc_emulator | style: %{current_style | conceal: true}}

        # Crossed-out / Strikethrough
        9 ->
          %{acc_emulator | style: %{current_style | strikethrough: true}}

        # Primary font (default)
        10 ->
          acc_emulator

        # 11-19: Alternative fonts
        11..19 ->
          acc_emulator

        # Fraktur (rarely supported, treat as normal)
        20 ->
          acc_emulator

        # Double underline
        21 ->
          %{
            acc_emulator
            | style: %{current_style | underline: false, double_underline: true}
          }

        # Normal intensity (neither bold nor faint)
        22 ->
          %{acc_emulator | style: %{current_style | bold: false, faint: false}}

        # Not italicized, not fraktur
        23 ->
          %{acc_emulator | style: %{current_style | italic: false}}

        # Not underlined (neither single nor double)
        24 ->
          %{
            acc_emulator
            | style: %{
                current_style
                | underline: false,
                  double_underline: false
              }
          }

        # Not blinking
        25 ->
          %{acc_emulator | style: %{current_style | blink: false}}

        # Proportional spacing (rarely used/supported)
        26 ->
          acc_emulator

        # Not reversed
        27 ->
          %{acc_emulator | style: %{current_style | reverse: false}}

        # Reveal (not concealed)
        28 ->
          %{acc_emulator | style: %{current_style | conceal: false}}

        # Not crossed out
        29 ->
          %{acc_emulator | style: %{current_style | strikethrough: false}}

        # Set foreground color (30-37)
        n when n >= 30 and n <= 37 ->
          color_name = TextFormatting.ansi_code_to_color_name(n)

          %{
            acc_emulator
            | style: %{current_style | foreground_color: color_name}
          }

        # Set foreground color (extended - 38)
        38 ->
          # TODO: Handle 256-color / RGB foreground (requires parsing next params)
          Logger.warning(
            "SGR: Extended foreground color (38) not fully implemented"
          )

          acc_emulator

        # Default foreground color
        39 ->
          %{acc_emulator | style: %{current_style | foreground_color: nil}}

        # Set background color (40-47)
        n when n >= 40 and n <= 47 ->
          color_name = TextFormatting.ansi_code_to_color_name(n)

          %{
            acc_emulator
            | style: %{current_style | background_color: color_name}
          }

        # Set background color (extended - 48)
        48 ->
          # TODO: Handle 256-color / RGB background (requires parsing next params)
          Logger.warning(
            "SGR: Extended background color (48) not fully implemented"
          )

          acc_emulator

        # Default background color
        49 ->
          %{acc_emulator | style: %{current_style | background_color: nil}}

        # Set bright foreground color (90-97)
        n when n >= 90 and n <= 97 ->
          color_name = TextFormatting.ansi_code_to_color_name(n)

          %{
            acc_emulator
            | style: %{current_style | foreground_color: color_name}
          }

        # Set bright background color (100-107)
        n when n >= 100 and n <= 107 ->
          color_name = TextFormatting.ansi_code_to_color_name(n)

          %{
            acc_emulator
            | style: %{current_style | background_color: color_name}
          }

        # Ignore nil params (from maybe_param)
        nil ->
          acc_emulator

        _ ->
          Logger.warning("SGR: Unhandled parameter: #{param}")
          acc_emulator
      end
    end)
  end

  # Parameter Parser
  @spec parse_params(String.t()) :: list(integer() | nil)
  def parse_params(param_string) when is_binary(param_string) do
    param_string
    # Corrected: Keep empty strings for params like CSI ;m
    |> String.split(";", trim: false)
    |> Enum.map(fn
      # Represent empty param (e.g., CSI ;m or CSI m)
      "" ->
        nil

      # Handle potential integer conversion errors gracefully
      str ->
        case Integer.parse(str) do
          {int_val, ""} -> int_val
          # Treat non-integer params as nil or handle as error? Defaulting to nil.
          _ -> nil
        end
    end)
  end

  # --- Helper for Erasing ---

  # Creates a list of new (empty) cells
  defp create_empty_cells(count) do
    List.duplicate(Cell.new(), count)
  end

  # Replaces a portion of a list (representing a row) with empty cells
  # Handles potential negative lengths gracefully.
  defp replace_range_with_empty(list, start_index, end_index)
       when start_index <= end_index do
    length = end_index - start_index + 1

    if length > 0 do
      empty_part = create_empty_cells(length)
      List.replace_at(list, start_index, empty_part)
    else
      # No change if length is zero or negative
      list
    end
  end

  # Start > End
  defp replace_range_with_empty(list, _start_index, _end_index), do: list

  # ED - Erase Display Handler
  @spec handle_ed(Emulator.t(), integer()) :: Emulator.t()
  def handle_ed(emulator, mode \\ 0) do
    Logger.debug("ED received - Erase Display (Mode: #{mode})")
    %{cursor: cursor} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)
    {current_col, current_row} = Manager.get_position(cursor)

    %{width: width, height: height, cells: cells, scrollback: scrollback} =
      active_buffer

    new_cells =
      case mode do
        # Mode 0: Erase from cursor to end of screen
        0 ->
          # Erase current line from cursor to end
          current_line = Enum.at(cells, current_row)

          erased_current_line =
            replace_range_with_empty(current_line, current_col, width - 1)

          # Erase lines below cursor
          cells_after_update =
            List.replace_at(cells, current_row, erased_current_line)

          Enum.map_indexed(cells_after_update, fn line, index ->
            if index > current_row do
              create_empty_cells(width)
            else
              line
            end
          end)

        # Mode 1: Erase from beginning of screen to cursor
        1 ->
          # Erase current line from beginning to cursor (inclusive)
          current_line = Enum.at(cells, current_row)

          erased_current_line =
            replace_range_with_empty(current_line, 0, current_col)

          # Erase lines above cursor
          cells_after_update =
            List.replace_at(cells, current_row, erased_current_line)

          Enum.map_indexed(cells_after_update, fn line, index ->
            if index < current_row do
              create_empty_cells(width)
            else
              line
            end
          end)

        # Mode 2: Erase entire screen
        2 ->
          List.duplicate(create_empty_cells(width), height)

        # Mode 3: Erase entire screen + scrollback (xterm)
        3 ->
          # Handled below by updating scrollback too
          List.duplicate(create_empty_cells(width), height)

        # Unknown mode - do nothing
        _ ->
          Logger.warning("Unhandled ED mode: #{mode}")
          cells
      end

    # Clear scrollback only for mode 3
    new_scrollback = if mode == 3, do: [], else: scrollback

    updated_active_buffer = %{
      active_buffer
      | cells: new_cells,
        scrollback: new_scrollback
    }

    Emulator.update_active_buffer(emulator, updated_active_buffer)
  end

  # EL - Erase in Line Handler
  @spec handle_el(Emulator.t(), integer()) :: Emulator.t()
  def handle_el(emulator, mode \\ 0) do
    Logger.debug("EL received - Erase in Line (Mode: #{mode})")
    %{cursor: cursor} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)
    {current_col, current_row} = Manager.get_position(cursor)
    %{width: width, cells: cells} = active_buffer

    # Ensure row index is within bounds
    if current_row >= 0 and current_row < length(cells) do
      current_line = Enum.at(cells, current_row)

      new_line =
        case mode do
          # Mode 0: Erase from cursor to end of line
          0 ->
            replace_range_with_empty(current_line, current_col, width - 1)

          # Mode 1: Erase from beginning of line to cursor (inclusive)
          1 ->
            replace_range_with_empty(current_line, 0, current_col)

          # Mode 2: Erase entire line
          2 ->
            create_empty_cells(width)

          # Unknown mode - do nothing
          _ ->
            Logger.warning("Unhandled EL mode: #{mode}")
            current_line
        end

      new_cells = List.replace_at(cells, current_row, new_line)
      updated_active_buffer = %{active_buffer | cells: new_cells}
      Emulator.update_active_buffer(emulator, updated_active_buffer)
    else
      # Cursor outside valid rows, should ideally not happen
      Logger.error(
        "EL command received with cursor row (#{current_row}) outside buffer height (#{length(cells)})"
      )

      emulator
    end
  end

  # --- New Helper Function for DECSCUSR ---
  @spec handle_decscusr(Emulator.t(), integer() | nil) :: Emulator.t()
  defp handle_decscusr(emulator, param) do
    style =
      case param do
        0 ->
          :blinking_block

        # Default
        1 ->
          :blinking_block

        2 ->
          :steady_block

        3 ->
          :blinking_underline

        4 ->
          :steady_underline

        5 ->
          :blinking_bar

        6 ->
          :steady_bar

        # Handle invalid parameter, default to blinking block
        _ ->
          Logger.debug(
            "DECSCUSR: Invalid parameter #{inspect(param)}, defaulting to blinking_block."
          )

          :blinking_block
      end

    Logger.debug("DECSCUSR: Setting cursor style to #{style}")
    %{emulator | cursor_style: style}
  end
end
