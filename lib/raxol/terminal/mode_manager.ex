defmodule Raxol.Terminal.ModeManager do
  @moduledoc """
  Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.

  This module centralizes the state and logic for various terminal modes,
  handling both simple flag toggles and modes with side effects on the
  emulator state (like screen buffer switching or resizing).
  """

  use GenServer
  require Logger

  require Raxol.Core.Runtime.Log

  # Needed for functions modifying Emulator state
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Modes.ModeStateManager
  alias Raxol.Terminal.Modes.Handlers.{
    DECPrivateHandler,
    StandardHandler,
    MouseHandler,
    ScreenBufferHandler
  }
  alias Raxol.Terminal.Modes.Types.ModeTypes

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
    # KAM (Keyboard Action Mode) could be added here if needed in the future.
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

  @impl true
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, ModeStateManager.new()}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:set_mode, mode, value}, _from, state) do
    case ModeStateManager.set_mode(state, mode, value) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_mode, mode}, _from, state) do
    value = ModeStateManager.mode_enabled?(state, mode)
    {:reply, value, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # Handle periodic updates
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Terminating (Reason: #{inspect(reason)})",
      %{module: __MODULE__, reason: reason}
    )

    :ok
  end

  # --- Mode Lookup ---

  @doc """
  Looks up a DEC private mode code and returns the corresponding mode atom.
  """
  @spec lookup_private(integer()) :: mode() | nil
  def lookup_private(code) when is_integer(code) do
    case ModeTypes.lookup_private(code) do
      nil -> nil
      mode_def -> mode_def.name
    end
  end

  @doc """
  Looks up a standard mode code and returns the corresponding mode atom.
  """
  @spec lookup_standard(integer()) :: mode() | nil
  def lookup_standard(code) when is_integer(code) do
    case ModeTypes.lookup_standard(code) do
      nil -> nil
      mode_def -> mode_def.name
    end
  end

  # --- Mode Setting/Resetting ---

  @doc """
  Sets one or more modes. Dispatches to specific handlers.
  Returns potentially updated Emulator state if side effects occurred.
  """
  @spec set_mode(Emulator.t(), [mode()]) :: {:ok, Emulator.t()} | {:error, term()}
  def set_mode(emulator, modes) when is_list(modes) do
    Enum.reduce_while(modes, {:ok, emulator}, fn mode, {:ok, emu} ->
      case do_set_mode(mode, emu) do
        {:ok, new_emu} -> {:cont, {:ok, new_emu}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Resets one or more modes. Dispatches to specific handlers.
  Returns potentially updated Emulator state if side effects occurred.
  """
  @spec reset_mode(Emulator.t(), [mode()]) :: {:ok, Emulator.t()} | {:error, term()}
  def reset_mode(emulator, modes) when is_list(modes) do
    Enum.reduce_while(modes, {:ok, emulator}, fn mode, {:ok, emu} ->
      case do_reset_mode(mode, emu) do
        {:ok, new_emu} -> {:cont, {:ok, new_emu}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # --- Private Set/Reset Helpers ---

  defp do_set_mode(mode_name, emulator) do
    with {:ok, mode_def} <- find_mode_definition(mode_name),
         {:ok, new_state} <- ModeStateManager.set_mode(emulator.mode_manager, mode_name, true),
         {:ok, new_emu} <- apply_mode_effects(mode_def, emulator) do
      {:ok, %{new_emu | mode_manager: new_state}}
    end
  end

  defp do_reset_mode(mode_name, emulator) do
    with {:ok, mode_def} <- find_mode_definition(mode_name),
         {:ok, new_state} <- ModeStateManager.reset_mode(emulator.mode_manager, mode_name),
         {:ok, new_emu} <- apply_mode_effects(mode_def, emulator) do
      {:ok, %{new_emu | mode_manager: new_state}}
    end
  end

  defp find_mode_definition(mode_name) do
    case ModeTypes.get_all_modes()
         |> Map.values()
         |> Enum.find(&(&1.name == mode_name)) do
      nil -> {:error, :invalid_mode}
      mode_def -> {:ok, mode_def}
    end
  end

  defp apply_mode_effects(mode_def, emulator) do
    case mode_def.category do
      :dec_private -> DECPrivateHandler.handle_mode_change(mode_def.name, true, emulator)
      :standard -> StandardHandler.handle_mode_change(mode_def.name, true, emulator)
      :mouse -> MouseHandler.handle_mode_change(mode_def.name, true, emulator)
      :screen_buffer -> ScreenBufferHandler.handle_mode_change(mode_def.name, true, emulator)
    end
  end
end
