defmodule Raxol.Terminal.ModeHandlers do
  @moduledoc """
  Handles terminal mode management functions.
  This module extracts the mode handling logic from the main emulator.
  """

  alias Raxol.Terminal.ModeManager

  @doc """
  Updates the insert mode in the mode manager.
  """
  @spec update_insert_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_insert_mode_direct(mode_manager, value) do
    %{mode_manager | insert_mode: value}
  end

  @doc """
  Updates the alternate buffer active state in the mode manager.
  """
  @spec update_alternate_buffer_active_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_alternate_buffer_active_direct(mode_manager, value) do
    %{mode_manager | alternate_buffer_active: value}
  end

  @doc """
  Updates the cursor keys mode in the mode manager.
  """
  @spec update_cursor_keys_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_cursor_keys_mode_direct(mode_manager, value) do
    %{
      mode_manager
      | cursor_keys_mode: if(value, do: :application, else: :normal)
    }
  end

  @doc """
  Updates the origin mode in the mode manager.
  """
  @spec update_origin_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_origin_mode_direct(mode_manager, value) do
    %{mode_manager | origin_mode: value}
  end

  @doc """
  Updates the line feed mode in the mode manager.
  """
  @spec update_line_feed_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_line_feed_mode_direct(mode_manager, value) do
    %{mode_manager | line_feed_mode: value}
  end

  @doc """
  Updates the auto wrap mode in the mode manager.
  """
  @spec update_auto_wrap_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_auto_wrap_direct(mode_manager, value) do
    %{mode_manager | auto_wrap: value}
  end

  @doc """
  Updates the cursor visible mode in the mode manager.
  """
  @spec update_cursor_visible_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_cursor_visible_direct(mode_manager, value) do
    %{mode_manager | cursor_visible: value}
  end

  @doc """
  Updates the screen mode reverse in the mode manager.
  """
  @spec update_screen_mode_reverse_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_screen_mode_reverse_direct(mode_manager, value) do
    %{mode_manager | screen_mode_reverse: value}
  end

  @doc """
  Updates the auto repeat mode in the mode manager.
  """
  @spec update_auto_repeat_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_auto_repeat_mode_direct(mode_manager, value) do
    %{mode_manager | auto_repeat_mode: value}
  end

  @doc """
  Updates the interlacing mode in the mode manager.
  """
  @spec update_interlacing_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_interlacing_mode_direct(mode_manager, value) do
    %{mode_manager | interlacing_mode: value}
  end

  @doc """
  Updates the bracketed paste mode in the mode manager.
  """
  @spec update_bracketed_paste_mode_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_bracketed_paste_mode_direct(mode_manager, value) do
    %{mode_manager | bracketed_paste_mode: value}
  end

  @doc """
  Updates the column width 132 mode in the mode manager.
  """
  @spec update_column_width_132_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_column_width_132_direct(mode_manager, value) do
    %{mode_manager | column_width_mode: if(value, do: :wide, else: :normal)}
  end

  @doc """
  Updates the column width 80 mode in the mode manager.
  """
  @spec update_column_width_80_direct(ModeManager.t(), boolean()) :: ModeManager.t()
  def update_column_width_80_direct(mode_manager, value) do
    %{mode_manager | column_width_mode: if(value, do: :normal, else: :wide)}
  end

  @doc """
  Returns the mapping of mode names to their corresponding update functions.
  """
  @spec mode_updates() :: map()
  def mode_updates do
    get_mode_update_mappings()
    |> Enum.map(fn {key, func} ->
      {key, Function.capture(__MODULE__, func, 2)}
    end)
    |> Map.new()
  end

  # Private functions

  defp get_mode_update_mappings do
    [
      {:irm, :update_insert_mode_direct},
      {:lnm, :update_line_feed_mode_direct},
      {:decom, :update_origin_mode_direct},
      {:decawm, :update_auto_wrap_direct},
      {:dectcem, :update_cursor_visible_direct},
      {:decscnm, :update_screen_mode_reverse_direct},
      {:decarm, :update_auto_repeat_mode_direct},
      {:decinlm, :update_interlacing_mode_direct},
      {:bracketed_paste, :update_bracketed_paste_mode_direct},
      {:decckm, :update_cursor_keys_mode_direct},
      {:deccolm_132, :update_column_width_132_direct},
      {:deccolm_80, :update_column_width_80_direct},
      {:dec_alt_screen, :update_alternate_buffer_active_direct},
      {:dec_alt_screen_save, :update_alternate_buffer_active_direct},
      {:alt_screen_buffer, :update_alternate_buffer_active_direct}
    ]
  end
end
