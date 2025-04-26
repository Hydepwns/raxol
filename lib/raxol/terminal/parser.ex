defmodule Raxol.Terminal.Parser do
  @moduledoc """
  Parses raw byte streams into terminal events and commands.
  Handles escape sequences (CSI, OSC, DCS, etc.) and plain text.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.Commands.Executor
  alias Raxol.Terminal.Commands.Modes
  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Cursor.Movement
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Parser.States.GroundState
  alias Raxol.Terminal.Parser.States.EscapeState
  alias Raxol.Terminal.Parser.States.DesignateCharsetState
  alias Raxol.Terminal.Parser.States.CSIEntryState
  alias Raxol.Terminal.Parser.States.CSIParamState
  alias Raxol.Terminal.Parser.States.CSIIntermediateState
  alias Raxol.Terminal.Parser.States.OSCStringState
  alias Raxol.Terminal.Parser.States.OSCStringMaybeSTState
  alias Raxol.Terminal.Parser.States.DCSEntryState
  alias Raxol.Terminal.Parser.States.DCSPassthroughState
  alias Raxol.Terminal.Parser.States.DCSPassthroughMaybeSTState
  # Add alias for ScreenModes if mode_enabled? is called directly (it isn't currently)
  require Logger

  # --- Define Internal Parser State ---
  defmodule State do
    @moduledoc false
    defstruct state: :ground,
              # Raw params string buffer (e.g., "1;31")
              params_buffer: "",
              # Raw intermediates string buffer (e.g., "?")
              intermediates_buffer: "",
              # Buffer for OSC/DCS/etc. content
              payload_buffer: "",
              # Final byte collected for CSI/DCS sequence (before payload for DCS)
              final_byte: nil,
              # G-set being designated (0-3)
              designating_gset: nil
  end

  # --- Public API ---

  @doc """
  Parses a chunk of input using a state machine.

  Takes the current emulator state and input binary, returns the updated emulator state
  after processing the input chunk.

  Delegates actual state modification (character writing, command execution)
  back to the Emulator module.
  """
  @spec parse_chunk(Emulator.t(), binary()) :: Emulator.t()
  def parse_chunk(emulator, input) when is_binary(input) do
    # Start the internal recursive parsing with initial parser state
    initial_parser_state = %Raxol.Terminal.Parser.State{}
    # Pass initial emulator, initial parser state, and the input
    parse_loop(emulator, initial_parser_state, input)
  end

  # --- Internal Parsing State Machine (Renamed do_parse_chunk -> parse_loop) ---

  # Base case: End of input
  # Accepts emulator, parser_state, and empty input
  defp parse_loop(emulator, parser_state, "") do
    # IO.inspect({:parse_loop_end_of_input, parser_state.state, ""}, label: "DEBUG_PARSER")
    if parser_state.state != :ground do
      Logger.debug("Input ended while in parser state: #{parser_state.state}")
    end

    emulator
  end

  # --- Ground State ---
  # Delegates to GroundState handler
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         input
       ) do
    case GroundState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- Escape State ---
  # Delegates to EscapeState handler
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         input
       ) do
    case EscapeState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- Designate Charset State ---
  # Delegates to DesignateCharsetState handler
  defp parse_loop(
         emulator,
         %State{state: :designate_charset} = parser_state,
         input
       ) do
    case DesignateCharsetState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- CSI Entry State ---
  # Delegates to CSIEntryState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_entry} = parser_state,
         input
       ) do
    case CSIEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- CSI Param State ---
  # Delegates to CSIParamState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_param} = parser_state,
         input
       ) do
    case CSIParamState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- CSI Intermediate State ---
  # Delegates to CSIIntermediateState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_intermediate} = parser_state,
         input
       ) do
    case CSIIntermediateState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- OSC String State ---
  # Delegates to OSCStringState handler
  defp parse_loop(
         emulator,
         %State{state: :osc_string} = parser_state,
         input
       ) do
    case OSCStringState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # Helper state to check for ST after ESC in OSC String
  # Delegates to OSCStringMaybeSTState handler
  defp parse_loop(
         emulator,
         %State{state: :osc_string_maybe_st} = parser_state,
         input
       ) do
    case OSCStringMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- DCS Entry State ---
  # Delegates to DCSEntryState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_entry} = parser_state,
         input
       ) do
    case DCSEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- DCS Passthrough State ---
  # Delegates to DCSPassthroughState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough} = parser_state,
         input
       ) do
    case DCSPassthroughState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # Helper state to check for ST after ESC in DCS Passthrough
  # Delegates to DCSPassthroughMaybeSTState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough_maybe_st} = parser_state,
         input
       ) do
    case DCSPassthroughMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:handled, final_emulator} ->
        final_emulator
    end
  end

  # --- Private Helper Functions (Moved from Emulator) ---

  # Accumulates digits or semicolons into the params_buffer.
  # Accepts the current parser_state and the byte, returns updated parser_state.
  defp accumulate_csi_param(parser_state, byte)
       when byte >= ?0 and byte <= ?; do
    # Prevent overly long param strings (sanity check)
    current_params = parser_state.params_buffer
    # Arbitrary limit
    if String.length(current_params) < 256 do
      %{parser_state | params_buffer: current_params <> <<byte>>}
    else
      Logger.warning("Exceeded CSI parameter string length limit")
      # Return unchanged state to prevent excessive growth
      parser_state
    end
  end

  # Collects intermediate bytes (0x20-0x2F) into the intermediates_buffer.
  # Accepts the current parser_state and the byte, returns updated parser_state.
  defp collect_csi_intermediate(parser_state, byte)
       when byte >= 0x20 and byte <= 0x2F do
    # Prevent overly long intermediate strings
    current_intermediates = parser_state.intermediates_buffer
    # Arbitrary limit (usually only 1 or 2)
    if String.length(current_intermediates) < 16 do
      %{parser_state | intermediates_buffer: current_intermediates <> <<byte>>}
    else
      Logger.warning("Exceeded CSI intermediate string length limit")
      # Return unchanged state
      parser_state
    end
  end

  # Collects private marker or intermediate bytes (0x3C-0x3F) into intermediates_buffer
  defp collect_csi_intermediate(parser_state, byte)
       when byte >= 0x3C and byte <= 0x3F do
    # Combined with the above function as the range check is different in CSI Entry
    current_intermediates = parser_state.intermediates_buffer
    # Arbitrary limit
    if String.length(current_intermediates) < 16 do
      %{parser_state | intermediates_buffer: current_intermediates <> <<byte>>}
    else
      Logger.warning("Exceeded CSI intermediate string length limit")
      # Return unchanged state
      parser_state
    end
  end

  # Helper to accumulate DCS parameters (similar to CSI)
  defp accumulate_dcs_param(parser_state, byte)
       when byte >= ?0 and byte <= ?; do
    current_params = parser_state.params_buffer

    if String.length(current_params) < 256 do
      %{parser_state | params_buffer: current_params <> <<byte>>}
    else
      Logger.warning("Exceeded DCS parameter string length limit")
      parser_state
    end
  end

  # Helper to collect DCS intermediates (similar to CSI)
  defp collect_dcs_intermediate(parser_state, byte)
       when byte >= 0x20 and byte <= 0x2F do
    current_intermediates = parser_state.intermediates_buffer

    if String.length(current_intermediates) < 16 do
      %{parser_state | intermediates_buffer: current_intermediates <> <<byte>>}
    else
      Logger.warning("Exceeded DCS intermediate string length limit")
      parser_state
    end
  end

  # --- ADDED CSI Dispatcher ---
  # Dispatch CSI command based on final byte and intermediates
  defp dispatch_csi(emulator, params_buffer, intermediates_buffer, final_byte) do
    params = parse_csi_params(params_buffer)
    intermediates = intermediates_buffer

    # IO.inspect({:dispatch_csi, final_byte, intermediates, params}, label: "DEBUG_CSI")

    # Delegate based on final byte category
    case final_byte do
      # Cursor Movement
      ?A -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?B -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?C -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?D -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?E -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?F -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?G -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?H -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?d -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?f -> dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte)
      ?q when intermediates == " " -> dispatch_csi_cursor_style(emulator, params, intermediates, final_byte)

      # Editing
      ?J -> dispatch_csi_editing(emulator, params, intermediates, final_byte)
      ?K -> dispatch_csi_editing(emulator, params, intermediates, final_byte)
      ?L -> dispatch_csi_editing(emulator, params, intermediates, final_byte)
      ?M -> dispatch_csi_editing(emulator, params, intermediates, final_byte)

      # Scrolling
      ?S -> dispatch_csi_scrolling(emulator, params, intermediates, final_byte)
      ?T -> dispatch_csi_scrolling(emulator, params, intermediates, final_byte)
      ?r -> dispatch_csi_scrolling(emulator, params, intermediates, final_byte)

      # Modes
      ?h -> dispatch_csi_modes(emulator, params, intermediates, final_byte)
      ?l -> dispatch_csi_modes(emulator, params, intermediates, final_byte)

      # Graphics
      ?m -> dispatch_csi_graphics(emulator, params, intermediates, final_byte)

      # Device Status
      ?n -> dispatch_csi_device_status(emulator, params, intermediates, final_byte)

      _ ->
        Logger.debug(
          "Unhandled CSI sequence in dispatch: final=#{final_byte}, intermediates=#{inspect(intermediates)}, params=#{inspect(params)}"
        )
        emulator
    end
  end

  # --- CSI Sub-Dispatchers ---

  defp dispatch_csi_graphics(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # SGR - Set Graphics Rendition
      {?m, ""} ->
        handle_sgr(emulator, params)

      _ ->
        Logger.debug("Unhandled CSI graphics sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_scrolling(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # SU - Scroll Up
      {?S, ""} ->
        count = get_csi_param(params, 1)
        Screen.scroll_up(emulator, count)

      # SD - Scroll Down
      {?T, ""} ->
        count = get_csi_param(params, 1)
        Screen.scroll_down(emulator, count)

      # DECSTBM - Set Top and Bottom Margins
      {?r, ""} ->
        handle_set_scroll_region(emulator, params)

      _ ->
        Logger.debug("Unhandled CSI scrolling sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_modes(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # DECSET - Set Mode
      {?h, "?"} ->
        Modes.handle_dec_private_mode(emulator, params, :set)

      {?h, ""} ->
        Modes.handle_ansi_mode(emulator, params, :set)

      # DECRST - Reset Mode
      {?l, "?"} ->
        Modes.handle_dec_private_mode(emulator, params, :reset)

      {?l, ""} ->
        Modes.handle_ansi_mode(emulator, params, :reset)

      _ ->
        Logger.debug("Unhandled CSI mode sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_cursor_movement(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # CUU - Cursor Up
      {?A, ""} ->
        count = get_csi_param(params, 1)
        %{emulator | cursor: Movement.move_up(emulator.cursor, count)}

      # CUD - Cursor Down
      {?B, ""} ->
        count = get_csi_param(params, 1)
        %{emulator | cursor: Movement.move_down(emulator.cursor, count)}

      # CUF - Cursor Forward
      {?C, ""} ->
        count = get_csi_param(params, 1)
        %{emulator | cursor: Movement.move_right(emulator.cursor, count)}

      # CUB - Cursor Back
      {?D, ""} ->
        count = get_csi_param(params, 1)
        %{emulator | cursor: Movement.move_left(emulator.cursor, count)}

      # CUP - Cursor Position
      {?H, ""} ->
        handle_cursor_position(emulator, params)

      # HVP - Horizontal and Vertical Position (same as CUP)
      {?f, ""} ->
        handle_cursor_position(emulator, params)

      # CNL - Cursor Next Line
      {?E, ""} ->
        count = get_csi_param(params, 1)
        cursor = emulator.cursor
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}} # Move to col 0
        cursor = Movement.move_down(cursor, count)
        %{emulator | cursor: cursor}

      # CPL - Cursor Previous Line
      {?F, ""} ->
        count = get_csi_param(params, 1)
        cursor = emulator.cursor
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}} # Move to col 0
        cursor = Movement.move_up(cursor, count)
        %{emulator | cursor: cursor}

      # CHA - Cursor Horizontal Absolute
      {?G, ""} ->
        col = get_csi_param(params, 1)
        {_, row} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col - 1, row)} # 1-based to 0-based col

      # VPA - Vertical Position Absolute
      {?d, ""} ->
        row = get_csi_param(params, 1)
        {col, _} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col, row - 1)} # 1-based to 0-based row

      _ ->
        Logger.debug("Unhandled CSI cursor movement sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_editing(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # ED - Erase in Display (clear screen)
      {?J, ""} ->
        n = get_csi_param(params, 1, 0)
        Screen.clear_screen(emulator, n)

      # EL - Erase in Line (clear line)
      {?K, ""} ->
        n = get_csi_param(params, 1, 0)
        Screen.clear_line(emulator, n)

      # IL - Insert Line
      {?L, ""} ->
        n = get_csi_param(params, 1)
        Screen.insert_lines(emulator, n)

      # DL - Delete Line
      {?M, ""} ->
        n = get_csi_param(params, 1)
        Screen.delete_lines(emulator, n)

      _ ->
        Logger.debug("Unhandled CSI editing sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_cursor_style(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # DECSCUSR - Set Cursor Style
      {?q, " "} ->
        n = get_csi_param(params, 1, 1)
        handle_cursor_style(emulator, n)

      _ ->
        Logger.debug("Unhandled CSI cursor style sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_csi_device_status(emulator, params, intermediates, final_byte) do
    case {final_byte, intermediates} do
      # DSR - Device Status Report
      {?n, ""} ->
        n = get_csi_param(params, 1)
        handle_device_status_report(emulator, n)

      _ ->
        Logger.debug("Unhandled CSI device status sequence: #{final_byte}, #{inspect(intermediates)}")
        emulator
    end
  end

  defp dispatch_osc(emulator, payload_buffer) do
    # Logic moved from deprecated Raxol.Terminal.CommandExecutor
    # Parse the command string: Ps ; Pt ST
    # Ps is the command code (0, 2, 8, etc.)
    case String.split(payload_buffer, ";", parts: 2) do
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
                      "Malformed OSC 8 sequence: '#{payload_buffer}'"
                    )

                    emulator
                end

              # Add other OSC commands here (e.g., colors, notifications)
              _ ->
                Logger.warning(
                  "Unhandled OSC command code: #{ps_code}, String: '#{payload_buffer}'"
                )

                emulator
            end

          # Failed to parse Ps as integer
          _ ->
            Logger.warning(
              "Invalid OSC command code: '#{ps_str}', String: '#{payload_buffer}'"
            )

            emulator
        end

      # Handle OSC sequences with no parameters (e.g., some color requests)
      # Or potentially malformed sequences
      _ ->
        Logger.warning(
          "Unhandled or malformed OSC sequence format: '#{payload_buffer}'"
        )

        emulator
    end
  end

  defp dispatch_dcs(emulator, params_buffer, intermediates_buffer, final_byte, payload_buffer) do
    # Logic moved from deprecated Raxol.Terminal.CommandExecutor
    # Parse the raw param string buffer (optional, DCS params are less common)
    params = parse_csi_params(params_buffer)
    # Use intermediates_buffer directly
    intermediates = intermediates_buffer

    Logger.debug(
      "DCS called: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}', Payload(len=#{String.length(payload_buffer)})"
    )

    # Dispatch based on params/intermediates/final_byte
    # Match on final_byte first
    case {final_byte, intermediates} do
      # Sixel Graphics (DECGRA) - ESC P P1 ; P2 ; P3 q <payload> ESC \
      # P1 = pixel aspect ratio (ignored), P2 = background color mode (ignored), P3 = horizontal grid size (ignored)
      {?q, _intermediates} ->
        handle_sixel_graphics(emulator, payload_buffer)

      # TODO: Add other DCS handlers (e.g., User-Defined Keys - DECDLD, Terminal Reports - DECRQSS)

      _ ->
        Logger.warning(
          "Unhandled DCS sequence: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}'"
        )

        emulator
    end
  end

  # Sixel Graphics Handler (Moved from deprecated executor)
  @spec handle_sixel_graphics(Emulator.t(), String.t()) :: Emulator.t()
  defp handle_sixel_graphics(emulator, payload) do
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

  # --- ADDED Placeholder Helper Functions ---

  defp parse_csi_params(params_buffer) do
    # Simplified placeholder - assumes Parser.parse_params exists or similar logic
    String.split(params_buffer, ";", trim: true)
    |> Enum.map(fn
      # Empty param
      "" ->
        nil

      s ->
        try do
          String.to_integer(s)
        rescue
          # Invalid integer
          _ -> nil
        end
    end)
  end

  defp get_csi_param(params, index, default \\ 1) do
    # Simplified placeholder - assumes Parser.get_param exists or similar logic
    Enum.at(params, index - 1) || default
  end

  defp handle_sgr(emulator, params_buffer) do
    # Parse the raw param string (e.g., "1;31") into list of integers/nil
    params = parse_csi_params(params_buffer)

    # Convert numeric params to attribute atoms
    attribute_atoms = Enum.map(params, &sgr_code_to_atom/1) |> Enum.reject(&is_nil/1)

    # Apply the attributes sequentially using Enum.reduce
    new_style =
      Enum.reduce(attribute_atoms, emulator.style, &Raxol.Terminal.ANSI.TextFormatting.apply_attribute/2)

    # Update the emulator state
    %{emulator | style: new_style}
  end

  # Helper to convert SGR code to attribute atom
  # Based on Raxol.Terminal.ANSI.TextFormatting.apply_attribute/2
  # and common SGR codes.
  defp sgr_code_to_atom(code) do
    case code do
      0 -> :reset
      1 -> :bold
      2 -> :faint # Note: Faint often resets bold in TextFormatting
      3 -> :italic
      4 -> :underline
      5 -> :blink
      # 6 is rapid blink, often same as 5
      7 -> :reverse
      8 -> :conceal
      9 -> :strikethrough
      21 -> :double_underline # Needs support in TextFormatting?
      22 -> :normal_intensity # Resets bold/faint
      23 -> :no_italic_fraktur # Resets italic
      24 -> :no_underline # Resets underline
      25 -> :no_blink
      27 -> :no_reverse
      28 -> :reveal # Resets conceal
      29 -> :no_strikethrough

      # Standard Foreground Colors
      30 -> :black
      31 -> :red
      32 -> :green
      33 -> :yellow
      34 -> :blue
      35 -> :magenta
      36 -> :cyan
      37 -> :white
      39 -> :default_fg

      # Standard Background Colors
      40 -> :bg_black
      41 -> :bg_red
      42 -> :bg_green
      43 -> :bg_yellow
      44 -> :bg_blue
      45 -> :bg_magenta
      46 -> :bg_cyan
      47 -> :bg_white
      49 -> :default_bg

      # High Intensity Foreground Colors
      90 -> :bright_black # Need specific atoms in TextFormatting or map to basic?
      91 -> :bright_red
      92 -> :bright_green
      93 -> :bright_yellow
      94 -> :bright_blue
      95 -> :bright_magenta
      96 -> :bright_cyan
      97 -> :bright_white

      # High Intensity Background Colors
      100 -> :bg_bright_black
      101 -> :bg_bright_red
      102 -> :bg_bright_green
      103 -> :bg_bright_yellow
      104 -> :bg_bright_blue
      105 -> :bg_bright_magenta
      106 -> :bg_bright_cyan
      107 -> :bg_bright_white

      # TODO: Handle 256-color (38;5;n, 48;5;n) and TrueColor (38;2;r;g;b, 48;2;r;g;b) codes
      # These require consuming multiple parameters.

      # Fallback for unknown codes
      _ ->
        Logger.debug("Unhandled SGR code: #{inspect(code)}")
        nil
    end
  end

  defp handle_set_scroll_region(emulator, params) do
    # DECSTBM - Set Top and Bottom Margins (Scrolling Region)
    # Params: P t ; P b r (top line; bottom line)
    # Values are 1-based. If params are omitted, reset to full screen.
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)

    {top_line, bottom_line} =
      case params do
        [] -> {1, height} # Reset to full height
        [nil] -> {1, height} # Reset to full height
        [t] when is_integer(t) -> {t, height} # Top only, bottom defaults to height
        [nil, b] when is_integer(b) -> {1, b} # Bottom only, top defaults to 1
        [t, b] when is_integer(t) and is_integer(b) -> {t, b} # Both specified
        _ ->
          Logger.warning("Invalid DECSTBM parameters: #{inspect(params)}")
          {1, height} # Default to full height on error
      end

    # Validate and clamp parameters (1-based)
    # Ensure top < bottom, and both are within screen bounds.
    valid_top = max(1, top_line)
    valid_bottom = min(height, bottom_line)

    if valid_top >= valid_bottom do
      Logger.warning(
        "Invalid scroll region: top (#{valid_top}) >= bottom (#{valid_bottom}). Resetting."
      )

      # Reset to full screen on invalid range
      %{emulator | scroll_region: nil}
    else
      # Set the scroll region (convert to 0-based for internal storage)
      new_scroll_region = {valid_top - 1, valid_bottom - 1}
      Logger.debug("Setting scroll region to: #{inspect(new_scroll_region)}")
      %{emulator | scroll_region: new_scroll_region}
    end
  end

  defp handle_cursor_position(emulator, params) do
    # Placeholder - Needs logic from old executor's handle_cursor_position
    Logger.debug("CUP/HVP called with params: #{inspect(params)}")
    emulator
  end

  defp handle_cursor_style(emulator, param) do
    # DECSCUSR - Set Cursor Style
    # Params: 0 or 1 (blinking block), 2 (steady block),
    #         3 (blinking underline), 4 (steady underline),
    #         5 (blinking bar), 6 (steady bar)
    # Defaults are often implementation-specific.

    new_style = case param do
      0 -> :blinking_block # Default
      1 -> :blinking_block
      2 -> :steady_block
      3 -> :blinking_underline
      4 -> :steady_underline
      5 -> :blinking_bar
      6 -> :steady_bar
      _ ->
        Logger.warning("Unknown cursor style code: #{param}. Defaulting to blinking block.")
        :blinking_block
    end

    Logger.debug("Setting cursor style to: #{new_style}")
    %{emulator | cursor_style: new_style}
  end

  defp handle_device_status_report(emulator, param) do
    # DSR - Device Status Report
    # Params: 5 (Status Report), 6 (Cursor Position Report - CPR)

    response =
      case param do
        5 ->
          # Report OK: CSI 0 n
          "\e[0n"

        6 ->
          # Report Cursor Position (CPR): CSI Pl ; Pc R
          # Pl = line (1-based), Pc = column (1-based)
          # Emulator uses 0-based internally.
          {col_0_based, row_0_based} = emulator.cursor.position
          row_1_based = row_0_based + 1
          col_1_based = col_0_based + 1
          "\e[#{row_1_based};#{col_1_based}R"

        _ ->
          Logger.warning("Unknown DSR parameter: #{param}")
          nil
      end

    # Append response to output buffer if generated
    if response do
      Logger.debug("Sending DSR response: #{inspect(response)}")
      %{emulator | output_buffer: emulator.output_buffer <> response}
    else
      emulator
    end
  end
end
