defmodule Raxol.Terminal.Emulator.Helpers do
  @moduledoc """
  Utility and helper functions for the terminal emulator.
  Extracted from the main emulator module for clarity and reuse.
  """

  alias Raxol.Terminal.{Cursor, ScreenBuffer}

  @spec get_config_struct(Raxol.Terminal.Emulator.t()) :: any()
  def get_config_struct(%Raxol.Terminal.Emulator{config: pid})
      when is_pid(pid) do
    GenServer.call(pid, :get_state)
  end

  @spec get_window_manager_struct(Raxol.Terminal.Emulator.t()) :: any()
  def get_window_manager_struct(%Raxol.Terminal.Emulator{window_manager: pid})
      when is_pid(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Gets the cursor struct from the emulator.
  """
  @spec get_cursor_struct(Raxol.Terminal.Emulator.t()) :: Cursor.t()
  def get_cursor_struct(%Raxol.Terminal.Emulator{cursor: cursor}) do
    case is_pid(cursor) do
      true ->
        GenServer.call(cursor, :get_state)

      false ->
        cursor
    end
  end

  @spec get_mode_manager_struct(Raxol.Terminal.Emulator.t()) :: any()
  def get_mode_manager_struct(%Raxol.Terminal.Emulator{
        mode_manager: mode_manager
      }) do
    mode_manager
  end

  @doc """
  Gets the active buffer from the emulator.
  """
  @spec get_screen_buffer(Raxol.Terminal.Emulator.t()) :: ScreenBuffer.t()
  def get_screen_buffer(
        %Raxol.Terminal.Emulator{active_buffer_type: :main} = emulator
      ),
      do: emulator.main_screen_buffer

  def get_screen_buffer(
        %Raxol.Terminal.Emulator{active_buffer_type: :alternate} = emulator
      ),
      do: emulator.alternate_screen_buffer

  # Test helpers
  def get_cursor_struct_for_test(
        %Raxol.Terminal.Emulator{cursor: pid} = emulator
      )
      when is_pid(pid),
      do: get_cursor_struct(emulator)

  def get_mode_manager_struct_for_test(%Raxol.Terminal.Emulator{} = emulator),
    do: get_mode_manager_struct(emulator)

  def get_cursor_position_struct(
        %Raxol.Terminal.Emulator{cursor: cursor} = emulator
      ) do
    case is_pid(cursor) do
      true ->
        get_cursor_struct(emulator).position

      false ->
        # Handle non-pid cursor (e.g., in test environments)
        case cursor do
          %{position: position} -> position
          %{col: col, row: row} -> {col, row}
          _ -> {0, 0}
        end
    end
  end

  def get_cursor_visible_struct(
        %Raxol.Terminal.Emulator{cursor: pid} = emulator
      )
      when is_pid(pid),
      do: get_cursor_struct(emulator).visible

  def get_mode_manager_cursor_visible(%Raxol.Terminal.Emulator{} = emulator),
    do: get_mode_manager_struct(emulator).cursor_visible

  @doc """
  Gets the current cursor position.
  Returns {row, col} for consistency with ANSI standards.
  """
  @spec get_cursor_position(Raxol.Terminal.Emulator.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(%Raxol.Terminal.Emulator{cursor: cursor} = emulator) do
    case is_pid(cursor) do
      true ->
        cursor_struct = get_cursor_struct(emulator)
        # Cursor struct always has :position field
        %{position: {row, col}} = cursor_struct
        {row, col}

      false ->
        # Cursor struct always has :position field
        %{position: {row, col}} = cursor
        {row, col}
    end
  end
end
