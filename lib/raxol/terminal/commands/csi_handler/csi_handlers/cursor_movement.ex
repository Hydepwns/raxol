defmodule Raxol.Terminal.Commands.CSIHandler.CursorMovement do
  @moduledoc """
  Handlers for cursor movement CSI commands.
  """

  alias Raxol.Terminal.Commands.CSIHandler.Cursor

  @doc """
  Handles cursor up movement.
  """
  def handle_cursor_up(emulator, amount) do
    # Handle both PID-based and struct-based cursors
    case emulator.cursor do
      %{row: _, col: _} = cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        active_buffer = Raxol.Terminal.BufferManager.get_screen_buffer(emulator)
        _height = Raxol.Terminal.ScreenBuffer.get_height(active_buffer)

        new_row = max(0, cursor.row - amount)

        updated_cursor = %{
          cursor
          | row: new_row,
            position: {new_row, cursor.col}
        }

        %{emulator | cursor: updated_cursor}

      _ ->
        # For PID-based cursors, use the standard handler
        case Cursor.handle_command(
               emulator,
               [amount],
               ?A
             ) do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  @doc """
  Handles cursor down movement.
  """
  def handle_cursor_down(emulator, amount) do
    # Handle both PID-based and struct-based cursors
    case emulator.cursor do
      %{row: _, col: _} = cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        active_buffer = Raxol.Terminal.BufferManager.get_screen_buffer(emulator)
        height = Raxol.Terminal.ScreenBuffer.get_height(active_buffer)

        new_row = min(height - 1, cursor.row + amount)

        updated_cursor = %{
          cursor
          | row: new_row,
            position: {new_row, cursor.col}
        }

        %{emulator | cursor: updated_cursor}

      _ ->
        # For PID-based cursors, use the standard handler
        case Cursor.handle_command(
               emulator,
               [amount],
               ?B
             ) do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  @doc """
  Handles cursor forward movement.
  """
  def handle_cursor_forward(emulator, amount) do
    # Handle both PID-based and struct-based cursors
    case emulator.cursor do
      %{row: _, col: _} = cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        active_buffer = Raxol.Terminal.BufferManager.get_screen_buffer(emulator)
        width = Raxol.Terminal.ScreenBuffer.get_width(active_buffer)

        new_col = min(width - 1, cursor.col + amount)
        updated_cursor = %{cursor | col: new_col}
        %{emulator | cursor: updated_cursor}

      _ ->
        # For PID-based cursors, use the standard handler
        case Cursor.handle_command(
               emulator,
               [amount],
               ?C
             ) do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  @doc """
  Handles cursor backward movement.
  """
  def handle_cursor_backward(emulator, amount) do
    # Handle both PID-based and struct-based cursors
    case emulator.cursor do
      %{row: _, col: _} = cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        new_col = max(0, cursor.col - amount)
        updated_cursor = %{cursor | col: new_col}
        %{emulator | cursor: updated_cursor}

      _ ->
        # For PID-based cursors, use the standard handler
        case Cursor.handle_command(
               emulator,
               [amount],
               ?D
             ) do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  @doc """
  Handles direct cursor positioning with proper clamping.
  """
  def handle_cursor_position_direct(emulator, row, col) do
    # Handle direct coordinate setting with proper clamping
    active_buffer = Raxol.Terminal.BufferManager.get_screen_buffer(emulator)
    width = Raxol.Terminal.ScreenBuffer.get_width(active_buffer)
    height = Raxol.Terminal.ScreenBuffer.get_height(active_buffer)

    # Convert from 1-indexed ANSI coordinates to 0-indexed internal coordinates
    row_0_indexed = if row <= 0, do: 0, else: row - 1
    col_0_indexed = if col <= 0, do: 0, else: col - 1

    # Clamp coordinates to screen bounds
    row_clamped = max(0, min(row_0_indexed, height - 1))
    col_clamped = max(0, min(col_0_indexed, width - 1))

    # Update cursor position - handle different cursor formats
    updated_cursor =
      case emulator.cursor do
        %{row: _, col: _} = cursor ->
          %{
            cursor
            | row: row_clamped,
              col: col_clamped,
              position: {row_clamped, col_clamped}
          }

        %{position: _} = cursor ->
          %{
            cursor
            | position: {row_clamped, col_clamped}
          }

        _ ->
          Raxol.Terminal.Cursor.Manager.set_position(
            emulator.cursor,
            {row_clamped, col_clamped}
          )
      end

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  @doc """
  Handles cursor position with parameter parsing.
  """
  def handle_cursor_position(emulator, row, col)
      when is_integer(row) and is_integer(col) do
    # Handle direct row/col parameters (3-argument version for tests)
    # The test calls handle_cursor_position(emulator, 20, 20) expecting row=20, col=20
    # Convert from 1-indexed ANSI coordinates to 0-indexed internal coordinates
    row = max(0, row - 1)
    col = max(0, col - 1)

    case emulator.cursor do
      %{row: _, col: _} = cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        active_buffer = Raxol.Terminal.BufferManager.get_screen_buffer(emulator)
        width = Raxol.Terminal.ScreenBuffer.get_width(active_buffer)
        height = Raxol.Terminal.ScreenBuffer.get_height(active_buffer)

        # Clamp coordinates to screen bounds
        row_clamped = max(0, min(row, height - 1))
        col_clamped = max(0, min(col, width - 1))

        updated_cursor = %{
          cursor
          | row: row_clamped,
            col: col_clamped,
            position: {row_clamped, col_clamped}
        }

        %{emulator | cursor: updated_cursor}

      _ ->
        # For PID-based cursors, use the standard handler
        # ANSI cursor position command uses [row, col] order (1-indexed)
        result = Cursor.handle_command(emulator, [row + 1, col + 1], ?H)

        case result do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  def handle_cursor_position(emulator, params) do
    # The CSI parser already provides {row, col} in the correct order
    # params is already {row, col} from the CSI parser
    {row, col} =
      case params do
        {r, c} when is_integer(r) and is_integer(c) -> {r, c}
        # Handle params with semicolon
        [r, ?;, c] when is_integer(r) and is_integer(c) -> {r, c}
        [r, c] when is_integer(r) and is_integer(c) -> {r, c}
        [r] when is_integer(r) -> {r, 1}
        [] -> {1, 1}
        _ -> {1, 1}
      end

    # Handle both PID-based and struct-based cursors
    case emulator.cursor do
      %{row: _, col: _} = _cursor ->
        # For test cursors that have row/col fields (like CursorManager)
        # Use the direct cursor positioning function
        case handle_cursor_position_direct(emulator, row, col) do
          {:ok, updated_emulator} -> updated_emulator
          updated_emulator -> updated_emulator
        end

      _ ->
        # For PID-based cursors, use the standard handler
        result =
          Cursor.handle_command(
            emulator,
            [col, row],
            ?H
          )

        case result do
          {:ok, updated_emulator} -> updated_emulator
          {:error, _, _} -> emulator
          updated_emulator -> updated_emulator
        end
    end
  end

  @doc """
  Handles cursor column positioning.
  """
  def handle_cursor_column(emulator, column) do
    case Cursor.handle_command(
           emulator,
           [column],
           ?G
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end
end
