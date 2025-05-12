defmodule Raxol.Terminal.Commands.ModeHandlers do
  @moduledoc """
  Handles mode setting and resetting related CSI commands.

  This module contains handlers for setting and resetting terminal modes,
  both standard ANSI modes and DEC private modes. Each function takes the
  current emulator state and parsed parameters, returning the updated
  emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager
  require Logger

  @doc """
  Handles Set Mode (SM - `h`) or Reset Mode (RM - `l`).

  Dispatches to `ModeManager` to handle both standard ANSI modes and
  DEC private modes (prefixed with `?`).
  """
  @spec handle_h_or_l(Emulator.t(), list(integer()), String.t(), char()) :: Emulator.t()
  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    action = if final_byte == ?h, do: :set, else: :reset
    apply_mode_func = if action == :set, do: &ModeManager.set_mode/2, else: &ModeManager.reset_mode/2

    if intermediates_buffer == "?" do
      handle_dec_private_mode(emulator, params, apply_mode_func, action)
    else
      handle_standard_mode(emulator, params, apply_mode_func, action)
    end
  end

  # Helper function to handle DEC private modes
  @spec handle_dec_private_mode(Emulator.t(), list(integer()), function(), :set | :reset) :: Emulator.t()
  defp handle_dec_private_mode(emulator, params, apply_mode_func, action) do
    # Process each mode parameter
    Enum.reduce(params, emulator, fn param, acc ->
      case param do
        # Cursor Keys Mode (DECCKM)
        1 ->
          apply_mode_func.(acc, [:cursor_keys])

        # ANSI/VT52 Mode (DECANM)
        2 ->
          apply_mode_func.(acc, [:ansi_mode])

        # Column Mode (DECCOLM)
        3 ->
          apply_mode_func.(acc, [:column_mode])

        # Scrolling Mode (DECSCLM)
        4 ->
          apply_mode_func.(acc, [:smooth_scroll])

        # Screen Mode (DECSCNM)
        5 ->
          apply_mode_func.(acc, [:reverse_video])

        # Origin Mode (DECOM)
        6 ->
          apply_mode_func.(acc, [:origin_mode])

        # Auto Wrap Mode (DECAWM)
        7 ->
          apply_mode_func.(acc, [:auto_wrap])

        # Auto Repeat Mode (DECARM)
        8 ->
          apply_mode_func.(acc, [:auto_repeat])

        # Interlace Mode (DECINLM)
        9 ->
          apply_mode_func.(acc, [:interlace])

        # Line Feed/New Line Mode (DECLNM)
        20 ->
          apply_mode_func.(acc, [:line_feed_new_line])

        # Cursor Blinking (DECSCUSR)
        12 ->
          apply_mode_func.(acc, [:cursor_blink])

        # Cursor Visibility (DECTCEM)
        25 ->
          apply_mode_func.(acc, [:cursor_visible])

        # Bracketed Paste Mode
        2004 ->
          apply_mode_func.(acc, [:bracketed_paste])

        # Focus Reporting Mode
        1004 ->
          apply_mode_func.(acc, [:focus_reporting])

        _ ->
          Logger.warning("Unknown DEC private mode: #{param}")
          acc
      end
    end)
  end

  # Helper function to handle standard ANSI modes
  @spec handle_standard_mode(Emulator.t(), list(integer()), function(), :set | :reset) :: Emulator.t()
  defp handle_standard_mode(emulator, params, apply_mode_func, action) do
    # Process each mode parameter
    Enum.reduce(params, emulator, fn param, acc ->
      case param do
        # Keyboard Action Mode (KAM)
        2 ->
          apply_mode_func.(acc, [:keyboard_action])

        # Insert/Replace Mode (IRM)
        4 ->
          apply_mode_func.(acc, [:insert_mode])

        # Send/Receive Mode (SRM)
        12 ->
          apply_mode_func.(acc, [:send_receive])

        # Echo Mode (ERM)
        20 ->
          apply_mode_func.(acc, [:echo])

        _ ->
          Logger.warning("Unknown standard mode: #{param}")
          acc
      end
    end)
  end

  # --- Parameter Validation Helpers ---

  @doc """
  Gets a parameter value with validation.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_param(list(integer() | nil), non_neg_integer(), integer(), integer(), integer()) :: integer()
  defp get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value
      _ ->
        Logger.warning("Invalid parameter value at index #{index}, using default #{default}")
        default
    end
  end

  @doc """
  Gets a parameter value with validation for non-negative integers.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_non_neg_param(list(integer() | nil), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp get_valid_non_neg_param(params, index, default) do
    get_valid_param(params, index, default, 0, 9999)
  end
end
