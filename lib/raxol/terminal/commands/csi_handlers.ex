defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handles the execution logic for specific CSI commands.

  This module serves as the main entry point for CSI command handling,
  delegating to specialized handler modules for different types of commands.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

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
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager, as: CharsetStateManager
  require Raxol.Core.Runtime.Log

  @doc "Handles Select Graphic Rendition (SGR - 'm')"
  @spec handle_m(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_m(emulator, params) do
    Raxol.Core.Runtime.Log.debug("[SGR Handler] Input Style: #{inspect(emulator.style)}, Params: #{inspect(params)}")
    new_style = SGRHandler.apply_sgr_params(params, emulator.style)
    Raxol.Core.Runtime.Log.debug("[SGR Handler] Output Style: #{inspect(new_style)}")
    {:ok, %{emulator | style: new_style}}
  end

  # Delegate cursor movement handlers
  @spec handle_H(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_H(emulator, params), do: CursorHandlers.handle_H(emulator, params)

  @spec handle_A(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_A(emulator, params), do: CursorHandlers.handle_A(emulator, params)

  @spec handle_B(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_B(emulator, params), do: CursorHandlers.handle_B(emulator, params)

  @spec handle_C(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_C(emulator, params), do: CursorHandlers.handle_C(emulator, params)

  @spec handle_D(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_D(emulator, params), do: CursorHandlers.handle_D(emulator, params)

  @spec handle_E(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_E(emulator, params), do: CursorHandlers.handle_E(emulator, params)

  @spec handle_F(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_F(emulator, params), do: CursorHandlers.handle_F(emulator, params)

  @spec handle_G(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_G(emulator, params), do: CursorHandlers.handle_G(emulator, params)

  @spec handle_d(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params), do: CursorHandlers.handle_d(emulator, params)

  # Delegate buffer operation handlers
  @spec handle_L(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_L(emulator, params), do: BufferHandlers.handle_L(emulator, params)

  @spec handle_M(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_M(emulator, params), do: BufferHandlers.handle_M(emulator, params)

  @spec handle_P(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_P(emulator, params), do: BufferHandlers.handle_P(emulator, params)

  @spec handle_at(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_at(emulator, params),
    do: BufferHandlers.handle_at(emulator, params)

  @spec handle_X(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_X(emulator, params), do: BufferHandlers.handle_X(emulator, params)

  @spec handle_S(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_S(emulator, params), do: BufferHandlers.handle_S(emulator, params)

  @spec handle_T(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_T(emulator, params), do: BufferHandlers.handle_T(emulator, params)

  # Delegate erase handlers
  @spec handle_J(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_J(emulator, params), do: EraseHandlers.handle_J(emulator, params)

  @spec handle_K(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_K(emulator, params), do: EraseHandlers.handle_K(emulator, params)

  # Delegate device status handlers
  defdelegate handle_n(emulator, params), to: DeviceHandlers

  defdelegate handle_c(emulator, params, intermediates_buffer),
    to: DeviceHandlers

  # Delegate mode handlers
  defdelegate handle_h_or_l(emulator, params, intermediates_buffer, final_byte),
    to: ModeHandlers

  # Delegate window manipulation handlers
  defdelegate handle_t(emulator, params), to: WindowHandlers

  @doc "Handles Save Cursor (SCP - 's')"
  @spec handle_s(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_s(emulator, _params) do
    {:ok, %{emulator | saved_cursor: emulator.cursor}}
  end

  @doc "Handles Restore Cursor (RCP - 'u')"
  @spec handle_u(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_u(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        Raxol.Core.Runtime.Log.warning_with_context("No saved cursor position to restore", %{})
        {:error, :no_saved_cursor, emulator}

      saved_cursor ->
        {:ok, %{emulator | cursor: saved_cursor}}
    end
  end

  @doc "Handles Set Cursor Style (DECSCUSR - 'q')"
  @spec handle_q_deccusr(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_q_deccusr(emulator, params) do
    style = ParameterValidation.get_valid_non_neg_param(params, 0, 0)
    cursor_style = map_cursor_style(style, emulator.cursor.style)
    {:ok, %{emulator | cursor: %{emulator.cursor | style: cursor_style}}}
  end

  # Helper function to map cursor style code to style atom
  @spec map_cursor_style(non_neg_integer(), CursorManager.style()) ::
          CursorManager.style()
  defp map_cursor_style(style, current_style) do
    case style do
      0 ->
        :blink_block

      1 ->
        :blink_block

      2 ->
        :steady_block

      3 ->
        :blink_underline

      4 ->
        :steady_underline

      5 ->
        :blink_bar

      6 ->
        :steady_bar

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context("Unknown cursor style: #{style}", %{})
        current_style
    end
  end

  @doc "Handles Designate Character Set (SCS - via non-standard CSI sequences)"
  @spec handle_scs(Emulator.t(), String.t(), char()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_scs(emulator, charset_param_str, final_byte) do
    actual_param_str =
      if charset_param_str == "", do: "B", else: charset_param_str

    charset_code =
      String.at(actual_param_str, 0) |> String.to_charlist() |> List.first()

    target_gset_key =
      case final_byte do
        ?( ->
          :g0

        ?) ->
          :g1

        ?* ->
          :g2

        ?+ ->
          :g3

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context("SCS: Unexpected final_byte: #{inspect(final_byte)}", %{})
          nil
      end

    charset_atom = CharsetStateManager.charset_code_to_atom(charset_code)

    if target_gset_key && charset_atom do
      Raxol.Core.Runtime.Log.debug(
        "SCS: Designating #{inspect(target_gset_key)} to charset #{inspect(charset_atom)} (from char code #{charset_code})"
      )

      updated_charset_state =
        Map.put(emulator.charset_state, target_gset_key, charset_atom)

      {:ok, %{emulator | charset_state: updated_charset_state}}
    else
      msg = "SCS: Failed to designate charset. Param: '#{charset_param_str}', Char Code: #{inspect(charset_code)}, Final Byte: #{<<final_byte::utf8>>}, Mapped Charset: #{inspect(charset_atom)}, Target GSet: #{inspect(target_gset_key)}"
      Raxol.Core.Runtime.Log.warning_with_context(msg, %{})

      {:error, :invalid_charset_designation, emulator}
    end
  end

  @doc "Handles DECSTBM (Set Scrolling Region - 'r')"
  @spec handle_r(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_r(emulator, params) do
    height = emulator.height
    top = Enum.at(params, 0, 1) - 1
    bottom = Enum.at(params, 1, height) - 1
    valid_region = top >= 0 and bottom < height and top < bottom
    is_full_screen = top == 0 and bottom == height - 1
    new_cursor = %{emulator.cursor | position: {0, 0}}

    if valid_region and not is_full_screen do
      {:ok, %{emulator | scroll_region: {top, bottom}, cursor: new_cursor}}
    else
      {:ok, %{emulator | scroll_region: nil, cursor: new_cursor}}
    end
  end
end
