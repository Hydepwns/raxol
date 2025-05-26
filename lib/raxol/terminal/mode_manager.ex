defmodule Raxol.Terminal.ModeManager do
  @moduledoc """
  Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.

  This module centralizes the state and logic for various terminal modes,
  handling both simple flag toggles and modes with side effects on the
  emulator state (like screen buffer switching or resizing).
  """

  require Raxol.Core.Runtime.Log

  # Needed for functions modifying Emulator state
  alias Raxol.Terminal.Emulator
  # Removed ANSI.TerminalState from here
  alias Raxol.Terminal.{ScreenBuffer, Cursor.Manager, ANSI.TextFormatting}
  alias Raxol.Terminal.ANSI.TerminalState

  # alias Raxol.Terminal.ANSI.TerminalState # Keep this alias for the default value if not using Application.get_env directly

  @screen_buffer_module Application.compile_env(
                          :raxol,
                          :screen_buffer_impl,
                          Raxol.Terminal.ScreenBuffer
                        )

  # e.g., :decckm, :insert_mode, :alt_screen_buffer, etc.
  @type mode :: atom()

  # DEC Private Mode codes and their corresponding mode atoms
  @dec_private_modes %{
    # Cursor Keys Mode
    1 => :decckm,
    # 132 Column Mode
    3 => :deccolm_132,
    # 80 Column Mode
    80 => :deccolm_80,
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
    # Note: Affects cursor style, maybe handle separately?
    12 => :att_blink,
    # Text Cursor Enable Mode
    25 => :dectcem,
    # Use Alternate Screen Buffer (Simple)
    47 => :dec_alt_screen,
    # Send Mouse X & Y on button press
    # Specific mode
    1000 => :mouse_report_x10,
    # Use Cell Motion Mouse Tracking
    # Specific mode
    1002 => :mouse_report_cell_motion,
    # Send FocusIn/FocusOut events
    1004 => :focus_events,
    # SGR Mouse Mode
    # Specific mode
    1006 => :mouse_report_sgr,
    # Use Alt Screen, Save/Restore State (no clear)
    1047 => :dec_alt_screen_save,
    # Save/Restore Cursor Position (and attributes)
    # Combined mode for save/restore via TerminalState
    1048 => :decsc_deccara,
    # Use Alt Screen, Save/Restore State, Clear on switch
    # The most common alternate screen mode
    1049 => :alt_screen_buffer,
    # Enable bracketed paste mode
    2004 => :bracketed_paste
  }

  # Standard Mode codes and their corresponding mode atoms
  @standard_modes %{
    # Insert Mode
    # Insert/Replace Mode
    4 => :irm,
    # Line Feed Mode
    # Line Feed/New Line Mode
    20 => :lnm,
    # Column Width Mode
    # 132 Column Mode
    3 => :deccolm_132,
    # 132 Column Mode
    132 => :deccolm_132,
    # 80 Column Mode
    80 => :deccolm_80
    # TODO: Add others if needed (e.g., KAM - Keyboard Action Mode)
  }

  # Refined struct based on common modes
  # DECTCEM (25)
  defstruct cursor_visible: true,
            # DECAWM (7)
            auto_wrap: true,
            # DECOM (6)
            origin_mode: false,
            # IRM (4)
            insert_mode: false,
            # LNM (20)
            line_feed_mode: false,
            # DECCCOLM (3) :normal (80) | :wide (132)
            column_width_mode: :normal,
            # DECCKM (1) :normal | :application
            cursor_keys_mode: :normal,
            # DECSCNM (5)
            screen_mode_reverse: false,
            # DECARM (8) - Note: Default is often ON
            auto_repeat_mode: true,
            # DECINLM (9)
            interlacing_mode: false,
            # Tracks if alt buffer is active (47, 1047, 1049)
            alternate_buffer_active: false,
            # :none, :x10, :cell_motion, :sgr (1000, 1002, 1006)
            mouse_report_mode: :none,
            # (1004)
            focus_events_enabled: false,
            # Tracks the active alt screen mode
            alt_screen_mode: nil,
            # Bracketed paste mode
            bracketed_paste_mode: false,
            # Added for the new logic
            active_buffer_type: :main

  # TODO: Consider saved state for 1048 (DECSC/DECRC) - maybe managed by TerminalState?
  # TODO: Consider saved state for 1047/1049 - maybe managed by TerminalState?

  @type t :: %__MODULE__{}

  @doc """
  Creates a new mode manager state with default values.
  """
  @spec new() :: t()
  def new() do
    %__MODULE__{
      cursor_keys_mode: :normal,
      cursor_visible: true,
      auto_wrap: true,
      auto_repeat_mode: true,
      # Default is replace mode
      insert_mode: false,
      # Default is LF only
      line_feed_mode: false,
      column_width_mode: :normal,
      interlacing_mode: false,
      focus_events_enabled: false,
      bracketed_paste_mode: false
    }
  end

  # --- Mode Lookup ---

  @doc """
  Looks up a DEC private mode code and returns the corresponding mode atom.
  """
  @spec lookup_private(integer()) :: mode() | nil
  def lookup_private(code) when is_integer(code) do
    Map.get(@dec_private_modes, code)
  end

  @doc """
  Looks up a standard mode code and returns the corresponding mode atom.
  """
  @spec lookup_standard(integer()) :: mode() | nil
  def lookup_standard(code) when is_integer(code) do
    Map.get(@standard_modes, code)
  end

  # --- Mode Setting/Resetting ---

  @doc """
  Sets one or more modes. Dispatches to specific handlers.
  Returns potentially updated Emulator state if side effects occurred.
  """
  @spec set_mode(Emulator.t(), [mode()]) :: Emulator.t()
  def set_mode(emulator, modes) when is_list(modes) do
    Enum.reduce(modes, emulator, &do_set_mode/2)
  end

  @doc """
  Resets one or more modes. Dispatches to specific handlers.
  Returns potentially updated Emulator state if side effects occurred.
  """
  @spec reset_mode(Emulator.t(), [mode()]) :: Emulator.t()
  def reset_mode(emulator, modes) when is_list(modes) do
    Enum.reduce(modes, emulator, &do_reset_mode/2)
  end

  # --- Private Set/Reset Helpers ---

  # Handles setting a single mode
  defp do_set_mode(mode_atom, emulator) do
    # Get current mode manager state
    mm_state = emulator.mode_manager

    case mode_atom do
      # Simple flag toggles (update mm_state only)
      :dectcem ->
        update_mm_state(emulator, %{mm_state | cursor_visible: true})

      :decawm ->
        update_mm_state(emulator, %{mm_state | auto_wrap: true})

      :decom ->
        update_mm_state(emulator, %{mm_state | origin_mode: true})

      :irm ->
        update_mm_state(emulator, %{mm_state | insert_mode: true})

      :insert_mode ->
        update_mm_state(emulator, %{mm_state | insert_mode: true})

      :lnm ->
        update_mm_state(emulator, %{mm_state | line_feed_mode: true})

      :decckm ->
        update_mm_state(emulator, %{mm_state | cursor_keys_mode: :application})

      :decscnm ->
        update_mm_state(emulator, %{mm_state | screen_mode_reverse: true})

      :decarm ->
        update_mm_state(emulator, %{mm_state | auto_repeat_mode: true})

      :decinlm ->
        update_mm_state(emulator, %{mm_state | interlacing_mode: true})

      :focus_events ->
        update_mm_state(emulator, %{mm_state | focus_events_enabled: true})

      :bracketed_paste ->
        update_mm_state(emulator, %{mm_state | bracketed_paste_mode: true})

      # Modes with side effects (delegate to specific handlers)
      :deccolm_132 ->
        set_column_width_mode(emulator, :wide)

      :deccolm_80 ->
        set_column_width_mode(emulator, :normal)

      :alt_screen_buffer ->
        set_alternate_buffer(emulator, :mode_1049)

      :dec_alt_screen_save ->
        set_alternate_buffer(emulator, :mode_1047)

      :dec_alt_screen ->
        set_alternate_buffer(emulator, :mode_47)

      # DECSC part
      :decsc_deccara ->
        save_terminal_state(emulator)

      :mouse_report_x10 ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :x10})

      :mouse_report_cell_motion ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :cell_motion})

      :mouse_report_sgr ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :sgr})

      # Unknown/Unhandled
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled mode to set: #{inspect(mode_atom)}",
          %{}
        )

        # Return unchanged emulator state
        emulator
    end
  end

  # Handles resetting a single mode
  defp do_reset_mode(mode_atom, emulator) do
    mm_state = emulator.mode_manager

    case mode_atom do
      # Simple flag toggles (update mm_state only)
      :dectcem ->
        update_mm_state(emulator, %{mm_state | cursor_visible: false})

      :decawm ->
        update_mm_state(emulator, %{mm_state | auto_wrap: false})

      :decom ->
        update_mm_state(emulator, %{mm_state | origin_mode: false})

      :irm ->
        update_mm_state(emulator, %{mm_state | insert_mode: false})

      :insert_mode ->
        update_mm_state(emulator, %{mm_state | insert_mode: false})

      :lnm ->
        update_mm_state(emulator, %{mm_state | line_feed_mode: false})

      :decckm ->
        update_mm_state(emulator, %{mm_state | cursor_keys_mode: :normal})

      :decscnm ->
        update_mm_state(emulator, %{mm_state | screen_mode_reverse: false})

      :decarm ->
        update_mm_state(emulator, %{mm_state | auto_repeat_mode: false})

      :decinlm ->
        update_mm_state(emulator, %{mm_state | interlacing_mode: false})

      :focus_events ->
        update_mm_state(emulator, %{mm_state | focus_events_enabled: false})

      :bracketed_paste ->
        update_mm_state(emulator, %{mm_state | bracketed_paste_mode: false})

      # Modes with side effects (delegate to specific handlers)
      :deccolm_132 ->
        set_column_width_mode(emulator, :normal)

      :deccolm_80 ->
        set_column_width_mode(emulator, :normal)

      :alt_screen_buffer ->
        reset_alternate_buffer(emulator)

      :dec_alt_screen_save ->
        reset_alternate_buffer(emulator)

      :dec_alt_screen ->
        reset_alternate_buffer(emulator)

      # DECRC part
      :decsc_deccara ->
        restore_terminal_state(emulator, :cursor_only)

      # Assuming reset goes to none
      :mouse_report_x10 ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :none})

      :mouse_report_cell_motion ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :none})

      :mouse_report_sgr ->
        update_mm_state(emulator, %{mm_state | mouse_report_mode: :none})

      # Unknown/Unhandled
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled mode to reset: #{inspect(mode_atom)}",
          %{}
        )

        # Return unchanged emulator state
        emulator
    end
  end

  # Helper to update only the mode_manager state within the emulator
  defp update_mm_state(emulator, new_mm_state) do
    %{emulator | mode_manager: new_mm_state}
  end

  # --- Mode Checkers ---

  @doc """
  Checks if a specific mode flag is currently enabled.
  """
  @spec mode_enabled?(t(), mode()) :: boolean()
  # Dedicated clauses for problematic mouse modes
  def mode_enabled?(
        %__MODULE__{mouse_report_mode: actual_mouse_mode},
        :mouse_report_x10
      ) do
    actual_mouse_mode == :x10
  end

  def mode_enabled?(
        %__MODULE__{mouse_report_mode: actual_mouse_mode},
        :mouse_report_cell_motion
      ) do
    actual_mouse_mode == :cell_motion
  end

  def mode_enabled?(
        %__MODULE__{mouse_report_mode: actual_mouse_mode},
        :mouse_report_sgr
      ) do
    actual_mouse_mode == :sgr
  end

  # Fallback for other cases
  def mode_enabled?(mm_state, mode_flag) do
    case mode_flag do
      :dectcem ->
        mm_state.cursor_visible

      :decawm ->
        mm_state.auto_wrap

      :decom ->
        mm_state.origin_mode

      :irm ->
        mm_state.insert_mode

      :lnm ->
        mm_state.line_feed_mode

      :decckm ->
        mm_state.cursor_keys_mode == :application

      :decscnm ->
        mm_state.screen_mode_reverse

      :decarm ->
        mm_state.auto_repeat_mode

      :decinlm ->
        mm_state.interlacing_mode

      :focus_events ->
        mm_state.focus_events_enabled

      # Generic check
      :alt_screen_buffer ->
        mm_state.alternate_buffer_active

      # Specific alt buffer modes might need explicit checks if needed elsewhere
      # Check if ANY alt buffer is active
      :dec_alt_screen ->
        mm_state.alternate_buffer_active

      :dec_alt_screen_save ->
        mm_state.alternate_buffer_active

      :bracketed_paste ->
        mm_state.bracketed_paste_mode

      # Mouse modes are handled by dedicated clauses above
      :deccolm_80 ->
        mm_state.column_width_mode == :normal

      # Corrected
      :deccolm_100 ->
        mm_state.column_width_mode == :wide

      :deccolm_132 ->
        mm_state.column_width_mode == :wide

      # TODO: Add other simple flags as needed
      _ ->
        Raxol.Core.Runtime.Log.debug(
          "[ModeManager] mode_enabled? fallback for: #{inspect(mode_flag)}"
        )

        # Default to false for unknown or complex modes here
        false
    end
  end

  # --- Mode Specific Handlers (Implementation) ---

  # Handles DECCCOLM (Mode 3)
  defp set_column_width_mode(emulator, width_mode) do
    new_width =
      case width_mode do
        :wide -> 132
        :normal -> 80
      end

    # Resize main buffer
    main_buffer =
      @screen_buffer_module.resize(
        emulator.main_screen_buffer,
        new_width,
        emulator.main_screen_buffer.height
      )

    emulator = %{emulator | main_screen_buffer: main_buffer}

    # Resize alternate buffer if it exists
    emulator =
      if emulator.alternate_screen_buffer do
        alt_buffer =
          @screen_buffer_module.resize(
            emulator.alternate_screen_buffer,
            new_width,
            emulator.alternate_screen_buffer.height
          )

        %{emulator | alternate_screen_buffer: alt_buffer}
      else
        emulator
      end

    # Update mode manager state
    mm_state = %{emulator.mode_manager | column_width_mode: width_mode}
    update_mm_state(emulator, mm_state)
  end

  # Handles setting alternate buffer modes (47, 1047, 1049)
  defp set_alternate_buffer(emulator, type) do
    mm_state = emulator.mode_manager

    # If already in some alternate buffer mode, and trying to set the same, do nothing or log.
    # Or if trying to set a *different* alt mode, maybe reset first? For now, assume one alt mode at a time.
    if mm_state.alternate_buffer_active && mm_state.alt_screen_mode == type do
      Raxol.Core.Runtime.Log.debug(
        "[ModeManager] Already in alternate screen mode #{type}. No change."
      )

      emulator
    else
      {buffer_width, buffer_height} =
        @screen_buffer_module.get_dimensions(emulator.main_screen_buffer)

      {emulator_to_modify, new_active_type} =
        case type do
          :mode_1049 ->
            emulator_to_modify = save_terminal_state(emulator)

            current_alt_buffer =
              emulator_to_modify.alternate_screen_buffer ||
                @screen_buffer_module.new(buffer_width, buffer_height)

            cleared_alt_buffer =
              @screen_buffer_module.clear(
                current_alt_buffer,
                TextFormatting.new()
              )

            emulator_with_alt = %{
              emulator_to_modify
              | alternate_screen_buffer: cleared_alt_buffer
            }

            {emulator_with_alt, :alternate}

          :mode_1047 ->
            emulator_to_modify = save_terminal_state(emulator)

            current_alt_buffer =
              emulator_to_modify.alternate_screen_buffer ||
                @screen_buffer_module.new(buffer_width, buffer_height)

            emulator_with_alt = %{
              emulator_to_modify
              | alternate_screen_buffer: current_alt_buffer
            }

            {emulator_with_alt, :alternate}

          :mode_47 ->
            current_alt_buffer =
              emulator.alternate_screen_buffer ||
                @screen_buffer_module.new(buffer_width, buffer_height)

            emulator_with_alt = %{
              emulator
              | alternate_screen_buffer: current_alt_buffer
            }

            {emulator_with_alt, :alternate}
        end

      # Now emulator_to_modify contains the correct alternate_screen_buffer from the case block.
      # We only need to ensure active_buffer_type is set.
      emulator_to_modify = %{
        emulator_to_modify
        | active_buffer_type: new_active_type
      }

      new_mm_state = %{
        mm_state
        | alternate_buffer_active: true,
          alt_screen_mode: type
      }

      update_mm_state(emulator_to_modify, new_mm_state)
    end
  end

  # Handles resetting alternate buffer modes (47, 1047, 1049)
  defp reset_alternate_buffer(emulator) do
    mm_state = emulator.mode_manager

    unless mm_state.alternate_buffer_active do
      Raxol.Core.Runtime.Log.debug(
        "[ModeManager] Main buffer already active. No change from reset_alternate_buffer."
      )

      emulator
    else
      Raxol.Core.Runtime.Log.debug(
        "[ModeManager] Resetting to main buffer from: #{inspect(mm_state.alt_screen_mode)}"
      )

      emulator_after_restore =
        if mm_state.alt_screen_mode == :mode_1047 ||
             mm_state.alt_screen_mode == :mode_1049 do
          restore_terminal_state(emulator, :full)
        else
          emulator
        end

      # Explicitly set the active buffer type back to main
      emulator_to_update = %{emulator_after_restore | active_buffer_type: :main}

      emulator_to_update =
        if mm_state.alt_screen_mode == :mode_1049 do
          # Clear the alternate buffer before switching away from it
          # Get the configured screen buffer module
          screen_buffer_impl =
            Application.get_env(
              :raxol,
              :screen_buffer_impl,
              Raxol.Terminal.ScreenBuffer
            )

          text_formatting_impl =
            Application.get_env(
              :raxol,
              :text_formatting_impl,
              Raxol.Terminal.ANSI.TextFormatting
            )

          if alt_buf = emulator_to_update.alternate_screen_buffer do
            cleared_alt_buf =
              screen_buffer_impl.clear(alt_buf, text_formatting_impl.new())

            %{emulator_to_update | alternate_screen_buffer: cleared_alt_buf}
          else
            # Should not happen if 1049 was active, but good to be defensive
            emulator_to_update
          end
        else
          emulator_to_update
        end

      # Update ModeManager's internal state
      new_mm_state = %{
        mm_state
        | alternate_buffer_active: false,
          alt_screen_mode: nil
      }

      # Ensure this uses emulator_to_update (which has active_buffer_type set correctly)
      update_mm_state(emulator_to_update, new_mm_state)
    end
  end

  # --- Terminal State Saving/Restoring Helpers (using Application.get_env) ---

  # type can be :full or :cursor_only (for DECSC/DECRC)
  defp save_terminal_state(emulator) do
    # Fetch the implementation module at runtime
    terminal_state_module =
      Application.get_env(
        :raxol,
        :terminal_state_impl,
        Raxol.Terminal.ANSI.TerminalState
      )

    # The terminal_state_module.save_state function should take the current stack and the full emulator state
    # and return the new stack.
    new_stack = terminal_state_module.save_state(emulator.state_stack, emulator)
    %{emulator | state_stack: new_stack}
  end

  # type can be :full or :cursor_only
  defp restore_terminal_state(emulator, type \\ :full) do
    # Fetch the implementation module at runtime
    terminal_state_module =
      Application.get_env(
        :raxol,
        :terminal_state_impl,
        Raxol.Terminal.ANSI.TerminalState
      )

    # 1. Get the restored data and new stack from the terminal_state_module
    {new_stack, restored_state_data} =
      terminal_state_module.restore_state(emulator.state_stack)

    if restored_state_data do
      # 2. Determine which fields to apply based on 'type'
      fields_to_apply =
        case type do
          # Assuming style is often saved with cursor
          :cursor_only ->
            [:cursor]

          :full ->
            [
              :cursor,
              :style,
              :charset_state,
              :mode_manager,
              :scroll_region,
              :cursor_style
            ]

          # Default to no fields if type is unknown
          _ ->
            []
        end

      # 3. Apply the selected fields to the emulator
      emu_with_restored_data =
        terminal_state_module.apply_restored_data(
          emulator,
          restored_state_data,
          fields_to_apply
        )

      # 4. Update the emulator with the new stack
      %{emu_with_restored_data | state_stack: new_stack}
    else
      # No state was restored (stack was empty)
      Raxol.Core.Runtime.Log.debug(
        "[ModeManager] Terminal state stack empty, no state to restore."
      )

      emulator
    end
  end

  # Example: DECOM - Origin Mode (?6)
  defp handle_decpm_set(state, :origin_mode),
    do: %__MODULE__{state | origin_mode: true}

  defp handle_decpm_reset(state, :origin_mode),
    do: %__MODULE__{state | origin_mode: false}

  # Example: DECAWM - Autowrap Mode (?7) - Assuming it's a direct field
  defp handle_decpm_set(state, :auto_wrap),
    do: %__MODULE__{state | auto_wrap: true}

  defp handle_decpm_reset(state, :auto_wrap),
    do: %__MODULE__{state | auto_wrap: false}

  # Add other DEC private modes here, ensuring they map to actual struct fields
  # For mouse modes, they typically affect state.mouse_report_mode

  # Generic fallback for modes not directly mapped to a boolean field,
  # or for those that need more complex logic (like mouse modes affecting mouse_report_mode)
  # Ensure this doesn't try to set unknown keys if it's just a struct.
  # This part is speculative without seeing the original function.
  # If there was a dynamic `Map.put` before, it needs to be careful.
  # For specific mouse modes like :x10_mouse, :button_event_mouse, etc.,
  # they should set state.mouse_report_mode to the appropriate atom
  # e.g., :normal, :cell_motion, :all_motion

  defp handle_decpm_set(state, :x10_mouse) do
    %__MODULE__{state | mouse_report_mode: :normal}
  end

  defp handle_decpm_reset(state, :x10_mouse) do
    # Resetting x10 usually means no mouse reporting or a default
    %__MODULE__{state | mouse_report_mode: nil}
  end

  # For ?1002h
  defp handle_decpm_set(state, :button_event_mouse) do
    %__MODULE__{state | mouse_report_mode: :cell_motion}
  end

  defp handle_decpm_reset(state, :button_event_mouse) do
    %__MODULE__{state | mouse_report_mode: nil}
  end

  # For ?1003h
  defp handle_decpm_set(state, :any_event_mouse) do
    %__MODULE__{state | mouse_report_mode: :all_motion}
  end

  defp handle_decpm_reset(state, :any_event_mouse) do
    %__MODULE__{state | mouse_report_mode: nil}
  end

  # Ensure a catch-all or proper handling for unmapped modes if necessary
  defp handle_decpm_set(state, _unknown_mode) do
    # Log this event, as it indicates an unhandled DEC private mode set.
    # Raxol.Core.Runtime.Log.warn("Attempted to set unhandled DEC private mode: #{inspect(unknown_mode)}")
    # Return state unchanged
    state
  end

  defp handle_decpm_reset(state, _unknown_mode) do
    # Raxol.Core.Runtime.Log.warn("Attempted to reset unhandled DEC private mode: #{inspect(unknown_mode)}")
    # Return state unchanged
    state
  end
end
