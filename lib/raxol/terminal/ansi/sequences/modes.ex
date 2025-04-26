defmodule Raxol.Terminal.ANSI.Sequences.Modes do
  @moduledoc """
  ANSI Terminal Modes Sequence Handler.

  Handles parsing and application of ANSI terminal mode sequences,
  including screen modes, input modes, and rendering modes.
  """

  alias Raxol.Terminal.ANSI.ScreenModes
  require Logger

  @doc """
  Set or reset a screen mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `mode` - Mode identifier
  * `enabled` - Boolean indicating if mode should be enabled or disabled

  ## Returns

  Updated emulator state
  """
  def set_screen_mode(emulator, mode, enabled) do
    case ScreenModes.get_mode(mode) do
      nil ->
        Logger.debug("Unknown screen mode: #{mode}")
        emulator

      mode_def ->
        mode_name = mode_def.name

        # Update the screen modes map in the emulator state
        updated_modes = Map.put(emulator.screen_modes, mode_name, enabled)
        emulator = %{emulator | screen_modes: updated_modes}

        # Handle special mode actions if needed
        handle_special_mode_action(emulator, mode_name, enabled)
    end
  end

  @doc """
  Handle special mode actions that require additional state changes.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `mode_name` - The name of the mode
  * `enabled` - Boolean indicating if mode is enabled or disabled

  ## Returns

  Updated emulator state
  """
  def handle_special_mode_action(emulator, mode_name, enabled) do
    case {mode_name, enabled} do
      {:alternate_screen, true} ->
        # Switch to alternate screen buffer
        %{emulator | active_buffer_type: :alternate}

      {:alternate_screen, false} ->
        # Switch back to main screen buffer
        %{emulator | active_buffer_type: :main}

      {:origin_mode, _} ->
        # Reset cursor position when origin mode changes
        %{emulator | cursor_x: 0, cursor_y: 0}

      {:cursor_visible, enabled} ->
        # Update cursor visibility
        %{emulator | cursor_visible: enabled}

      {:auto_wrap, _} ->
        # Auto-wrap mode only affects text output behavior, no state change needed
        emulator

      {:insert_mode, _} ->
        # Insert mode affects text insertion behavior, no state change needed
        emulator

      {:bracketed_paste, _} ->
        # Bracketed paste affects input handling, no state change needed
        emulator

      {:mouse_tracking, _} ->
        # Mouse tracking affects input handling, no state change needed
        emulator

      {:focus_events, _} ->
        # Focus events affects window behavior, no state change needed
        emulator

      _ ->
        # Other modes don't require special handling
        emulator
    end
  end

  @doc """
  Enable or disable bracketed paste mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `enabled` - Boolean indicating if mode should be enabled or disabled

  ## Returns

  Updated emulator state
  """
  def set_bracketed_paste_mode(emulator, enabled) do
    %{emulator | bracketed_paste_mode: enabled}
  end

  @doc """
  Enable or disable focus reporting.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `enabled` - Boolean indicating if mode should be enabled or disabled

  ## Returns

  Updated emulator state
  """
  def set_focus_reporting(emulator, enabled) do
    %{emulator | focus_reporting: enabled}
  end

  @doc """
  Switch to alternate buffer mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `use_alternate` - Boolean indicating if alternate buffer should be used

  ## Returns

  Updated emulator state
  """
  def set_alternate_buffer(emulator, use_alternate) do
    buffer_type = if use_alternate, do: :alternate, else: :main
    %{emulator | active_buffer_type: buffer_type}
  end
end
