defmodule Raxol.Terminal.Emulator.Adapter do
  @moduledoc """
  Adapter module to make EmulatorLite compatible with existing code that
  expects the full Emulator struct.

  This module provides conversion functions and compatibility shims.
  """

  alias Raxol.Terminal.EmulatorLite
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager

  @doc """
  Converts an EmulatorLite to an Emulator struct for compatibility.

  Note: This creates a "hollow" Emulator with nil PIDs for GenServers.
  It's suitable for parsing and buffer operations but not for full
  terminal emulation with concurrent state management.
  """
  @spec from_lite(EmulatorLite.t()) :: Emulator.t()
  def from_lite(%EmulatorLite{} = lite) do
    %Emulator{
      # PIDs are nil - no GenServers
      state: nil,
      event: nil,
      buffer: nil,
      config: nil,
      command: nil,
      cursor: lite.cursor,
      window_manager: nil,
      mode_manager: lite.mode_manager,

      # Buffers
      active_buffer_type: lite.active_buffer_type,
      main_screen_buffer: lite.main_screen_buffer,
      alternate_screen_buffer: lite.alternate_screen_buffer,
      # Legacy field
      active: nil,
      # Legacy field
      alternate: nil,

      # Character sets
      charset_state: lite.charset_state,

      # Dimensions
      width: lite.width,
      height: lite.height,

      # Window state
      window_state: lite.window_state,
      window_title: lite.window_title,

      # Parser state
      parser_state: lite.parser_state,
      state_stack: [],

      # Command history
      command_history: lite.command_history || [],
      current_command_buffer: lite.current_command_buffer || "",
      max_command_history: lite.max_command_history,

      # Buffers
      scrollback_buffer: lite.scrollback_buffer,
      scrollback_limit: lite.scrollback_limit,
      output_buffer: lite.output_buffer,

      # Additional managers (nil for lite version)
      screen_buffer_manager: nil,
      output_manager: nil,
      cursor_manager: nil,
      scrollback_manager: nil,
      selection_manager: nil,
      mode_manager_pid: nil,
      style_manager: nil,
      damage_tracker: nil,

      # Mode and style
      mode_state: lite.mode_state,
      style: lite.style,
      cursor_style: lite.cursor_style,
      saved_cursor: lite.saved_cursor,

      # Scroll region
      scroll_region: lite.scroll_region,

      # Memory management
      # Default 100MB
      memory_limit: 100_000_000,

      # Session
      session_id: lite.session_id,
      client_options: lite.client_options,

      # Other state
      last_col_exceeded: lite.last_col_exceeded,
      cursor_blink_rate: 0,
      sixel_state: nil,
      plugin_manager: nil
    }
  end

  @doc """
  Converts a full Emulator to EmulatorLite, discarding GenServer references.

  This is useful for extracting just the state without the process overhead.
  """
  @spec to_lite(Emulator.t()) :: EmulatorLite.t()
  def to_lite(%Emulator{} = emulator) do
    %EmulatorLite{
      width: emulator.width,
      height: emulator.height,
      cursor: emulator.cursor,
      main_screen_buffer: emulator.main_screen_buffer,
      alternate_screen_buffer: emulator.alternate_screen_buffer,
      active_buffer_type: emulator.active_buffer_type,
      parser_state: emulator.parser_state,
      charset_state: emulator.charset_state,
      style: emulator.style,
      saved_style: nil,
      saved_cursor: emulator.saved_cursor,
      cursor_style: emulator.cursor_style,
      last_col_exceeded: emulator.last_col_exceeded,
      scroll_region: emulator.scroll_region,
      scrollback_buffer: emulator.scrollback_buffer,
      scrollback_limit: emulator.scrollback_limit,
      mode_manager: emulator.mode_manager || %ModeManager{},
      mode_state: emulator.mode_state,
      command_history: emulator.command_history,
      current_command_buffer: emulator.current_command_buffer,
      max_command_history: emulator.max_command_history,
      window_title: emulator.window_title,
      window_state: emulator.window_state,
      output_buffer: emulator.output_buffer || "",
      session_id: emulator.session_id,
      client_options: emulator.client_options
    }
  end

  @doc """
  Checks if an emulator is the lite version (no GenServers).
  """
  @spec lite?(Emulator.t() | EmulatorLite.t()) :: boolean()
  def lite?(%EmulatorLite{}), do: true
  def lite?(%Emulator{state: nil, event: nil, buffer: nil}), do: true
  def lite?(_), do: false

  @doc """
  Ensures we have an Emulator struct, converting from EmulatorLite if needed.

  This is a compatibility function for code that expects Emulator structs.
  """
  @spec ensure_emulator(Emulator.t() | EmulatorLite.t()) :: Emulator.t()
  def ensure_emulator(%Emulator{} = emulator), do: emulator
  def ensure_emulator(%EmulatorLite{} = lite), do: from_lite(lite)

  @doc """
  Ensures we have an EmulatorLite struct, converting from Emulator if needed.

  This is useful for performance-critical paths that don't need GenServers.
  """
  @spec ensure_lite(Emulator.t() | EmulatorLite.t()) :: EmulatorLite.t()
  def ensure_lite(%EmulatorLite{} = lite), do: lite
  def ensure_lite(%Emulator{} = emulator), do: to_lite(emulator)
end
