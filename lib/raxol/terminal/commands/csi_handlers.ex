defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.CSIHandlers.{Basic, Cursor, Screen, Device}
  require Raxol.Core.Runtime.Log

  @private_modes %{
    1 => :cursor_keys,
    2 => :ansi,
    3 => :column_132,
    4 => :smooth_scroll,
    5 => :reverse_video,
    6 => :origin,
    7 => :auto_wrap,
    8 => :auto_repeat,
    9 => :interlacing,
    12 => :blinking_cursor,
    25 => :show_cursor,
    47 => :alternate_screen,
    1049 => :alternate_screen_buffer
  }

  @charsets %{
    ?0 => :us_ascii,
    ?1 => :dec_special,
    ?2 => :dec_supplementary,
    ?3 => :dec_technical,
    ?4 => :dec_supplementary_graphics,
    ?5 => :dec_supplementary_ipa,
    ?6 => :dec_supplementary_arabic,
    ?7 => :dec_supplementary_hebrew,
    ?8 => :dec_supplementary_latin1,
    ?9 => :dec_supplementary_latin2
  }

  @public_modes %{
    2 => :keyboard_action,
    4 => :insert_mode,
    12 => :send_receive,
    20 => :new_line,
    34 => :cursor_style,
    36 => :keyboard_type,
    40 => :allow_80_to_132,
    42 => :more_fix,
    44 => :turn_off_margin_bell,
    66 => :application_keypad
  }

  def handle_basic_command(emulator, params, byte) do
    Basic.handle_command(emulator, params, byte)
  end

  def handle_cursor_command(emulator, params, byte) do
    Cursor.handle_command(emulator, params, byte)
  end

  def handle_screen_command(emulator, params, byte) do
    Screen.handle_command(emulator, params, byte)
  end

  def handle_device_command(emulator, params, intermediates_buffer, byte) do
    Device.handle_command(emulator, params, intermediates_buffer, byte)
  end

  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    case intermediates_buffer do
      "?" -> handle_private_mode(emulator, params, final_byte)
      _ -> handle_public_mode(emulator, params, final_byte)
    end
  end

  def handle_deccusr(emulator, params) do
    Basic.handle_decscusr(emulator, params)
  end

  @doc """
  Handles DECCUSR (DEC Cursor Style Report) command.
  This is an alias for handle_deccusr/2 for backward compatibility.
  """
  def handle_q_deccusr(emulator, params) do
    handle_deccusr(emulator, params)
  end

  @doc """
  Handles SCS (Select Character Set) command.
  The final_byte parameter determines which character set to select.
  """
  @spec handle_scs(Emulator.t(), list(integer()), integer()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_scs(emulator, _params, final_byte) do
    case Map.get(@charsets, final_byte) do
      nil -> {:error, :invalid_charset, emulator}
      charset -> Emulator.set_charset(emulator, charset)
    end
  end

  # Private mode handlers
  defp handle_private_mode(emulator, [mode], final_byte) do
    case Map.get(@private_modes, mode) do
      nil ->
        {:ok, emulator}

      mode_name ->
        case final_byte do
          ?h -> Emulator.set_mode(emulator, mode_name)
          ?l -> Emulator.reset_mode(emulator, mode_name)
        end
    end
  end

  defp handle_public_mode(emulator, [mode], final_byte) do
    case Map.get(@public_modes, mode) do
      nil ->
        {:ok, emulator}

      mode_name ->
        case final_byte do
          ?h -> Emulator.set_mode(emulator, mode_name)
          ?l -> Emulator.reset_mode(emulator, mode_name)
        end
    end
  end
end
