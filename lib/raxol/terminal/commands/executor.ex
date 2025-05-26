defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc """
  Executes parsed terminal commands (CSI, OSC, DCS).

  This module takes parsed command details and the current emulator state,
  and returns the updated emulator state after applying the command's effects.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Commands.DCSHandlers
  require Raxol.Core.Runtime.Log

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  This function delegates to handler modules (e.g., CSIHandlers, CursorHandlers, etc.).
  To add support for new CSI commands, implement them in the appropriate handler module.
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

    result =
      case final_byte do
        # Delegate to CSIHandlers, passing emulator and parsed params
        ?m ->
          CSIHandlers.handle_m(emulator, params)

        ?H ->
          CSIHandlers.handle_H(emulator, params)

        ?r ->
          CSIHandlers.handle_r(emulator, params)

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

        ?c ->
          CSIHandlers.handle_c(emulator, params, intermediates_buffer)

        ?n ->
          CSIHandlers.handle_n(emulator, params)

        ?q when intermediates_buffer == " " ->
          CSIHandlers.handle_q_deccusr(emulator, params)

        ?s ->
          CSIHandlers.handle_s(emulator, params)

        ?u ->
          CSIHandlers.handle_u(emulator, params)

        ?t ->
          CSIHandlers.handle_t(emulator, params)

        final_byte when final_byte in [?(, ?), ?*, ?+] ->
          CSIHandlers.handle_scs(emulator, params_buffer, final_byte)

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context("Unknown CSI command: #{inspect(final_byte)}", %{})
          {:error, :unhandled_csi, emulator}
      end

    case result do
      {:ok, new_emulator} ->
        new_emulator

      {:error, reason, new_emulator} ->
        Raxol.Core.Runtime.Log.error("CSI handler error: #{inspect(reason)}")
        new_emulator

      %Emulator{} = new_emulator ->
        new_emulator
    end
  end

  @doc """
  Executes an OSC (Operating System Command).

  Params: `command_string` (the content between OSC and ST).
  """
  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Raxol.Core.Runtime.Log.debug("Executing OSC command: #{inspect(command_string)}")

    result =
      case String.split(command_string, ";", parts: 2) do
        # Ps ; Pt format
        [ps_str, pt] ->
          case Integer.parse(ps_str) do
            {ps_code, ""} ->
              # Dispatch based on Ps parameter code
              case ps_code do
                0 ->
                  OSCHandlers.handle_0_or_2(emulator, pt)

                1 ->
                  OSCHandlers.handle_1(emulator, pt)

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

                _ ->
                  Raxol.Core.Runtime.Log.warning_with_context("Unknown OSC command code: #{ps_code}, String: '#{command_string}'", %{})
                  {:error, :unhandled_osc, emulator}
              end

            # Failed to parse Ps as integer
            _ ->
              Raxol.Core.Runtime.Log.warning_with_context("Invalid OSC command code: '#{ps_str}', String: '#{command_string}'", %{})
              {:error, :invalid_osc_code, emulator}
          end

        # Handle OSC sequences with no parameters (e.g., some color requests)
        # Or potentially malformed sequences
        _ ->
          Raxol.Core.Runtime.Log.warning_with_context("OSC: Unexpected command format: '#{command_string}'", %{})
          {:error, :malformed_osc, emulator}
      end

    case result do
      {:ok, new_emulator} ->
        new_emulator

      {:error, reason, new_emulator} ->
        Raxol.Core.Runtime.Log.error("OSC handler error: #{inspect(reason)}")
        new_emulator

      %Emulator{} = new_emulator ->
        new_emulator
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

    result =
      DCSHandlers.handle_dcs(
        emulator,
        params,
        intermediates_buffer,
        final_byte,
        data_string
      )

    case result do
      {:ok, new_emulator} ->
        new_emulator

      {:error, reason, new_emulator} ->
        Raxol.Core.Runtime.Log.error("DCS handler error: #{inspect(reason)}")
        new_emulator

      %Emulator{} = new_emulator ->
        new_emulator
    end
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
    Raxol.Core.Runtime.Log.debug("Sending DCS Response: #{inspect(response_str)}")
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
