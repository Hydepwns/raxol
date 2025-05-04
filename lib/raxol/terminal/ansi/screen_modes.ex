defmodule Raxol.Terminal.ANSI.ScreenModes do
  @moduledoc """
  Handles screen mode transitions and state management.
  This includes alternate screen buffer, cursor visibility,
  line wrapping, and other terminal modes.
  """

  require Logger

  @type screen_mode ::
          :normal | :alternate | :application | :origin | :insert | :replace

  @type screen_state :: %{
          mode: screen_mode(),
          cursor_visible: boolean(),
          auto_wrap: boolean(),
          origin_mode: boolean(),
          insert_mode: boolean(),
          line_feed_mode: boolean(),
          column_width_mode: :normal | :wide,
          auto_repeat_mode: boolean(),
          interlacing_mode: boolean(),
          saved_state: map() | nil
        }

  # DEC Private Mode codes and their corresponding mode atoms
  @dec_private_modes %{
    # Cursor Keys Mode
    1 => :decckm,
    # 132 Column Mode
    3 => :deccolm_132,
    # Screen Mode (reverse)
    5 => :decscnm,
    # Origin Mode
    6 => :decom,
    # Auto Wrap Mode
    7 => :decawm,
    # Auto Repeat Mode
    8 => :decarm,
    # Interlace Mode
    9 => :decinlm,
    # Start Blinking Cursor
    12 => :att_blink,
    # Text Cursor Enable Mode
    25 => :dectcem,
    # Use Alternate Screen Buffer (Simple)
    47 => :dec_alt_screen,
    # Send Mouse X & Y on button press
    1000 => :mouse_report,
    # Use Cell Motion Mouse Tracking
    1002 => :mouse_motion,
    # Send FocusIn/FocusOut events
    1004 => :focus_events,
    # SGR Mouse Mode
    1006 => :sgr_mouse,
    # Use Alt Screen, Save/Restore State (no clear)
    1047 => :dec_alt_screen_save,
    # Save/Restore Cursor Position
    1048 => :decsc,
    # Use Alt Screen, Save/Restore State, Clear on switch
    1049 => :alt_screen_buffer
  }

  # Standard Mode codes and their corresponding mode atoms
  @standard_modes %{
    # Insert Mode
    4 => :insert_mode,
    # Line Feed Mode
    20 => :line_feed_mode
  }

  alias Raxol.Terminal.{Emulator, ScreenBuffer, Cell}
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TerminalState
  require Raxol.Terminal.ANSI.TerminalState

  @doc """
  Creates a new screen state with default values.
  """
  @spec new() :: %{
          mode: :normal,
          cursor_visible: true,
          auto_wrap: true,
          origin_mode: false,
          insert_mode: false,
          line_feed_mode: false,
          column_width_mode: :normal,
          auto_repeat_mode: false,
          interlacing_mode: false,
          saved_state: nil
        }
  def new do
    %{
      mode: :normal,
      cursor_visible: true,
      auto_wrap: true,
      origin_mode: false,
      insert_mode: false,
      line_feed_mode: false,
      column_width_mode: :normal,
      auto_repeat_mode: false,
      interlacing_mode: false,
      saved_state: nil
    }
  end

  @doc """
  Switches a specific mode on or off.
  """
  @spec switch_mode(screen_state(), atom(), boolean()) :: screen_state()
  def switch_mode(state, mode_flag, enable) do
    if enable do
      set_mode(state, mode_flag)
    else
      reset_mode(state, mode_flag)
    end
  end

  @doc """
  Switches between screen modes, saving the current state if needed.
  """
  @spec switch_mode(screen_state(), screen_mode()) :: screen_state()
  def switch_mode(state, new_mode) do
    case {state.mode, new_mode} do
      {current, current} ->
        state

      {:normal, :alternate} ->
        # Save normal screen state and switch to alternate
        %{state | mode: :alternate, saved_state: save_current_state(state)}

      {:alternate, :normal} ->
        # Restore normal screen state
        case state.saved_state do
          nil -> %{state | mode: :normal}
          saved -> restore_saved_state(saved)
        end

      _ ->
        %{state | mode: new_mode}
    end
  end

  @doc """
  Sets a specific screen mode flag.
  """
  @spec set_mode(screen_state(), atom()) :: screen_state()
  def set_mode(state, mode_flag) do
    case mode_flag do
      :cursor_visible -> %{state | cursor_visible: true}
      :auto_wrap -> %{state | auto_wrap: true}
      :origin_mode -> %{state | origin_mode: true}
      :insert_mode -> %{state | insert_mode: true}
      :line_feed_mode -> %{state | line_feed_mode: true}
      :wide_column -> %{state | column_width_mode: :wide}
      # Map DECCOLM to wide column mode
      :deccolm_132 -> %{state | column_width_mode: :wide}
      # Add missing modes
      # Mode 8
      :decarm -> %{state | auto_repeat_mode: true}
      # Mode 9
      :decinlm -> %{state | interlacing_mode: true}
      # Alias if needed
      :auto_repeat -> %{state | auto_repeat_mode: true}
      # Alias if needed
      :interlacing -> %{state | interlacing_mode: true}
      _ -> state
    end
  end

  @doc """
  Resets a specific screen mode flag.
  """
  @spec reset_mode(screen_state(), atom()) :: screen_state()
  def reset_mode(state, mode_flag) do
    case mode_flag do
      :cursor_visible -> %{state | cursor_visible: false}
      :auto_wrap -> %{state | auto_wrap: false}
      :origin_mode -> %{state | origin_mode: false}
      :insert_mode -> %{state | insert_mode: false}
      :line_feed_mode -> %{state | line_feed_mode: false}
      :wide_column -> %{state | column_width_mode: :normal}
      # Map DECCOLM to normal column mode
      :deccolm_132 -> %{state | column_width_mode: :normal}
      # Add missing modes
      # Mode 8
      :decarm -> %{state | auto_repeat_mode: false}
      # Mode 9
      :decinlm -> %{state | interlacing_mode: false}
      # Alias if needed
      :auto_repeat -> %{state | auto_repeat_mode: false}
      # Alias if needed
      :interlacing -> %{state | interlacing_mode: false}
      _ -> state
    end
  end

  @doc """
  Checks if a specific mode is enabled.
  """
  @spec mode_enabled?(screen_state(), atom()) :: boolean()
  def mode_enabled?(state, mode_flag) do
    case mode_flag do
      :cursor_visible -> state.cursor_visible
      :auto_wrap -> state.auto_wrap
      :origin_mode -> state.origin_mode
      :insert_mode -> state.insert_mode
      :line_feed_mode -> state.line_feed_mode
      :wide_column -> state.column_width_mode == :wide
      # Map DECCOLM to wide column check
      :deccolm_132 -> state.column_width_mode == :wide
      :auto_repeat -> state.auto_repeat_mode
      :interlacing -> state.interlacing_mode
      _ -> false
    end
  end

  @doc """
  Gets the current screen mode.
  """
  @spec get_mode(screen_state()) :: screen_mode()
  def get_mode(state), do: state.mode

  @doc """
  Gets the current column width mode.
  """
  @spec get_column_width_mode(screen_state()) :: :normal | :wide
  def get_column_width_mode(state), do: state.column_width_mode

  @doc """
  Gets the current auto-repeat mode.
  """
  @spec get_auto_repeat_mode(screen_state()) :: boolean()
  def get_auto_repeat_mode(state), do: state.auto_repeat_mode

  @doc """
  Gets the current interlacing mode.
  """
  @spec get_interlacing_mode(screen_state()) :: boolean()
  def get_interlacing_mode(state), do: state.interlacing_mode

  @doc """
  Looks up a DEC private mode code and returns the corresponding mode atom.
  """
  @spec lookup_private(integer()) :: atom() | nil
  def lookup_private(code) when is_integer(code) do
    Map.get(@dec_private_modes, code)
  end

  @doc """
  Looks up a standard mode code and returns the corresponding mode atom.
  """
  @spec lookup_standard(integer()) :: atom() | nil
  def lookup_standard(code) when is_integer(code) do
    Map.get(@standard_modes, code)
  end

  @doc """
  Handles setting or resetting DEC private modes based on parameters.

  Processes a list of parameters, looks up the corresponding mode atom,
  and applies the action (:set or :reset) to the emulator's mode_state.
  Updated to accept only emulator and {param, action}
  Also handles buffer resizing and screen clearing for relevant modes.
  """
  @spec handle_dec_private_mode(
          Raxol.Terminal.Emulator.t(),
          {integer(), :set | :reset}
        ) ::
          Raxol.Terminal.Emulator.t()
  def handle_dec_private_mode(emulator, {param, action}) do
    # Use the passed emulator directly
    acc_emulator = emulator

    mode_atom = lookup_private(param)

    if mode_atom do
      # Logger.debug("[ScreenModes] #{action} DEC Private Mode ##{param} (#{mode_atom})")

      # Get current dimensions BEFORE changing state
      current_buffer = Emulator.get_active_buffer(acc_emulator)

      {_current_width, current_height} =
        ScreenBuffer.get_dimensions(current_buffer)

      # Apply the basic mode state change first
      updated_mode_state =
        switch_mode(acc_emulator.mode_state, mode_atom, action == :set)

      emulator_with_mode = %{acc_emulator | mode_state: updated_mode_state}

      # --- Handle side effects based on the specific mode ---
      case {mode_atom, action} do
        # --- Column Width (DECCOLM) ---
        {:deccolm_132, :set} ->
          apply_column_width_change(emulator_with_mode, 132, current_height)

        {:deccolm_132, :reset} ->
          apply_column_width_change(emulator_with_mode, 80, current_height)

        # --- Alternate Screen Buffer (DECSCA/DECRARA) ---
        # Mode 1049: Use Alt Screen, Save/Restore State, Clear on switch
        {:alt_screen_buffer, :set} ->
          # Save state BEFORE switching
          new_stack =
            TerminalState.save_state(acc_emulator.state_stack, acc_emulator)

          emulator_with_stack = %{emulator_with_mode | state_stack: new_stack}
          # Clear the alternate buffer
          cleared_alt_buffer =
            ScreenBuffer.clear(emulator_with_stack.alternate_screen_buffer)

          emulator_with_cleared_alt = %{
            emulator_with_stack
            | alternate_screen_buffer: cleared_alt_buffer
          }

          # Switch active buffer type and move cursor home
          %{
            emulator_with_cleared_alt
            | active_buffer_type: :alternate,
              cursor:
                CursorManager.move_to(emulator_with_cleared_alt.cursor, 0, 0)
          }

        {:alt_screen_buffer, :reset} ->
          # Restore state AFTER switching back buffers
          {restored_state_stack, restored_data} =
            TerminalState.restore_state(acc_emulator.state_stack)

          restored_emulator =
            TerminalState.apply_restored_data(
              emulator_with_mode,
              restored_data,
              [:cursor, :style, :charset_state, :mode_state, :scroll_region]
            )

          # Switch active buffer type (restored_emulator already has mode_state reset)
          %{
            restored_emulator
            | active_buffer_type: :main,
              state_stack: restored_state_stack
          }

        # Mode 1047: Use Alt Screen, Save/Restore State (no clear)
        {:dec_alt_screen_save, :set} ->
          # Save state BEFORE switching
          new_stack =
            TerminalState.save_state(acc_emulator.state_stack, acc_emulator)

          emulator_with_stack = %{emulator_with_mode | state_stack: new_stack}
          # Switch active buffer type and move cursor home
          %{
            emulator_with_stack
            | active_buffer_type: :alternate,
              cursor: CursorManager.move_to(emulator_with_stack.cursor, 0, 0)
          }

        {:dec_alt_screen_save, :reset} ->
          # Restore state AFTER switching back buffers
          {restored_state_stack, restored_data} =
            TerminalState.restore_state(acc_emulator.state_stack)

          restored_emulator =
            TerminalState.apply_restored_data(
              emulator_with_mode,
              restored_data,
              [:cursor, :style, :charset_state, :mode_state, :scroll_region]
            )

          # Switch active buffer type
          %{
            restored_emulator
            | active_buffer_type: :main,
              state_stack: restored_state_stack
          }

        # Mode 47: Use Alternate Screen Buffer (Simple, no save/restore, clears on switch)
        {:dec_alt_screen, :set} ->
          cleared_alt_buffer =
            ScreenBuffer.clear(emulator_with_mode.alternate_screen_buffer)

          emulator_with_cleared_alt = %{
            emulator_with_mode
            | alternate_screen_buffer: cleared_alt_buffer
          }

          %{
            emulator_with_cleared_alt
            | active_buffer_type: :alternate,
              cursor:
                CursorManager.move_to(emulator_with_cleared_alt.cursor, 0, 0)
          }

        {:dec_alt_screen, :reset} ->
          %{emulator_with_mode | active_buffer_type: :main}

        # Does not restore cursor or clear main buffer per spec

        # --- Cursor Save/Restore (DECSC/DECRC) ---
        # Note: These are handled slightly differently; DECSC saves, DECRC restores.
        # Mode 1048 is used for both, action determines behavior.
        # Corresponds to DECSC command
        {:decsc, :set} ->
          # Save cursor state, etc.
          new_stack =
            TerminalState.save_state(acc_emulator.state_stack, acc_emulator, [
              :cursor,
              :style,
              :charset_state,
              :origin_mode
            ])

          %{emulator_with_mode | state_stack: new_stack}

        # Corresponds to DECRC command
        {:decsc, :reset} ->
          # Restore cursor state, etc.
          {restored_state_stack, restored_data} =
            TerminalState.restore_state(acc_emulator.state_stack)

          TerminalState.apply_restored_data(emulator_with_mode, restored_data, [
            :cursor,
            :style,
            :charset_state,
            :origin_mode
          ])
          |> Map.put(:state_stack, restored_state_stack)

        # --- Other modes just update mode_state (handled above) ---
        _ ->
          emulator_with_mode
      end
    else
      Logger.warning(
        "[ScreenModes] Unhandled DEC Private Mode parameter: #{param} action: #{action}"
      )

      acc_emulator
    end
  end

  @doc """
  Handles setting or resetting standard ANSI modes based on parameters.
  """
  @spec handle_ansi_mode(
          Raxol.Terminal.Emulator.t(),
          list(integer()),
          :set | :reset
        ) ::
          Raxol.Terminal.Emulator.t()
  def handle_ansi_mode(emulator, params, action) do
    Enum.reduce(params, emulator, fn param, acc_emulator ->
      mode_atom = lookup_standard(param)

      if mode_atom do
        Logger.debug(
          "[ScreenModes] #{action} ANSI mode #{param} (#{mode_atom})"
        )

        new_mode_state =
          case action do
            :set ->
              set_mode(acc_emulator.mode_state, map_mode_to_flag(mode_atom))

            :reset ->
              reset_mode(acc_emulator.mode_state, map_mode_to_flag(mode_atom))
          end

        %{acc_emulator | mode_state: new_mode_state}
      else
        Logger.warning("Unknown ANSI mode parameter: #{param}")
        acc_emulator
      end
    end)
  end

  # Private helper functions

  defp save_current_state(state) do
    Map.take(state, [
      :cursor_visible,
      :auto_wrap,
      :origin_mode,
      :insert_mode,
      :line_feed_mode,
      :column_width_mode,
      :auto_repeat_mode,
      :interlacing_mode
    ])
  end

  defp restore_saved_state(saved_state) do
    %{
      mode: :normal,
      cursor_visible: Map.get(saved_state, :cursor_visible, true),
      auto_wrap: Map.get(saved_state, :auto_wrap, true),
      origin_mode: Map.get(saved_state, :origin_mode, false),
      insert_mode: Map.get(saved_state, :insert_mode, false),
      line_feed_mode: Map.get(saved_state, :line_feed_mode, false),
      column_width_mode: Map.get(saved_state, :column_width_mode, :normal),
      auto_repeat_mode: Map.get(saved_state, :auto_repeat_mode, false),
      interlacing_mode: Map.get(saved_state, :interlacing_mode, false),
      saved_state: nil
    }
  end

  defp map_mode_to_flag(mode_atom) do
    case mode_atom do
      :dectcem -> :cursor_visible
      :decawm -> :auto_wrap
      :decom -> :origin_mode
      :decarm -> :auto_repeat
      # Standard mode 4
      :insert_mode -> :insert_mode
      # Standard mode 20
      :line_feed_mode -> :line_feed_mode
      # Add other mappings as needed (e.g., :decckm -> :cursor_key_mode)
      # Assume flag name matches atom if not explicitly mapped
      _ -> mode_atom
    end
  end

  @doc """
  Clears the screen based on the mode parameter.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - The mode for clearing the screen:
    * 0: Clear from cursor to end of screen
    * 1: Clear from start of screen to cursor
    * 2: Clear entire screen
    * 3: Clear entire screen and scrollback buffer

  ## Returns

  Updated emulator state
  """
  def clear_screen(emulator, n) do
    case n do
      # Since all values 0-3 return the same result in the original implementation
      # we can combine them here
      n when n in [0, 1, 2, 3] -> %{emulator | buffer: []}
      _ -> emulator
    end
  end

  @doc """
  Clears the current line based on the mode parameter.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - The mode for clearing the line:
    * 0: Clear from cursor to end of line
    * 1: Clear from start of line to cursor
    * 2: Clear entire line

  ## Returns

  Updated emulator state
  """
  def clear_line(emulator, n) do
    buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)
    {cursor_x, cursor_y} = emulator.cursor.position
    buffer_width = Raxol.Terminal.ScreenBuffer.get_width(buffer)

    new_buffer =
      case n do
        0 ->
          # Clear from cursor to end of line
          Raxol.Terminal.ScreenBuffer.clear_region(
            buffer,
            cursor_x,
            cursor_y,
            buffer_width - 1,
            cursor_y
          )

        1 ->
          # Clear from start of line to cursor
          Raxol.Terminal.ScreenBuffer.clear_region(
            buffer,
            0,
            cursor_y,
            cursor_x,
            cursor_y
          )

        2 ->
          # Clear entire line
          Raxol.Terminal.ScreenBuffer.clear_region(
            buffer,
            0,
            cursor_y,
            buffer_width - 1,
            cursor_y
          )

        # Unknown mode, do nothing
        _ ->
          buffer
      end

    Map.put(emulator, emulator.active_buffer_key, new_buffer)
  end

  @doc """
  Inserts n lines at the current cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - The number of lines to insert

  ## Returns

  Updated emulator state
  """
  def insert_line(emulator, n) do
    {_, y} = emulator.cursor.position
    buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)

    # Get the correct buffer key based on active_buffer_type
    buffer_key =
      if emulator.active_buffer_type == :main,
        do: :main_screen_buffer,
        else: :alternate_screen_buffer

    # Insert n lines at the current cursor position
    new_buffer =
      Raxol.Terminal.ScreenBuffer.insert_lines(buffer, y, n, emulator.style)

    # Return the updated emulator
    %{emulator | buffer_key => new_buffer}
  end

  @doc """
  Deletes n lines starting from the current cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - The number of lines to delete

  ## Returns

  Updated emulator state
  """
  def delete_line(emulator, n) do
    {_, y} = emulator.cursor.position
    buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)

    # Get the correct buffer key based on active_buffer_type
    buffer_key =
      if emulator.active_buffer_type == :main,
        do: :main_screen_buffer,
        else: :alternate_screen_buffer

    # Delete n lines starting from the current cursor position
    new_buffer =
      Raxol.Terminal.ScreenBuffer.delete_lines(buffer, y, n, emulator.style)

    # Return the updated emulator
    %{emulator | buffer_key => new_buffer}
  end

  # --- Private Helper for DECCOLM ---
  defp apply_column_width_change(emulator, new_width, current_height) do
    emulator
    |> Emulator.resize(new_width, current_height)
    |> Kernel.then(fn emu ->
      cleared_buffer = ScreenBuffer.clear(Emulator.get_active_buffer(emu))
      Emulator.put_active_buffer(emu, cleared_buffer)
    end)
    |> Kernel.then(fn emu ->
      %{emu | cursor: CursorManager.move_to(emu.cursor, 0, 0)}
    end)
  end
end
