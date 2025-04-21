defmodule Raxol.Terminal.ANSI.ScreenModes do
  @moduledoc """
  Handles screen mode transitions and state management.
  This includes alternate screen buffer, cursor visibility,
  line wrapping, and other terminal modes.
  """

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
    # Use Alternate Screen Buffer
    47 => :dec_alt_screen,
    # Send Mouse X & Y on button press
    1000 => :mouse_report,
    # Use Cell Motion Mouse Tracking
    1002 => :mouse_motion,
    # Send FocusIn/FocusOut events
    1004 => :focus_events,
    # SGR Mouse Mode
    1006 => :sgr_mouse,
    # Save cursor and use Alternate Screen Buffer
    1049 => :alt_screen_buffer
  }

  # Standard Mode codes and their corresponding mode atoms
  @standard_modes %{
    # Insert Mode
    4 => :insert_mode,
    # Line Feed Mode
    20 => :line_feed_mode
  }

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
      :auto_repeat -> %{state | auto_repeat_mode: true}
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
      :auto_repeat -> %{state | auto_repeat_mode: false}
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
end
