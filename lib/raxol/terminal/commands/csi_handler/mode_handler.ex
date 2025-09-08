defmodule Raxol.Terminal.Commands.CSIHandler.ModeHandlers do
  @moduledoc """
  Handlers for mode-related CSI commands.
  """

  alias Raxol.Terminal.Emulator
  require Logger

  @private_modes %{
    1 => :decckm,
    2 => :ansi,
    3 => :deccolm_132,
    4 => :smooth_scroll,
    5 => :decscnm,
    6 => :decom,
    7 => :decawm,
    8 => :decarm,
    9 => :decinlm,
    12 => :att_blink,
    25 => :dectcem,
    47 => :dec_alt_screen,
    1000 => :mouse_report_x10,
    1002 => :mouse_report_cell_motion,
    1004 => :focus_events,
    1006 => :mouse_report_sgr,
    1047 => :dec_alt_screen_save,
    1048 => :decsc_deccara,
    1049 => :alt_screen_buffer,
    2004 => :bracketed_paste
  }

  @public_modes %{
    2 => :keyboard_action,
    4 => :irm,
    12 => :send_receive,
    20 => :lnm,
    34 => :cursor_style,
    36 => :keyboard_type,
    40 => :allow_80_to_132,
    42 => :more_fix,
    44 => :turn_off_margin_bell,
    66 => :application_keypad
  }

  @doc """
  Handles h or l commands (mode setting/resetting).
  """
  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    Logger.debug(
      "CSIHandler.handle_h_or_l called with params=#{inspect(params)}, intermediates_buffer=#{inspect(intermediates_buffer)}, final_byte=#{inspect(final_byte)}"
    )

    case intermediates_buffer do
      "?" -> handle_private_mode(emulator, params, final_byte)
      _ -> handle_public_mode(emulator, params, final_byte)
    end
  end

  defp handle_private_mode(emulator, [mode], final_byte) do
    Logger.debug(
      "handle_private_mode: mode=#{inspect(mode)}, final_byte=#{inspect(final_byte)}"
    )

    case Map.get(@private_modes, mode) do
      nil ->
        Logger.debug(
          "handle_private_mode: mode #{inspect(mode)} not found in @private_modes"
        )

        emulator

      mode_name ->
        Logger.debug(
          "handle_private_mode: found mode_name=#{inspect(mode_name)}"
        )

        case final_byte do
          ?h ->
            Logger.debug(
              "handle_private_mode: calling Emulator.set_mode(emulator, #{inspect(mode_name)})"
            )

            result = Emulator.set_mode(emulator, mode_name)

            Logger.debug(
              "handle_private_mode: Emulator.set_mode returned #{inspect(result)}"
            )

            result

          ?l ->
            Logger.debug(
              "handle_private_mode: calling Emulator.reset_mode(emulator, #{inspect(mode_name)})"
            )

            result = Emulator.reset_mode(emulator, mode_name)

            Logger.debug(
              "handle_private_mode: Emulator.reset_mode returned #{inspect(result)}"
            )

            result
        end
    end
  end

  defp handle_public_mode(emulator, [mode], final_byte) do
    mode_name = Map.get(@public_modes, mode)

    Logger.debug(
      "handle_public_mode: mode=#{inspect(mode)}, mode_name=#{inspect(mode_name)}, final_byte=#{inspect(final_byte)}, type=#{inspect(is_integer(final_byte))}"
    )

    case mode_name do
      nil ->
        emulator

      _ ->
        case final_byte do
          ?h ->
            Raxol.Terminal.Emulator.set_mode(emulator, mode_name)

          ?l ->
            Raxol.Terminal.Emulator.reset_mode(emulator, mode_name)

          _ ->
            Logger.debug(
              "handle_public_mode: Unhandled final_byte #{inspect(final_byte)}"
            )

            emulator
        end
    end
  end

  @doc """
  Handles mode changes.
  """
  def handle_mode_change(emulator, mode, enabled) do
    case get_mode_name(mode) do
      nil -> emulator
      mode_name -> set_or_reset_mode(emulator, mode_name, enabled)
    end
  end

  defp get_mode_name(mode) do
    Map.get(@public_modes, mode) || Map.get(@private_modes, mode)
  end

  defp set_or_reset_mode(emulator, mode_name, enabled) do
    result =
      case enabled do
        true -> Emulator.set_mode(emulator, mode_name)
        false -> Emulator.reset_mode(emulator, mode_name)
      end

    case result do
      {:ok, new_emulator} -> new_emulator
      {:error, _} -> emulator
    end
  end
end
