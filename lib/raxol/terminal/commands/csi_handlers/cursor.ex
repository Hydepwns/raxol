defmodule Raxol.Terminal.Commands.CSIHandlers.Cursor do
  @moduledoc """
  Handles CSI cursor control sequences.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Emulator.Struct, as: Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.BufferManager

  @command_map %{
    ?A => {__MODULE__, :handle_cuu},
    ?B => {__MODULE__, :handle_cud},
    ?C => {__MODULE__, :handle_cuf},
    ?D => {__MODULE__, :handle_cub},
    ?E => {__MODULE__, :handle_cnl},
    ?F => {__MODULE__, :handle_cpl},
    ?G => {__MODULE__, :handle_cha},
    ?d => {__MODULE__, :handle_vpa},
    ?H => {__MODULE__, :handle_cup},
    ?f => {__MODULE__, :handle_hvp},
    ?` => {__MODULE__, :handle_hpa},
    ?' => {__MODULE__, :handle_vpr},
    ?$ => {__MODULE__, :handle_hpr}
  }

  @doc """
  Handles cursor movement commands.
  """
  def handle_command(emulator, params, byte) do
    case Map.get(@command_map, byte) do
      {module, function} -> apply(module, function, [emulator, params])
      nil -> {:ok, emulator}
    end
  end

  @doc "Handles Cursor Up (CUU - 'A')"
  @spec handle_cuu(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cuu(emulator, params) do
    lines = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_up(emulator, lines, width, height)
  end

  @doc "Handles Cursor Down (CUD - 'B')"
  @spec handle_cud(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cud(emulator, params) do
    lines = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_down(emulator, lines, width, height)
  end

  @doc "Handles Cursor Forward (CUF - 'C')"
  @spec handle_cuf(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cuf(emulator, params) do
    cols = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_right(emulator, cols, width, height)
  end

  @doc "Handles Cursor Backward (CUB - 'D')"
  @spec handle_cub(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cub(emulator, params) do
    cols = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_left(emulator, cols, width, height)
  end

  @doc "Handles Cursor Next Line (CNL - 'E')"
  @spec handle_cnl(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cnl(emulator, params) do
    lines = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_down(emulator, lines, width, height)
    Emulator.move_cursor_to_line_start(emulator)
  end

  @doc "Handles Cursor Previous Line (CPL - 'F')"
  @spec handle_cpl(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cpl(emulator, params) do
    lines = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_up(emulator, lines, width, height)
    Emulator.move_cursor_to_line_start(emulator)
  end

  @doc "Handles Cursor Horizontal Absolute (CHA - 'G')"
  @spec handle_cha(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cha(emulator, params) do
    col = get_valid_pos_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_to_column(emulator, col - 1, width, height)
  end

  @doc "Handles Cursor Position (CUP - 'H')"
  @spec handle_cup(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cup(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    col = get_valid_pos_param(params, 1, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)

    # Convert 1-indexed ANSI coordinates to 0-indexed internal coordinates
    # ANSI CUP command expects {row, col} format, but cursor stores {col, row}
    row_0 = row - 1
    col_0 = col - 1

    # Clamp to screen bounds
    row_clamped = max(0, min(row_0, height - 1))
    col_clamped = max(0, min(col_0, width - 1))

    # Update cursor position - cursor stores {col, row} format
    # For \e[10;5H: row=10, col=5 -> row_0=9, col_0=4 -> {4, 9}
    # The test expects {4, 9} which means {col, row} format
    # set_position expects {col, row} format
    updated_cursor =
      set_cursor_position(emulator.cursor, {col_clamped, row_clamped})

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc "Handles Horizontal Position Absolute (HPA - '`')"
  @spec handle_hpa(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_hpa(emulator, params) do
    col = get_valid_pos_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_to_column(emulator, col - 1, width, height)
  end

  @doc "Handles Vertical Position Absolute (VPA - 'd')"
  @spec handle_vpa(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_vpa(emulator, params) do
    row = get_valid_pos_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    {current_x, _} = Emulator.get_cursor_position(emulator)

    Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(
      emulator,
      {current_x, row - 1},
      width,
      height
    )
  end

  @doc "Handles Horizontal Position Relative (HPR - 'a')"
  @spec handle_hpr(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_hpr(emulator, params) do
    cols = get_valid_non_neg_param(params, 0, 1)
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    height = ScreenBuffer.get_height(active_buffer)
    Emulator.move_cursor_right(emulator, cols, width, height)
  end

  # Private helper functions
  defp get_valid_non_neg_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when integer?(value) and value >= 0 -> value
      _ -> default
    end
  end

  defp get_valid_pos_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      value when integer?(value) and value > 0 -> value
      _ -> default
    end
  end

  # Helper functions to handle cursor position
  defp set_cursor_position(cursor, position) when is_pid(cursor) do
    Raxol.Terminal.Cursor.Manager.set_position(cursor, position)
    cursor
  end

  defp set_cursor_position(cursor, {col, row}) when is_map(cursor) do
    # Handle both cursor formats
    case cursor do
      %{position: _} ->
        # Emulator cursor format with :position field
        %{cursor | position: {col, row}}

      %{row: _, col: _} ->
        # Test cursor format with :row and :col fields
        %{cursor | row: row, col: col, position: {col, row}}

      _ ->
        # Fallback
        cursor
    end
  end
end
