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
  # alias Raxol.Terminal.ANSI.Parser, as: ANSIParser

  # Add alias for ScreenModes if mode_enabled? is called directly (it isn't currently)
  # alias Raxol.Terminal.ANSI.ScreenModes
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
  # Accepts emulator, parser_state (matching state: :ground), and input starting with ESC
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         <<27, rest_after_esc::binary>>
       ) do
    # IO.inspect({:parse_loop_ground_escape, parser_state.state, input}, label: "DEBUG_PARSER")
    # Update parser state: change state atom, reset buffers
    next_parser_state = %State{
      parser_state
      | state: :escape,
        params_buffer: "",
        payload_buffer: "",
        intermediates_buffer: ""
    }

    parse_loop(emulator, next_parser_state, rest_after_esc)
  end

  # LF
  # Accepts emulator, parser_state (matching state: :ground), and input starting with LF
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         <<10, rest_after_lf::binary>>
       ) do
    # IO.inspect({:parse_loop_ground_lf, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_lf(emulator)
    # Continue with same parser state
    parse_loop(new_emulator, parser_state, rest_after_lf)
  end

  # CR
  # Accepts emulator, parser_state (matching state: :ground), and input starting with CR
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         <<13, rest_after_cr::binary>>
       ) do
    # IO.inspect({:parse_loop_ground_cr, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_cr(emulator)
    # Continue with same parser state
    parse_loop(new_emulator, parser_state, rest_after_cr)
  end

  # Printable character
  # Accepts emulator, parser_state (matching state: :ground), and printable char input
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         <<char_codepoint::utf8, rest_after_char::binary>>
       )
       when char_codepoint >= 32 do
    # Call back to Emulator
    new_emulator = Emulator.process_character(emulator, char_codepoint)

    # IO.inspect({:parser_ground_printable_before_recurse, :erlang.term_to_binary(new_emulator)}, label: "TRACE_EMU")
    # Continue with same parser state
    parse_loop(new_emulator, parser_state, rest_after_char)
  end

  # Fallback for other C0 or invalid UTF-8
  # Accepts emulator, parser_state (matching state: :ground), and any other byte
  defp parse_loop(
         emulator,
         %State{state: :ground} = parser_state,
         <<byte, rest::binary>>
       ) do
    # IO.inspect({:parse_loop_ground_fallback_or_c0, parser_state.state, input, byte}, label: "DEBUG_PARSER")
    if byte >= 0 and byte <= 31 and byte != 10 and byte != 13 do
      # Call back to Emulator for C0
      new_emulator = Emulator.process_character(emulator, byte)
      parse_loop(new_emulator, parser_state, rest)
    else
      Logger.warning(
        "[Parser] Unhandled/Ignored byte #{inspect(byte)} in ground state. Skipping."
      )

      parse_loop(emulator, parser_state, rest)
    end
  end

  # --- Escape State ---
  # Accepts emulator, parser_state (matching state: :escape), and empty input
  defp parse_loop(emulator, %State{state: :escape}, <<>>) do
    # IO.inspect({:parse_loop_escape_empty, parser_state.state, ""}, label: "DEBUG_PARSER")
    # Incomplete
    emulator
  end

  # Accepts emulator, parser_state (matching state: :escape), and input starting with CSI
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<91, rest_after_csi::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_csi, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{parser_state | state: :csi_entry}
    parse_loop(emulator, next_parser_state, rest_after_csi)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input starting with OSC
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<93, rest_after_osc::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_osc, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{parser_state | state: :osc_string, payload_buffer: ""}
    parse_loop(emulator, next_parser_state, rest_after_osc)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input starting with DCS
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<80, rest_after_dcs::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_dcs, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{
      parser_state
      | state: :dcs_entry,
        params_buffer: "",
        intermediates_buffer: "",
        payload_buffer: ""
    }

    parse_loop(emulator, next_parser_state, rest_after_dcs)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input for designating G0
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?(, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_designate_g0, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{
      parser_state
      | state: :designate_charset,
        designating_gset: 0
    }

    parse_loop(emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input for designating G1
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?), rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_designate_g1, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{
      parser_state
      | state: :designate_charset,
        designating_gset: 1
    }

    parse_loop(emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input for designating G2
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?*, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_designate_g2, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{
      parser_state
      | state: :designate_charset,
        designating_gset: 2
    }

    parse_loop(emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and input for designating G3
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?+, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_designate_g3, parser_state.state, input}, label: "DEBUG_PARSER")
    next_parser_state = %{
      parser_state
      | state: :designate_charset,
        designating_gset: 3
    }

    parse_loop(emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and SS2 input
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<78, rest_after_ss::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_ss2, parser_state.state, input}, label: "DEBUG_PARSER")
    Logger.info("[Parser] SS2 received - Not implemented")
    # TODO: Implement SS2 handling (invoke G2 for next char)
    # Return to ground after SS2
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(emulator, next_parser_state, rest_after_ss)
  end

  # Accepts emulator, parser_state (matching state: :escape), and SS3 input
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<79, rest_after_ss::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_ss3, parser_state.state, input}, label: "DEBUG_PARSER")
    Logger.info("[Parser] SS3 received - Not implemented")
    # TODO: Implement SS3 handling (invoke G3 for next char)
    # Return to ground after SS3
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(emulator, next_parser_state, rest_after_ss)
  end

  # Accepts emulator, parser_state (matching state: :escape), and RIS input
  # RIS
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?c, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_ris, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_ris(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and IND input
  # IND
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?D, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_ind, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_ind(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and NEL input
  # NEL
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?E, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_nel, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_nel(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and HTS input
  # HTS
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?H, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_hts, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_hts(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and RI input
  # RI
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?M, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_ri, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_ri(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and DECSC input
  # DECSC
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?7, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_decsc, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_decsc(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and DECRC input
  # DECRC
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<?8, rest_after::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_decrc, parser_state.state, input}, label: "DEBUG_PARSER")
    # Call back to Emulator
    new_emulator = Emulator.handle_decrc(emulator)
    next_parser_state = %{parser_state | state: :ground}
    parse_loop(new_emulator, next_parser_state, rest_after)
  end

  # Accepts emulator, parser_state (matching state: :escape), and fallback char input
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         <<char_codepoint, rest_after_char::binary>>
       ) do
    # IO.inspect({:parse_loop_escape_fallback, parser_state.state, input, char_codepoint}, label: "DEBUG_PARSER")
    Logger.debug(
      "[Parser] Unhandled char #{inspect(char_codepoint)} after ESC, returning to ground."
    )

    next_parser_state = %{parser_state | state: :ground}
    # Effectively ignore the char and go back to ground with the rest
    parse_loop(emulator, next_parser_state, rest_after_char)
  end

  # --- Designate Charset State ---
  # Accepts emulator, parser_state (matching state: :designate_charset), and input
  defp parse_loop(
         emulator,
         %State{state: :designate_charset, designating_gset: gset} =
           parser_state,
         rest
       ) do
    # IO.inspect({:parse_loop_designate, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      <<charset_code, rest_after_code::binary>> ->
        # Pass explicit gset and charset_code to Emulator
        new_charset_state =
          CharacterSets.designate_charset(
            emulator.charset_state,
            gset,
            charset_code
          )

        new_emulator = %{emulator | charset_state: new_charset_state}

        next_parser_state = %{
          parser_state
          | state: :ground,
            designating_gset: nil
        }

        parse_loop(new_emulator, next_parser_state, rest_after_code)
    end
  end

  # --- CSI Entry State ---
  # Accepts emulator, parser_state (matching state: :csi_entry), and input
  defp parse_loop(emulator, %State{state: :csi_entry} = parser_state, rest) do
    # IO.inspect({:parse_loop_csi_entry, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # Parameter byte
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?9 ->
        next_parser_state = accumulate_csi_param(parser_state, param_byte)

        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_param},
          rest_after_param
        )

      # Semicolon parameter separator
      <<?;, rest_after_param::binary>> ->
        next_parser_state = accumulate_csi_param(parser_state, ?;)

        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_param},
          rest_after_param
        )

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        next_parser_state =
          collect_csi_intermediate(parser_state, intermediate_byte)

        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_intermediate},
          rest_after_intermediate
        )

      # Private marker / Intermediate byte
      <<private_marker, rest_after_marker::binary>>
      when private_marker >= 0x3C and private_marker <= 0x3F ->
        next_parser_state =
          collect_csi_intermediate(parser_state, private_marker)

        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_intermediate},
          rest_after_marker
        )

      # Final byte
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        # Pass explicit params, intermediates, final_byte to Emulator
        new_emulator =
          dispatch_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )

        next_parser_state = %{parser_state | state: :ground}

        # IO.inspect({:parser_csi_before_recurse, :erlang.term_to_binary(new_emulator)}, label: "TRACE_EMU")
        parse_loop(new_emulator, next_parser_state, rest_after_final)

      # Ignored byte in CSI Entry (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in CSI Entry")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_ignored)

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in CSI Entry")
        # Stay in state, ignore byte
        parse_loop(emulator, parser_state, rest_after_ignored)

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in CSI Entry state, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_unhandled)
    end
  end

  # --- CSI Param State ---
  # Accepts emulator, parser_state (matching state: :csi_param), and input
  defp parse_loop(emulator, %State{state: :csi_param} = parser_state, rest) do
    # IO.inspect({:parse_loop_csi_param, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # Parameter byte or separator
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?; ->
        next_parser_state = accumulate_csi_param(parser_state, param_byte)
        parse_loop(emulator, next_parser_state, rest_after_param)

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        next_parser_state =
          collect_csi_intermediate(parser_state, intermediate_byte)

        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_intermediate},
          rest_after_intermediate
        )

      # Final byte
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        # Pass explicit params, intermediates, final_byte to Emulator
        new_emulator =
          dispatch_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(new_emulator, next_parser_state, rest_after_final)

      # Ignored byte in CSI Param (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in CSI Param")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_ignored)

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in CSI Param")
        # Stay in state, ignore byte
        parse_loop(emulator, parser_state, rest_after_ignored)

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in CSI Param state, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_unhandled)
    end
  end

  # --- CSI Intermediate State ---
  # Accepts emulator, parser_state (matching state: :csi_intermediate), and input
  defp parse_loop(
         emulator,
         %State{state: :csi_intermediate} = parser_state,
         rest
       ) do
    # IO.inspect({:parse_loop_csi_intermediate, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # Collect more intermediate bytes
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        next_parser_state =
          collect_csi_intermediate(parser_state, intermediate_byte)

        parse_loop(emulator, next_parser_state, rest_after_intermediate)

      # Parameter byte or separator
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?; ->
        next_parser_state = accumulate_csi_param(parser_state, param_byte)
        # Transition back to csi_param state to continue collecting params
        parse_loop(
          emulator,
          %{next_parser_state | state: :csi_param},
          rest_after_param
        )

      # Final byte
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        # Pass explicit params, intermediates, final_byte to Emulator
        new_emulator =
          dispatch_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(new_emulator, next_parser_state, rest_after_final)

      # Ignored byte in CSI Intermediate (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in CSI Intermediate")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_ignored)

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in CSI Intermediate")
        # Stay in state, ignore byte
        parse_loop(emulator, parser_state, rest_after_ignored)

      # Unhandled byte (including 0x30-0x3F which VTTest ignores here) - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in CSI Intermediate state, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_unhandled)
    end
  end

  # --- OSC String State ---
  # Accepts emulator, parser_state (matching state: :osc_string), and input
  defp parse_loop(
         emulator,
         %State{state: :osc_string} = parser_state,
         rest
       ) do
    # IO.inspect({:parse_loop_osc_string, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # String Terminator (ST - ESC \) -- Use escape_char check first
      <<27, rest_after_esc::binary>> ->
        parse_loop(
          emulator,
          %{parser_state | state: :osc_string_maybe_st},
          rest_after_esc
        )

      # BEL (7) is another valid terminator for OSC
      <<7, rest_after_bel::binary>> ->
        # Call the new Executor module
        new_emulator =
          Executor.execute_osc_command(
            emulator,
            parser_state.payload_buffer
          )
        # TODO: Actually implement execute_osc_command in the new module
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(new_emulator, next_parser_state, rest_after_bel)

      # CAN/SUB abort OSC string -- MOVED BEFORE C0/DEL catch-all
      <<abort_byte, rest_after_abort::binary>>
      when abort_byte == 0x18 or abort_byte == 0x1A ->
        Logger.debug("Aborting OSC String due to CAN/SUB")
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_abort)

      # Standard printable ASCII
      <<byte, rest_after_byte::binary>> when byte >= 32 and byte <= 126 ->
        next_parser_state = %{
          parser_state
          | payload_buffer: parser_state.payload_buffer <> <<byte>>
        }

        parse_loop(emulator, next_parser_state, rest_after_byte)

      # Ignore C0/DEL bytes within OSC string -- MOVED AFTER CAN/SUB check
      <<_ignored_byte, rest_after_ignored::binary>> ->
        # Includes C0 0-31 and DEL 127 (excluding ESC, BEL, CAN, SUB which are handled above)
        Logger.debug("Ignoring C0/DEL byte in OSC String")
        # Stay in state, ignore byte
        parse_loop(emulator, parser_state, rest_after_ignored)
    end
  end

  # Helper state to check for ST after ESC in OSC String
  defp parse_loop(
         emulator,
         %State{state: :osc_string_maybe_st} = parser_state,
         rest
       ) do
    case rest do
      # Found ST (ESC \), use literal 92 for '\'
      <<92, rest_after_st::binary>> ->
        # Call the new Executor module
        new_emulator =
          Executor.execute_osc_command(
            emulator,
            parser_state.payload_buffer
          )
        # TODO: Actually implement execute_osc_command in the new module
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(new_emulator, next_parser_state, rest_after_st)

      # Not ST
      <<_unexpected_byte, rest_after_unexpected::binary>> ->
        Logger.warning(
          "Malformed OSC termination: ESC not followed by ST. Returning to ground."
        )

        # Discard sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        # Continue parsing AFTER the unexpected byte
        parse_loop(emulator, next_parser_state, rest_after_unexpected)

      # Input ended after ESC, incomplete sequence
      <<>> ->
        Logger.warning(
          "Malformed OSC termination: Input ended after ESC. Returning to ground."
        )

        # Go to ground
        _next_parser_state = %{parser_state | state: :ground}
        # Return emulator as is
        emulator
    end
  end

  # --- DCS Entry State ---
  # Accepts emulator, parser_state (matching state: :dcs_entry), and input
  defp parse_loop(emulator, %State{state: :dcs_entry} = parser_state, rest) do
    # IO.inspect({:parse_loop_dcs_entry, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # Parameter byte (can DCS have parameters? VTTest suggests yes for some)
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?9 ->
        next_parser_state = accumulate_dcs_param(parser_state, param_byte)
        parse_loop(emulator, next_parser_state, rest_after_param)

      # Semicolon parameter separator
      <<?;, rest_after_param::binary>> ->
        next_parser_state = accumulate_dcs_param(parser_state, ?;)
        parse_loop(emulator, next_parser_state, rest_after_param)

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        next_parser_state =
          collect_dcs_intermediate(parser_state, intermediate_byte)

        parse_loop(emulator, next_parser_state, rest_after_intermediate)

      # Final byte (ends DCS header, moves to passthrough)
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        next_parser_state = %{
          parser_state
          | state: :dcs_passthrough,
            final_byte: final_byte,
            payload_buffer: ""
        }

        parse_loop(emulator, next_parser_state, rest_after_final)

      # Ignored byte in DCS Entry (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in DCS Entry")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_ignored)

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in DCS Entry")
        # Stay in state, ignore byte
        parse_loop(emulator, parser_state, rest_after_ignored)

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in DCS Entry state, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_unhandled)
    end
  end

  # --- DCS Passthrough State ---
  # Accepts emulator, parser_state (matching state: :dcs_passthrough), and input
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough} = parser_state,
         rest
       ) do
    # IO.inspect({:parse_loop_dcs_passthrough, parser_state.state, rest}, label: "DEBUG_PARSER")
    case rest do
      # Incomplete
      <<>> ->
        emulator

      # String Terminator (ST - ESC \) -- Use escape_char check first
      <<27, rest_after_esc::binary>> ->
        parse_loop(
          emulator,
          %{parser_state | state: :dcs_passthrough_maybe_st},
          rest_after_esc
        )

      # Collect payload bytes (>= 0x20), excluding DEL (0x7F)
      <<byte, rest_after_byte::binary>> when byte >= 0x20 and byte != 0x7F ->
        next_parser_state = %{
          parser_state
          | payload_buffer: parser_state.payload_buffer <> <<byte>>
        }

        parse_loop(emulator, next_parser_state, rest_after_byte)

      # CAN/SUB abort DCS passthrough
      <<abort_byte, rest_after_abort::binary>>
      when abort_byte == 0x18 or abort_byte == 0x1A ->
        Logger.debug("Aborting DCS Passthrough due to CAN/SUB")
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(emulator, next_parser_state, rest_after_abort)

      # Ignore C0 bytes (0x00-0x1F) and DEL (0x7F) during DCS passthrough
      # (ESC, CAN, SUB handled explicitly)
      <<_ignored_byte, rest_after_ignored::binary>> ->
        Logger.debug("Ignoring C0/DEL byte in DCS Passthrough")
        parse_loop(emulator, parser_state, rest_after_ignored)
    end
  end

  # Helper state to check for ST after ESC in DCS Passthrough
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough_maybe_st} = parser_state,
         rest
       ) do
    case rest do
      # Found ST (ESC \), use literal 92 for '\'
      <<92, rest_after_st::binary>> ->
        # Completed DCS Sequence
        # Call the new Executor module
        new_emulator =
          Executor.execute_dcs_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            parser_state.final_byte,
            parser_state.payload_buffer
          )
        # TODO: Actually implement execute_dcs_command in the new module
        next_parser_state = %{parser_state | state: :ground}
        parse_loop(new_emulator, next_parser_state, rest_after_st)

      # Not ST
      <<_unexpected_byte, rest_after_unexpected::binary>> ->
        Logger.warning(
          "Malformed DCS termination: ESC not followed by ST. Returning to ground."
        )

        # Discard sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        # Continue parsing AFTER the unexpected byte
        parse_loop(emulator, next_parser_state, rest_after_unexpected)

      # Input ended after ESC, incomplete sequence
      <<>> ->
        Logger.warning(
          "Malformed DCS termination: Input ended after ESC. Returning to ground."
        )

        # Go to ground
        _next_parser_state = %{parser_state | state: :ground}
        # Return emulator as is
        emulator
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
  # Dispatches CSI commands based on final byte and intermediates
  defp dispatch_csi_command(
         emulator,
         params_buffer,
         intermediates_buffer,
         final_byte
       ) do
    params = parse_csi_params(params_buffer)
    intermediates = intermediates_buffer

    case {final_byte, intermediates} do
      # SGR - Select Graphic Rendition
      {?m, ""} ->
        sgr_params = if params == [], do: [0], else: params
        handle_sgr(emulator, sgr_params)

      # --- Scrolling ---
      # SU - Scroll Up
      {?S, ""} ->
        count = get_csi_param(params, 1)
        Screen.scroll_up(emulator, count)

      # SD - Scroll Down
      {?T, ""} ->
        count = get_csi_param(params, 1)
        Screen.scroll_down(emulator, count)

      # --- Scrolling Region ---
      # DECSTBM - Set Top and Bottom Margins
      {?r, ""} ->
        handle_set_scroll_region(emulator, params)

      # --- DEC Private Mode Set/Reset ---
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

      # --- Cursor Movement ---
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
        # Move to col 0
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}}
        cursor = Movement.move_down(cursor, count)
        %{emulator | cursor: cursor}

      # CPL - Cursor Previous Line
      {?F, ""} ->
        count = get_csi_param(params, 1)
        cursor = emulator.cursor
        # Move to col 0
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}}
        cursor = Movement.move_up(cursor, count)
        %{emulator | cursor: cursor}

      # CHA - Cursor Horizontal Absolute
      {?G, ""} ->
        col = get_csi_param(params, 1)
        {_, row} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col, row)}

      # VPA - Vertical Position Absolute
      {?d, ""} ->
        row = get_csi_param(params, 1)
        {col, _} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col, row)}

      # --- Editing ---
      # ED - Erase in Display (clear screen)
      {?J, ""} ->
        # Default 0
        n = get_csi_param(params, 1, 0)
        Screen.clear_screen(emulator, n)

      # EL - Erase in Line (clear line)
      {?K, ""} ->
        # Default 0
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

      # --- Cursor Style/Visibility ---
      # DECSCUSR - Set Cursor Style (assuming from intermediate " " and final q)
      {?q, " "} ->
        # Default depends on terminal
        n = get_csi_param(params, 1, 1)
        handle_cursor_style(emulator, n)

      # --- Device Status Reports ---
      # DSR - Device Status Report
      {?n, ""} ->
        n = get_csi_param(params, 1)
        handle_device_status_report(emulator, n)

      # --- Default case ---
      _ ->
        Logger.debug(
          "Unhandled CSI sequence in dispatch: final=#{final_byte}, intermediates=#{inspect(intermediates)}, params=#{inspect(params)}"
        )

        emulator
    end
  end

  # --- ADDED Placeholder Helper Functions ---
  # These need to be implemented based on the logic from the old executor

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

  defp handle_sgr(emulator, params) do
    # Placeholder - Needs logic from old executor's handle_sgr
    # This involves iterating params and applying TextFormatting based on codes
    Logger.debug("SGR called with params: #{inspect(params)}")
    # Example call (incorrect, just placeholder):
    # new_style = Enum.reduce(params, emulator.style, &TextFormatting.apply_attribute/2)
    # %{emulator | style: new_style}
    # Return unchanged for now
    emulator
  end

  defp handle_set_scroll_region(emulator, params) do
    # Placeholder - Needs logic from old executor's handle_set_scroll_region
    Logger.debug("DECSTBM called with params: #{inspect(params)}")
    emulator
  end

  defp handle_cursor_position(emulator, params) do
    # Placeholder - Needs logic from old executor's handle_cursor_position
    Logger.debug("CUP/HVP called with params: #{inspect(params)}")
    emulator
  end

  defp handle_cursor_style(emulator, param) do
    # Placeholder - Needs logic from old executor's handle_cursor_style
    Logger.debug("DECSCUSR called with param: #{inspect(param)}")
    emulator
  end

  defp handle_device_status_report(emulator, param) do
    # Placeholder - Needs logic from old executor's handle_device_status_report
    Logger.debug("DSR called with param: #{inspect(param)}")
    emulator
  end
end
