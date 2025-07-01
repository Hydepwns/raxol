defmodule Raxol.Terminal.ModeManager do
  @moduledoc """
  Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.

  This module centralizes the state and logic for various terminal modes,
  handling both simple flag toggles and modes with side effects on the
  emulator state (like screen buffer switching or resizing).
  """

  require Logger

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Modes.ModeStateManager

  alias Raxol.Terminal.Modes.Handlers.{
    DECPrivateHandler,
    StandardHandler,
    MouseHandler,
    ScreenBufferHandler
  }

  alias Raxol.Terminal.Modes.Types.ModeTypes
  alias Raxol.Terminal.ModeManager.{SavedState}
  import Raxol.Guards

  @screen_buffer_module Application.compile_env(
                          :raxol,
                          :screen_buffer_impl,
                          Raxol.Terminal.ScreenBuffer
                        )

  @type mode :: atom()

  @dec_private_modes %{
    1 => :decckm,
    3 => :deccolm_132,
    80 => :deccolm_80,
    5 => :decscnm,
    6 => :decom,
    7 => :decawm,
    8 => :decarm,
    9 => :decinlm,
    12 => :att_blink,
    25 => :dectcem,
    47 => :dec_alt_screen,
    1000 => :mouse_report_x10,
    1002 => :mouse_report_cell_motion,
    1004 => :focus_events,
    1006 => :mouse_report_sgr,
    1047 => :dec_alt_screen_save,
    1048 => :decsc_deccara,
    1049 => :alt_screen_buffer,
    2004 => :bracketed_paste
  }

  @standard_modes %{
    4 => :irm,
    20 => :lnm,
    3 => :deccolm_132,
    132 => :deccolm_132,
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

  # --- Mode Lookup ---

  @doc """
  Looks up a DEC private mode code and returns the corresponding mode atom.
  """
  @spec lookup_private(integer()) :: mode() | nil
  def lookup_private(code) when integer?(code) do
    case ModeTypes.lookup_private(code) do
      nil -> nil
      mode_def -> mode_def.name
    end
  end

  @doc """
  Looks up a standard mode code and returns the corresponding mode atom.
  """
  @spec lookup_standard(integer()) :: mode() | nil
  def lookup_standard(code) when integer?(code) do
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
  @spec set_mode(Emulator.t(), [mode()]) ::
          {:ok, Emulator.t()} | {:error, term()}
  def set_mode(emulator, modes) when list?(modes) do
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
  @spec reset_mode(Emulator.t(), [mode()]) ::
          {:ok, Emulator.t()} | {:error, term()}
  def reset_mode(emulator, modes) when list?(modes) do
    Enum.reduce_while(modes, {:ok, emulator}, fn mode, {:ok, emu} ->
      case do_reset_mode(mode, emu) do
        {:ok, new_emu} -> {:cont, {:ok, new_emu}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Checks if a mode is enabled.
  """
  @spec mode_enabled?(t(), mode()) :: boolean()
  def mode_enabled?(state, mode) do
    case mode do
      :irm -> state.insert_mode
      :lnm -> state.line_feed_mode
      :decom -> state.origin_mode
      :decawm -> state.auto_wrap
      :dectcem -> state.cursor_visible
      :decscnm -> state.screen_mode_reverse
      :decarm -> state.auto_repeat_mode
      :decinlm -> state.interlacing_mode
      :bracketed_paste -> state.bracketed_paste_mode
      :decckm -> state.cursor_keys_mode == :application
      :deccolm_132 -> state.column_width_mode == :wide
      :deccolm_80 -> state.column_width_mode == :normal
      :dec_alt_screen -> state.alternate_buffer_active
      :dec_alt_screen_save ->
        IO.puts("DEBUG: mode_enabled? :dec_alt_screen_save = #{inspect(state.alternate_buffer_active)}")
        state.alternate_buffer_active
      :alt_screen_buffer -> state.alternate_buffer_active
      _ -> false
    end
  end

  @doc """
  Saves the current terminal state.
  """
  @spec save_state(Emulator.t()) :: Emulator.t()
  def save_state(emulator) do
    SavedState.save_state(emulator)
  end

  @doc """
  Restores the previously saved terminal state.
  """
  @spec restore_state(Emulator.t()) :: Emulator.t()
  def restore_state(emulator) do
    SavedState.restore_state(emulator)
  end

  # --- Private Set/Reset Helpers ---

  defp do_set_mode(mode_name, emulator) do
    with {:ok, mode_def} <- find_mode_definition(mode_name),
         {:ok, new_emu} <- apply_mode_effects(mode_def, emulator, true) do
      new_mode_manager = update_mode_manager_state(emulator.mode_manager, mode_name, true)
      {:ok, %{new_emu | mode_manager: new_mode_manager}}
    end
  end

  defp do_reset_mode(mode_name, emulator) do
    with {:ok, mode_def} <- find_mode_definition(mode_name),
         {:ok, new_emu} <- apply_mode_effects(mode_def, emulator, false) do
      new_mode_manager = update_mode_manager_state(emulator.mode_manager, mode_name, false)
      {:ok, %{new_emu | mode_manager: new_mode_manager}}
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

  defp apply_mode_effects(mode_def, emulator, value) do
    case mode_def.category do
      :dec_private ->
        DECPrivateHandler.handle_mode_change(mode_def.name, value, emulator)

      :standard ->
        StandardHandler.handle_mode_change(mode_def.name, value, emulator)

      :mouse ->
        MouseHandler.handle_mode_change(mode_def.name, value, emulator)

      :screen_buffer ->
        ScreenBufferHandler.handle_mode_change(mode_def.name, value, emulator)
    end
  end

  defp update_mode_manager_state(mode_manager, mode_name, value) do
    case mode_name do
      :irm -> %{mode_manager | insert_mode: value}
      :lnm -> %{mode_manager | line_feed_mode: value}
      :decom -> %{mode_manager | origin_mode: value}
      :decawm -> %{mode_manager | auto_wrap: value}
      :dectcem -> %{mode_manager | cursor_visible: value}
      :decscnm -> %{mode_manager | screen_mode_reverse: value}
      :decarm -> %{mode_manager | auto_repeat_mode: value}
      :decinlm -> %{mode_manager | interlacing_mode: value}
      :bracketed_paste -> %{mode_manager | bracketed_paste_mode: value}
      :decckm -> %{mode_manager | cursor_keys_mode: if(value, do: :application, else: :normal)}
      :deccolm_132 -> %{mode_manager | column_width_mode: if(value, do: :wide, else: :normal)}
      :deccolm_80 -> %{mode_manager | column_width_mode: if(value, do: :normal, else: :wide)}
      :dec_alt_screen -> %{mode_manager | alternate_buffer_active: value}
      :dec_alt_screen_save ->
        IO.puts("DEBUG: update_mode_manager_state :dec_alt_screen_save set to #{inspect(value)}")
        %{mode_manager | alternate_buffer_active: value}
      :alt_screen_buffer -> %{mode_manager | alternate_buffer_active: value}
      _ -> mode_manager
    end
  end

  @doc """
  Creates a new mode manager with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the mode manager.
  """
  @spec get_manager(t()) :: map()
  def get_manager(_state) do
    %{}
  end

  @doc """
  Updates the mode manager.
  """
  @spec update_manager(t(), map()) :: t()
  def update_manager(state, _modes) do
    state
  end

  @doc """
  Checks if the given mode is set.
  """
  @spec mode_set?(t(), atom()) :: boolean()
  def mode_set?(_state, _mode) do
    false
  end

  @doc """
  Gets the set modes.
  """
  @spec get_set_modes(t()) :: list()
  def get_set_modes(_state) do
    []
  end

  @doc """
  Resets all modes.
  """
  @spec reset_all_modes(t()) :: t()
  def reset_all_modes(state) do
    state
  end

  @doc """
  Saves the current modes.
  """
  @spec save_modes(t()) :: t()
  def save_modes(state) do
    state
  end

  @doc """
  Restores the saved modes.
  """
  @spec restore_modes(t()) :: t()
  def restore_modes(state) do
    state
  end

  @doc """
  Sets a mode with a value and private flag.
  """
  @spec set_mode(Emulator.t(), mode(), boolean(), boolean()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def set_mode(emulator, mode, value, private) do
    case private do
      true -> set_private_mode(emulator, mode, value)
      false -> set_standard_mode(emulator, mode, value)
    end
  end

  @doc """
  Sets a private mode with a value.
  """
  @spec set_private_mode(Emulator.t(), mode(), boolean()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def set_private_mode(emulator, mode, value) do
    case DECPrivateHandler.handle_mode(emulator, mode, value) do
      {:ok, new_emu} -> {:ok, new_emu}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sets a standard mode with a value.
  """
  @spec set_standard_mode(Emulator.t(), mode(), boolean()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def set_standard_mode(emulator, mode, value) do
    case StandardHandler.handle_mode(emulator, mode, value) do
      {:ok, new_emu} -> {:ok, new_emu}
      {:error, reason} -> {:error, reason}
    end
  end

  # Mode update functions for emulator delegation
  @doc """
  Updates the insert mode.
  """
  @spec update_insert_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_insert_mode(emulator, value) do
    case set_mode(emulator, :irm, value, false) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the line feed mode.
  """
  @spec update_line_feed_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_line_feed_mode(emulator, value) do
    case set_mode(emulator, :lnm, value, false) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the origin mode.
  """
  @spec update_origin_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_origin_mode(emulator, value) do
    case set_mode(emulator, :decom, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the auto wrap mode.
  """
  @spec update_auto_wrap_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_auto_wrap_mode(emulator, value) do
    case set_mode(emulator, :decawm, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the cursor visible mode.
  """
  @spec update_cursor_visible(Emulator.t(), boolean()) :: Emulator.t()
  def update_cursor_visible(emulator, value) do
    case set_mode(emulator, :dectcem, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the screen mode reverse.
  """
  @spec update_screen_mode_reverse(Emulator.t(), boolean()) :: Emulator.t()
  def update_screen_mode_reverse(emulator, value) do
    case set_mode(emulator, :decscnm, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the auto repeat mode.
  """
  @spec update_auto_repeat_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_auto_repeat_mode(emulator, value) do
    case set_mode(emulator, :decarm, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the interlacing mode.
  """
  @spec update_interlacing_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_interlacing_mode(emulator, value) do
    case set_mode(emulator, :decinlm, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the bracketed paste mode.
  """
  @spec update_bracketed_paste_mode(Emulator.t(), boolean()) :: Emulator.t()
  def update_bracketed_paste_mode(emulator, value) do
    case set_mode(emulator, :bracketed_paste, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end

  @doc """
  Updates the column width 132 mode.
  """
  @spec update_column_width_132(Emulator.t(), boolean()) :: Emulator.t()
  def update_column_width_132(emulator, value) do
    case set_mode(emulator, :deccolm_132, value, true) do
      {:ok, new_emu} -> new_emu
      {:error, _} -> emulator
    end
  end
end
