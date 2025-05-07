defmodule Raxol.Terminal.ModeManager do
  @moduledoc """
  Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.

  This module centralizes the state and logic for various terminal modes,
  handling both simple flag toggles and modes with side effects on the
  emulator state (like screen buffer switching or resizing).
  """

  require Logger

  alias Raxol.Terminal.Emulator # Needed for functions modifying Emulator state
  alias Raxol.Terminal.{ScreenBuffer, Cursor.Manager, ANSI.TextFormatting} # Removed ANSI.TerminalState from here
  # alias Raxol.Terminal.ANSI.TerminalState # Keep this alias for the default value if not using Application.get_env directly

  @terminal_state_module Application.compile_env(:raxol, :terminal_state_impl, Raxol.Terminal.ANSI.TerminalState)
  @screen_buffer_module Application.compile_env(:raxol, :screen_buffer_impl, Raxol.Terminal.ScreenBuffer)

  @type mode :: atom() # e.g., :decckm, :insert_mode, :alt_screen_buffer, etc.

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
    12 => :att_blink, # Note: Affects cursor style, maybe handle separately?
    # Text Cursor Enable Mode
    25 => :dectcem,
    # Use Alternate Screen Buffer (Simple)
    47 => :dec_alt_screen,
    # Send Mouse X & Y on button press
    1000 => :mouse_report_x10, # Specific mode
    # Use Cell Motion Mouse Tracking
    1002 => :mouse_report_cell_motion, # Specific mode
    # Send FocusIn/FocusOut events
    1004 => :focus_events,
    # SGR Mouse Mode
    1006 => :mouse_report_sgr, # Specific mode
    # Use Alt Screen, Save/Restore State (no clear)
    1047 => :dec_alt_screen_save,
    # Save/Restore Cursor Position (and attributes)
    1048 => :decsc_deccara, # Combined mode for save/restore via TerminalState
    # Use Alt Screen, Save/Restore State, Clear on switch
    1049 => :alt_screen_buffer, # The most common alternate screen mode
    2004 => :bracketed_paste # Enable bracketed paste mode
  }

  # Standard Mode codes and their corresponding mode atoms
  @standard_modes %{
    # Insert Mode
    4 => :irm, # Insert/Replace Mode
    # Line Feed Mode
    20 => :lnm, # Line Feed/New Line Mode
    # Column Width Mode
    3 => :deccolm_132, # 132 Column Mode
    132 => :deccolm_132, # 132 Column Mode
    80 => :deccolm_80, # 80 Column Mode
    # TODO: Add others if needed (e.g., KAM - Keyboard Action Mode)
  }

  # Refined struct based on common modes
  defstruct cursor_visible: true, # DECTCEM (25)
            auto_wrap: true, # DECAWM (7)
            origin_mode: false, # DECOM (6)
            insert_mode: false, # IRM (4)
            line_feed_mode: false, # LNM (20)
            column_width_mode: :normal, # DECCCOLM (3) :normal (80) | :wide (132)
            cursor_keys_mode: :normal, # DECCKM (1) :normal | :application
            screen_mode_reverse: false, # DECSCNM (5)
            auto_repeat_mode: true, # DECARM (8) - Note: Default is often ON
            interlacing_mode: false, # DECINLM (9)
            alternate_buffer_active: false, # Tracks if alt buffer is active (47, 1047, 1049)
            mouse_report_mode: :none, # :none, :x10, :cell_motion, :sgr (1000, 1002, 1006)
            focus_events_enabled: false, # (1004)
            alt_screen_mode: nil, # Tracks the active alt screen mode
            bracketed_paste_mode: false # Bracketed paste mode
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
      insert_mode: false, # Default is replace mode
      line_feed_mode: false, # Default is LF only
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
      :dectcem -> update_mm_state(emulator, %{mm_state | cursor_visible: true})
      :decawm -> update_mm_state(emulator, %{mm_state | auto_wrap: true})
      :decom -> update_mm_state(emulator, %{mm_state | origin_mode: true})
      :irm -> update_mm_state(emulator, %{mm_state | insert_mode: true})
      :lnm -> update_mm_state(emulator, %{mm_state | line_feed_mode: true})
      :decckm -> update_mm_state(emulator, %{mm_state | cursor_keys_mode: :application})
      :decscnm -> update_mm_state(emulator, %{mm_state | screen_mode_reverse: true})
      :decarm -> update_mm_state(emulator, %{mm_state | auto_repeat_mode: true})
      :decinlm -> update_mm_state(emulator, %{mm_state | interlacing_mode: true})
      :focus_events -> update_mm_state(emulator, %{mm_state | focus_events_enabled: true})
      :bracketed_paste -> update_mm_state(emulator, %{mm_state | bracketed_paste_mode: true})

      # Modes with side effects (delegate to specific handlers)
      :deccolm_132 -> set_column_width_mode(emulator, :wide)
      :deccolm_80 -> set_column_width_mode(emulator, :normal)
      :alt_screen_buffer -> set_alternate_buffer(emulator, :mode_1049)
      :dec_alt_screen_save -> set_alternate_buffer(emulator, :mode_1047)
      :dec_alt_screen -> set_alternate_buffer(emulator, :mode_47)
      :decsc_deccara -> save_terminal_state(emulator) # DECSC part
      :mouse_report_x10 -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :x10})
      :mouse_report_cell_motion -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :cell_motion})
      :mouse_report_sgr -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :sgr})

      # Unknown/Unhandled
      _ ->
        Logger.warning("[ModeManager] Unhandled mode to set: #{inspect(mode_atom)}")
        emulator # Return unchanged emulator state
    end
  end

  # Handles resetting a single mode
  defp do_reset_mode(mode_atom, emulator) do
    mm_state = emulator.mode_manager

    case mode_atom do
      # Simple flag toggles (update mm_state only)
      :dectcem -> update_mm_state(emulator, %{mm_state | cursor_visible: false})
      :decawm -> update_mm_state(emulator, %{mm_state | auto_wrap: false})
      :decom -> update_mm_state(emulator, %{mm_state | origin_mode: false})
      :irm -> update_mm_state(emulator, %{mm_state | insert_mode: false})
      :lnm -> update_mm_state(emulator, %{mm_state | line_feed_mode: false})
      :decckm -> update_mm_state(emulator, %{mm_state | cursor_keys_mode: :normal})
      :decscnm -> update_mm_state(emulator, %{mm_state | screen_mode_reverse: false})
      :decarm -> update_mm_state(emulator, %{mm_state | auto_repeat_mode: false})
      :decinlm -> update_mm_state(emulator, %{mm_state | interlacing_mode: false})
      :focus_events -> update_mm_state(emulator, %{mm_state | focus_events_enabled: false})
      :bracketed_paste -> update_mm_state(emulator, %{mm_state | bracketed_paste_mode: false})

      # Modes with side effects (delegate to specific handlers)
      :deccolm_132 -> set_column_width_mode(emulator, :wide)
      :deccolm_80 -> set_column_width_mode(emulator, :normal)
      :alt_screen_buffer -> reset_alternate_buffer(emulator)
      :dec_alt_screen_save -> reset_alternate_buffer(emulator)
      :dec_alt_screen -> reset_alternate_buffer(emulator)
      :decsc_deccara -> restore_terminal_state(emulator, :cursor_only) # DECRC part
      :mouse_report_x10 -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :none}) # Assuming reset goes to none
      :mouse_report_cell_motion -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :none})
      :mouse_report_sgr -> update_mm_state(emulator, %{mm_state | mouse_report_mode: :none})

      # Unknown/Unhandled
      _ ->
        Logger.warning("[ModeManager] Unhandled mode to reset: #{inspect(mode_atom)}")
        emulator # Return unchanged emulator state
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
  def mode_enabled?(%__MODULE__{mouse_report_mode: actual_mouse_mode}, :mouse_report_x10) do
    actual_mouse_mode == :x10
  end
  def mode_enabled?(%__MODULE__{mouse_report_mode: actual_mouse_mode}, :mouse_report_cell_motion) do
    actual_mouse_mode == :cell_motion
  end
  def mode_enabled?(%__MODULE__{mouse_report_mode: actual_mouse_mode}, :mouse_report_sgr) do
    actual_mouse_mode == :sgr
  end

  # Fallback for other cases
  def mode_enabled?(mm_state, mode_flag) do
    case mode_flag do
      :dectcem -> mm_state.cursor_visible
      :decawm -> mm_state.auto_wrap
      :decom -> mm_state.origin_mode
      :irm -> mm_state.insert_mode
      :lnm -> mm_state.line_feed_mode
      :decckm -> mm_state.cursor_keys_mode == :application
      :decscnm -> mm_state.screen_mode_reverse
      :decarm -> mm_state.auto_repeat_mode
      :decinlm -> mm_state.interlacing_mode
      :focus_events -> mm_state.focus_events_enabled
      :alt_screen_buffer -> mm_state.alternate_buffer_active # Generic check
      # Specific alt buffer modes might need explicit checks if needed elsewhere
      :dec_alt_screen -> mm_state.alternate_buffer_active # Check if ANY alt buffer is active
      :dec_alt_screen_save -> mm_state.alternate_buffer_active
      :bracketed_paste -> mm_state.bracketed_paste_mode
      # Mouse modes are handled by dedicated clauses above
      :deccolm_80 -> mm_state.column_width_mode == :normal
      :deccolm_100 -> mm_state.column_width_mode == :wide # Corrected
      :deccolm_132 -> mm_state.column_width_mode == :wide
      # TODO: Add other simple flags as needed
      _ ->
        Logger.debug("[ModeManager] mode_enabled? fallback for: #{inspect(mode_flag)}")
        false # Default to false for unknown or complex modes here
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
    main_buffer = @screen_buffer_module.resize(emulator.main_screen_buffer, new_width, emulator.main_screen_buffer.height)
    emulator = %{emulator | main_screen_buffer: main_buffer}

    # Resize alternate buffer if it exists
    emulator =
      if emulator.alternate_screen_buffer do
        alt_buffer = @screen_buffer_module.resize(emulator.alternate_screen_buffer, new_width, emulator.alternate_screen_buffer.height)
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
      Logger.debug("[ModeManager] Already in alternate screen mode #{type}. No change.")
      emulator
    else
      {buffer_width, buffer_height} = @screen_buffer_module.get_dimensions(emulator.main_screen_buffer)

      {emulator_to_modify, new_active_type} =
        case type do
          :mode_1049 ->
            emulator_to_modify = save_terminal_state(emulator)
            current_alt_buffer = emulator_to_modify.alternate_screen_buffer || @screen_buffer_module.new(buffer_width, buffer_height)
            cleared_alt_buffer = @screen_buffer_module.clear(current_alt_buffer, TextFormatting.new())
            emulator_with_alt = %{emulator_to_modify | alternate_screen_buffer: cleared_alt_buffer}
            {emulator_with_alt, :alternate}

          :mode_1047 ->
            emulator_to_modify = save_terminal_state(emulator)
            current_alt_buffer = emulator_to_modify.alternate_screen_buffer || @screen_buffer_module.new(buffer_width, buffer_height)
            emulator_with_alt = %{emulator_to_modify | alternate_screen_buffer: current_alt_buffer}
            {emulator_with_alt, :alternate}

          :mode_47 ->
            current_alt_buffer = emulator.alternate_screen_buffer || @screen_buffer_module.new(buffer_width, buffer_height)
            emulator_with_alt = %{emulator | alternate_screen_buffer: current_alt_buffer}
            {emulator_with_alt, :alternate}
        end

      # Now emulator_to_modify contains the correct alternate_screen_buffer from the case block.
      # We only need to ensure active_buffer_type is set.
      emulator_to_modify = %{emulator_to_modify | active_buffer_type: new_active_type}

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
      Logger.debug("[ModeManager] Main buffer already active. No change from reset_alternate_buffer.")
      emulator
    else
      Logger.debug("[ModeManager] Resetting to main buffer from: #{inspect(mm_state.alt_screen_mode)}")

      emulator_after_restore =
        if mm_state.alt_screen_mode == :mode_1047 || mm_state.alt_screen_mode == :mode_1049 do
          restore_terminal_state(emulator, :full)
        else
          emulator
        end

      if mm_state.alt_screen_mode == :mode_1049 do
        :ok
      end

      # Update ModeManager's internal state
      new_mm_state = %{
        mm_state
        | alternate_buffer_active: false,
          alt_screen_mode: nil
      }

      update_mm_state(emulator_after_restore, new_mm_state) # Ensure this uses emulator_after_restore
    end
  end

  # --- Terminal State Saving/Restoring Helpers (using @terminal_state_module) ---

  # type can be :full or :cursor_only (for DECSC/DECRC)
  defp save_terminal_state(emulator) do
    # The @terminal_state_module.save_state function should take the current stack and the full emulator state
    # and return the new stack.
    new_stack = @terminal_state_module.save_state(emulator.state_stack, emulator)
    %{emulator | state_stack: new_stack}
  end

  # type can be :full or :cursor_only
  defp restore_terminal_state(emulator, type \\ :full) do
    # 1. Get the restored data and new stack from the @terminal_state_module
    {new_stack, restored_state_data} = @terminal_state_module.restore_state(emulator.state_stack)

    if restored_state_data do
      # 2. Determine which fields to apply based on 'type'
      fields_to_apply =
        case type do
          :cursor_only -> [:cursor, :style] # Assuming style is often saved with cursor
          :full -> [:cursor, :style, :charset_state, :mode_manager, :scroll_region, :cursor_style]
          _ -> [] # Default to no fields if type is unknown
        end

      # 3. Apply the selected fields to the emulator
      emu_with_restored_data =
        @terminal_state_module.apply_restored_data(emulator, restored_state_data, fields_to_apply)

      # 4. Update the emulator with the new stack
      %{emu_with_restored_data | state_stack: new_stack}
    else
      # No state was restored (stack was empty)
      Logger.debug("[ModeManager] Terminal state stack empty, no state to restore.")
      emulator
    end
  end

  # Example: DECOM - Origin Mode (?6)
  defp handle_decpm_set(state, :origin_mode), do: %__MODULE__{state | origin_mode: true}
  defp handle_decpm_reset(state, :origin_mode), do: %__MODULE__{state | origin_mode: false}

  # Example: DECAWM - Autowrap Mode (?7) - Assuming it's a direct field
  defp handle_decpm_set(state, :auto_wrap), do: %__MODULE__{state | auto_wrap: true}
  defp handle_decpm_reset(state, :auto_wrap), do: %__MODULE__{state | auto_wrap: false}

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

  defp handle_decpm_set(state, :button_event_mouse) do # For ?1002h
    %__MODULE__{state | mouse_report_mode: :cell_motion}
  end
  defp handle_decpm_reset(state, :button_event_mouse) do
    %__MODULE__{state | mouse_report_mode: nil}
  end

  defp handle_decpm_set(state, :any_event_mouse) do # For ?1003h
    %__MODULE__{state | mouse_report_mode: :all_motion}
  end
  defp handle_decpm_reset(state, :any_event_mouse) do
    %__MODULE__{state | mouse_report_mode: nil}
  end

  # Ensure a catch-all or proper handling for unmapped modes if necessary
  defp handle_decpm_set(state, _unknown_mode) do
    # Log this event, as it indicates an unhandled DEC private mode set.
    # Logger.warn("Attempted to set unhandled DEC private mode: #{inspect(unknown_mode)}")
    state # Return state unchanged
  end

  defp handle_decpm_reset(state, _unknown_mode) do
    # Logger.warn("Attempted to reset unhandled DEC private mode: #{inspect(unknown_mode)}")
    state # Return state unchanged
  end
end
