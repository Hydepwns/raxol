defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handles the execution logic for specific CSI commands.

  This module serves as the main entry point for CSI command handling,
  delegating to specialized handler modules for different types of commands.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.{
    CursorHandlers,
    BufferHandlers,
    EraseHandlers,
    DeviceHandlers,
    ModeHandlers,
    WindowHandlers,
    ParameterValidation
  }
  alias Raxol.Terminal.ANSI.SGRHandler
  require Logger

  @doc "Handles Select Graphic Rendition (SGR - 'm')"
  @spec handle_m(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_m(emulator, params) do
    Logger.debug("[SGR Handler] Input Style: #{inspect(emulator.style)}, Params: #{inspect(params)}")
    new_style = SGRHandler.apply_sgr_params(params, emulator.style)
    Logger.debug("[SGR Handler] Output Style: #{inspect(new_style)}")
    %{emulator | style: new_style}
  end

  # Delegate cursor movement handlers
  defdelegate handle_H(emulator, params), to: CursorHandlers
  defdelegate handle_A(emulator, params), to: CursorHandlers
  defdelegate handle_B(emulator, params), to: CursorHandlers
  defdelegate handle_C(emulator, params), to: CursorHandlers
  defdelegate handle_D(emulator, params), to: CursorHandlers
  defdelegate handle_E(emulator, params), to: CursorHandlers
  defdelegate handle_F(emulator, params), to: CursorHandlers
  defdelegate handle_G(emulator, params), to: CursorHandlers
  defdelegate handle_d(emulator, params), to: CursorHandlers

  # Delegate buffer operation handlers
  defdelegate handle_L(emulator, params), to: BufferHandlers
  defdelegate handle_M(emulator, params), to: BufferHandlers
  defdelegate handle_P(emulator, params), to: BufferHandlers
  defdelegate handle_at(emulator, params), to: BufferHandlers
  defdelegate handle_X(emulator, params), to: BufferHandlers

  # Delegate erase handlers
  defdelegate handle_J(emulator, params), to: EraseHandlers
  defdelegate handle_K(emulator, params), to: EraseHandlers

  # Delegate device status handlers
  defdelegate handle_n(emulator, params), to: DeviceHandlers
  defdelegate handle_c(emulator, params, intermediates_buffer), to: DeviceHandlers

  # Delegate mode handlers
  defdelegate handle_h_or_l(emulator, params, intermediates_buffer, final_byte), to: ModeHandlers

  # Delegate window manipulation handlers
  defdelegate handle_t(emulator, params), to: WindowHandlers

  @doc "Handles Save Cursor (SCP - 's')"
  @spec handle_s(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_s(emulator, _params) do
    # Save cursor position and attributes
    %{emulator | saved_cursor: emulator.cursor}
  end

  @doc "Handles Restore Cursor (RCP - 'u')"
  @spec handle_u(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_u(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        Logger.warning("No saved cursor position to restore")
        emulator

      saved_cursor ->
        %{emulator | cursor: saved_cursor}
    end
  end

  @doc "Handles Set Cursor Style (DECSCUSR - 'q')"
  @spec handle_q_deccusr(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_q_deccusr(emulator, params) do
    style = ParameterValidation.get_valid_non_neg_param(params, 0, 0)
    cursor_style = map_cursor_style(style, emulator.cursor.style)
    %{emulator | cursor: %{emulator.cursor | style: cursor_style}}
  end

  # Helper function to map cursor style code to style atom
  @spec map_cursor_style(non_neg_integer(), CursorManager.style()) :: CursorManager.style()
  defp map_cursor_style(style, current_style) do
    case style do
      0 -> :blink_block
      1 -> :blink_block
      2 -> :steady_block
      3 -> :blink_underline
      4 -> :steady_underline
      5 -> :blink_bar
      6 -> :steady_bar
      _ ->
        Logger.warning("Unknown cursor style: #{style}")
        current_style
    end
  end

  @doc "Handles Designate Character Set (SCS - '(', ')', '*', '+')"
  @spec handle_scs(Emulator.t(), list(integer()), char()) :: Emulator.t()
  def handle_scs(emulator, params, final_byte) do
    code = ParameterValidation.get_valid_non_neg_param(params, 0, 0)
    charset = map_charset_code(code, final_byte)

    if charset do
      %{emulator | charset_state: %{emulator.charset_state | current_charset: charset}}
    else
      Logger.warning("Unknown charset code: #{code} for final byte: #{final_byte}")
      emulator
    end
  end

  # Helper function to map charset code to charset atom
  @spec map_charset_code(non_neg_integer(), char()) :: atom() | nil
  defp map_charset_code(code, final_byte) do
    case {code, final_byte} do
      {0, ?(} -> :us_ascii
      {0, ?)} -> :us_ascii
      {0, ?*} -> :us_ascii
      {0, ?+} -> :us_ascii
      {1, ?(} -> :dec_supplementary
      {1, ?)} -> :dec_supplementary
      {1, ?*} -> :dec_supplementary
      {1, ?+} -> :dec_supplementary
      {2, ?(} -> :dec_special_graphics
      {2, ?)} -> :dec_special_graphics
      {2, ?*} -> :dec_special_graphics
      {2, ?+} -> :dec_special_graphics
      {3, ?(} -> :dec_supplementary_graphics
      {3, ?)} -> :dec_supplementary_graphics
      {3, ?*} -> :dec_supplementary_graphics
      {3, ?+} -> :dec_supplementary_graphics
      {4, ?(} -> :dec_technical
      {4, ?)} -> :dec_technical
      {4, ?*} -> :dec_technical
      {4, ?+} -> :dec_technical
      _ -> nil
    end
  end

  @doc "Handles DECSTBM (Set Scrolling Region - 'r')"
  @spec handle_r(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_r(emulator, params) do
    height = emulator.height
    top = (Enum.at(params, 0, 1)) - 1
    bottom = (Enum.at(params, 1, height)) - 1

    valid_region = top >= 0 and bottom < height and top < bottom
    is_full_screen = top == 0 and bottom == height - 1
    new_cursor = %{emulator.cursor | position: {0, 0}}

    if valid_region and not is_full_screen do
      %{emulator | scroll_region: {top, bottom}, cursor: new_cursor}
    else
      %{emulator | scroll_region: nil, cursor: new_cursor}
    end
  end
end
