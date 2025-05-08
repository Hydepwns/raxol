defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc """
  Executes parsed terminal commands (CSI, OSC, DCS).

  This module takes parsed command details and the current emulator state,
  and returns the updated emulator state after applying the command's effects.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.System.Clipboard
  alias Raxol.Terminal.ANSI.SixelGraphics
  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Commands.DCSHandlers
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

    # Dispatch based on final byte to the CSIHandlers module
    case final_byte do
      # Delegate to CSIHandlers, passing emulator and parsed params
      ?m ->
        CSIHandlers.handle_m(emulator, params)

      ?H ->
        CSIHandlers.handle_H(emulator, params)

      ?r ->
        CSIHandlers.handle_r(emulator, params)

      # 'h' - Set Mode (SM)
      # 'l' - Reset Mode (RM)
      final_byte when final_byte in [?h, ?l] ->
        CSIHandlers.handle_h_or_l(
          emulator,
          params,
          intermediates_buffer,
          final_byte
        )

      ?J ->
        CSIHandlers.handle_J(emulator, params)

      ?K ->
        CSIHandlers.handle_K(emulator, params)

      ?A ->
        CSIHandlers.handle_A(emulator, params)

      ?B ->
        CSIHandlers.handle_B(emulator, params)

      ?C ->
        CSIHandlers.handle_C(emulator, params)

      ?D ->
        CSIHandlers.handle_D(emulator, params)

      ?E ->
        CSIHandlers.handle_E(emulator, params)

      ?F ->
        CSIHandlers.handle_F(emulator, params)

      ?G ->
        CSIHandlers.handle_G(emulator, params)

      ?d ->
        CSIHandlers.handle_d(emulator, params)

      ?L ->
        CSIHandlers.handle_L(emulator, params)

      ?M ->
        CSIHandlers.handle_M(emulator, params)

      ?P ->
        CSIHandlers.handle_P(emulator, params)

      ?@ ->
        CSIHandlers.handle_at(emulator, params)

      ?S ->
        CSIHandlers.handle_S(emulator, params)

      ?T ->
        CSIHandlers.handle_T(emulator, params)

      ?X ->
        CSIHandlers.handle_X(emulator, params)

      # 'c' - Send Device Attributes (DA)
      ?c ->
        CSIHandlers.handle_c(emulator, params, intermediates_buffer)

      # 'n' - Device Status Report (DSR)
      ?n ->
        CSIHandlers.handle_n(emulator, params)

      # 'q' - Set cursor style (DECSCUSR, requires space intermediate)
      ?q when intermediates_buffer == " " ->
        CSIHandlers.handle_q_deccusr(emulator, params)

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
              # Delegate to OSCHandlers
              0 ->
                OSCHandlers.handle_0_or_2(emulator, pt)

              2 ->
                OSCHandlers.handle_0_or_2(emulator, pt)

              4 ->
                OSCHandlers.handle_4(emulator, pt)

              7 ->
                OSCHandlers.handle_7(emulator, pt)

              8 ->
                OSCHandlers.handle_8(emulator, pt)

              52 ->
                OSCHandlers.handle_52(emulator, pt)

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
                    # Not storing hyperlink state currently
                    emulator

                  # Handle cases with missing params: OSC 8;;uri ST (common)
                  # Or just uri without params: OSC 8;uri ST (allowed?)
                  # Treat as just URI for now if only one part
                  [uri] ->
                    Logger.debug("OSC 8: Hyperlink: URI='#{uri}', No Params")
                    # Not storing hyperlink state currently
                    emulator

                  # Handle malformed OSC 8
                  _ ->
                    Logger.warning(
                      "Malformed OSC 8 sequence: '#{command_string}'"
                    )

                    emulator
                end

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
  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t()
        ) ::
          Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte,
        data_string
      ) do
    # Parse parameters (similar to CSI)
    params = Parser.parse_params(params_buffer)

    # Delegate to DCSHandlers
    DCSHandlers.handle_dcs(
      emulator,
      params,
      intermediates_buffer,
      final_byte,
      data_string
    )
  end

  # ============================================================================
  # == Helper Functions
  # ============================================================================

  # --- DCS Response Helper ---

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
    params =
      case attrs.fg do
        {:ansi, n} when n >= 0 and n <= 7 -> [30 + n | params]
        {:ansi, n} when n >= 8 and n <= 15 -> [90 + (n - 8) | params]
        {:color_256, n} -> [38, 5, n | params]
        {:rgb, r, g, b} -> [38, 2, r, g, b | params]
        :default -> params
      end

    # Add background color
    params =
      case attrs.bg do
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
