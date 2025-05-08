defmodule Raxol.Terminal.Commands.DCSHandlers do
  @moduledoc """
  Handles the execution logic for specific DCS commands.

  Functions are called by `Raxol.Terminal.Commands.Executor` after initial parsing.
  """

  alias Raxol.Terminal.Emulator
  # Needed for param parsing if done here
  alias Raxol.Terminal.Commands.Parser
  # Add alias for TextFormatting
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ScreenBuffer
  # For DECRQSS ' q'
  alias Raxol.Terminal.Cursor.Manager
  require Logger

  @doc "Dispatches DCS command execution based on intermediates and final byte."
  @spec handle_dcs(
          Emulator.t(),
          list(integer() | nil),
          String.t(),
          non_neg_integer(),
          String.t()
        ) :: Emulator.t()
  def handle_dcs(
        emulator,
        params,
        intermediates_buffer,
        final_byte,
        data_string
      ) do
    Logger.debug(
      "Handling DCS command: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}, data_len=#{byte_size(data_string)}"
    )

    # --- Dispatch based on params/intermediates/final byte ---
    case {intermediates_buffer, final_byte} do
      # DECRQSS (Request Status String): DCS ! | Pt ST
      # Using final byte | as marker
      {"!", ?|} ->
        handle_decrqss(emulator, data_string)

      # Sixel Graphics: DCS <params> q <data> ST
      # The parser should ideally handle Sixel data streaming separately.
      {_intermediates, ?q} ->
        Logger.debug(
          "DCS Sixel Graphics (Params: #{inspect(params)}, Data Length: #{byte_size(data_string)}) - Stubbed in DCSHandlers"
        )

        # TODO: Pass data_string to the SixelGraphics module/parser state machine
        # This likely involves updating the main Parser state, not direct execution here.
        # Potential call: SixelGraphics.handle_data(emulator.sixel_state, data_string)
        emulator

      # Unhandled DCS
      _ ->
        Logger.warning(
          "Unhandled DCS command in DCSHandlers: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}"
        )

        emulator
    end
  end

  # --- Specific DCS Handlers ---

  @doc "Handles DECRQSS (Request Status String)"
  defp handle_decrqss(emulator, requested_status) do
    Logger.debug("DCS DECRQSS: Request status '#{requested_status}'")

    # Query the emulator state and format the response
    case requested_status do
      # SGR - Graphics Rendition Combination
      "m" ->
        # Format: P1$r<Ps>m   (Ps is semicolon-separated SGR codes)
        sgr_params = TextFormatting.format_sgr_params(emulator.style)
        response_payload = "#{sgr_params}m"
        send_dcs_response(emulator, "1", requested_status, response_payload)

      # DECSTBM - Set Top and Bottom Margins
      "r" ->
        # Format: P1$r<Pt>;<Pb>r (Pt=top, Pb=bottom)
        {top, bottom} =
          emulator.scroll_region ||
            {0,
             ScreenBuffer.get_height(Emulator.get_active_buffer(emulator)) - 1}

        response_payload = "#{top + 1};#{bottom + 1}r"
        send_dcs_response(emulator, "1", requested_status, response_payload)

      # DECSCUSR - Set Cursor Style
      # Note the leading space in the request string
      " q" ->
        # Format: P1$r<Ps> q (Ps=cursor style code)
        # Map the style atom to the DECSCUSR code (using steady codes)
        cursor_style_code =
          case emulator.cursor_style do
            :block -> 2
            :underline -> 4
            :bar -> 6
            # Default/fallback to block if unknown style encountered
            _ -> 2
          end

        response_payload = "#{cursor_style_code} q"
        send_dcs_response(emulator, "1", requested_status, response_payload)

      # TODO: Add more DECRQSS handlers (e.g., DECSLPP, DECSLRM, etc.)
      _ ->
        Logger.warning(
          "DECRQSS: Unsupported status request '#{requested_status}'"
        )

        # Respond with P0$r (invalid/unsupported request)
        send_dcs_response(emulator, "0", requested_status, "")
    end
  end

  # --- Helper Functions (Moved from Executor) ---

  @doc "Sends a formatted DCS response."
  defp send_dcs_response(
         emulator,
         validity,
         _requested_status,
         response_payload
       ) do
    # Format: DCS <validity> ! | <response_payload> ST
    # Note: The original request (e.g., "m") is NOT part of the standard response payload format P...$r...
    # The payload itself contains the terminating character (m, r, q, etc.)
    response_str = "\eP#{validity}!|#{response_payload}\e\\"
    Logger.debug("Sending DCS Response: #{inspect(response_str)}")
    %{emulator | output_buffer: emulator.output_buffer <> response_str}
  end
end
