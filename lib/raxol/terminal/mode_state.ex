defmodule Raxol.Terminal.ModeState do
  @moduledoc """
  Manages terminal mode state and transitions.

  This module is responsible for:
  - Managing mode state
  - Handling mode transitions
  - Validating mode changes
  - Providing mode state queries
  """

  require Raxol.Core.Runtime.Log

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
    12 => :att_blink,
    # Text Cursor Enable Mode
    25 => :dectcem,
    # Use Alternate Screen Buffer (Simple)
    47 => :dec_alt_screen,
    # Send Mouse X & Y on button press
    1000 => :mouse_report_x10,
    # Use Cell Motion Mouse Tracking
    1002 => :mouse_report_cell_motion,
    # Send FocusIn/FocusOut events
    1004 => :focus_events,
    # SGR Mouse Mode
    1006 => :mouse_report_sgr,
    # Use Alt Screen, Save/Restore State (no clear)
    1047 => :dec_alt_screen_save,
    # Save/Restore Cursor Position (and attributes)
    1048 => :decsc_deccara,
    # Use Alt Screen, Save/Restore State, Clear on switch
    1049 => :alt_screen_buffer,
    # Enable bracketed paste mode
    2004 => :bracketed_paste
  }

  # Standard Mode codes and their corresponding mode atoms
  @standard_modes %{
    # Insert Mode
    4 => :irm,
    # Line Feed Mode
    20 => :lnm,
    # Column Width Mode
    3 => :deccolm_132,
    # 132 Column Mode
    132 => :deccolm_132,
    # 80 Column Mode
    80 => :deccolm_80
  }

  defstruct cursor_visible: true,
            auto_wrap: true,
            origin_mode: false,
            insert_mode: false,
            line_feed_mode: false,
            column_width_mode: :normal,
            cursor_keys_mode: :normal,
            screen_mode_reverse: false,
            auto_repeat_mode: true,
            interlacing_mode: false,
            alternate_buffer_active: false,
            mouse_report_mode: :none,
            focus_events_enabled: false,
            alt_screen_mode: nil,
            bracketed_paste_mode: false,
            active_buffer_type: :main

  @type t :: %__MODULE__{}

  @doc """
  Creates a new mode state with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

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
  Checks if a specific mode is enabled.

  ## Parameters
    * `state` - The current mode state
    * `mode` - The mode to check

  ## Returns
    * `boolean()` - Whether the mode is enabled
  """
  @spec mode_enabled?(t(), atom()) :: boolean()
  def mode_enabled?(state, mode) do
    case mode do
      :dectcem -> state.cursor_visible
      :decawm -> state.auto_wrap
      :decom -> state.origin_mode
      :irm -> state.insert_mode
      :lnm -> state.line_feed_mode
      :decckm -> state.cursor_keys_mode == :application
      :decscnm -> state.screen_mode_reverse
      :decarm -> state.auto_repeat_mode
      :decinlm -> state.interlacing_mode
      :focus_events -> state.focus_events_enabled
      :alt_screen_buffer -> state.alternate_buffer_active
      :dec_alt_screen -> state.alternate_buffer_active
      :dec_alt_screen_save -> state.alternate_buffer_active
      :bracketed_paste -> state.bracketed_paste_mode
      :mouse_report_x10 -> state.mouse_report_mode == :x10
      :mouse_report_cell_motion -> state.mouse_report_mode == :cell_motion
      :mouse_report_sgr -> state.mouse_report_mode == :sgr
      :deccolm_80 -> state.column_width_mode == :normal
      :deccolm_132 -> state.column_width_mode == :wide
      _ -> false
    end
  end

  @doc """
  Sets a mode to enabled state.

  ## Parameters
    * `state` - The current mode state
    * `mode` - The mode to enable

  ## Returns
    * `t()` - The updated mode state
  """
  @spec set_mode(t(), atom()) :: t()
  def set_mode(state, mode) do
    case mode do
      :dectcem -> %{state | cursor_visible: true}
      :decawm -> %{state | auto_wrap: true}
      :decom -> %{state | origin_mode: true}
      :irm -> %{state | insert_mode: true}
      :lnm -> %{state | line_feed_mode: true}
      :decckm -> %{state | cursor_keys_mode: :application}
      :decscnm -> %{state | screen_mode_reverse: true}
      :decarm -> %{state | auto_repeat_mode: true}
      :decinlm -> %{state | interlacing_mode: true}
      :focus_events -> %{state | focus_events_enabled: true}
      :bracketed_paste -> %{state | bracketed_paste_mode: true}
      :mouse_report_x10 -> %{state | mouse_report_mode: :x10}
      :mouse_report_cell_motion -> %{state | mouse_report_mode: :cell_motion}
      :mouse_report_sgr -> %{state | mouse_report_mode: :sgr}
      :deccolm_132 -> %{state | column_width_mode: :wide}
      :deccolm_80 -> %{state | column_width_mode: :normal}
      _ -> state
    end
  end

  @doc """
  Resets a mode to disabled state.

  ## Parameters
    * `state` - The current mode state
    * `mode` - The mode to disable

  ## Returns
    * `t()` - The updated mode state
  """
  @spec reset_mode(t(), atom()) :: t()
  def reset_mode(state, mode) do
    case mode do
      :dectcem -> %{state | cursor_visible: false}
      :decawm -> %{state | auto_wrap: false}
      :decom -> %{state | origin_mode: false}
      :irm -> %{state | insert_mode: false}
      :lnm -> %{state | line_feed_mode: false}
      :decckm -> %{state | cursor_keys_mode: :normal}
      :decscnm -> %{state | screen_mode_reverse: false}
      :decarm -> %{state | auto_repeat_mode: false}
      :decinlm -> %{state | interlacing_mode: false}
      :focus_events -> %{state | focus_events_enabled: false}
      :bracketed_paste -> %{state | bracketed_paste_mode: false}
      :mouse_report_x10 -> %{state | mouse_report_mode: :none}
      :mouse_report_cell_motion -> %{state | mouse_report_mode: :none}
      :mouse_report_sgr -> %{state | mouse_report_mode: :none}
      :deccolm_132 -> %{state | column_width_mode: :normal}
      :deccolm_80 -> %{state | column_width_mode: :normal}
      _ -> state
    end
  end

  @doc """
  Sets the alternate buffer mode.

  ## Parameters
    * `state` - The current mode state
    * `type` - The alternate buffer mode type

  ## Returns
    * `t()` - The updated mode state
  """
  @spec set_alternate_buffer_mode(t(), atom()) :: t()
  def set_alternate_buffer_mode(state, type) do
    %{state | alternate_buffer_active: true, alt_screen_mode: type}
  end

  @doc """
  Resets the alternate buffer mode.

  ## Parameters
    * `state` - The current mode state

  ## Returns
    * `t()` - The updated mode state
  """
  @spec reset_alternate_buffer_mode(t()) :: t()
  def reset_alternate_buffer_mode(state) do
    %{state | alternate_buffer_active: false, alt_screen_mode: nil}
  end
end
