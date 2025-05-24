defmodule Raxol.Terminal.Emulator.Cursor do
  @moduledoc """
  Handles cursor operations for the terminal emulator.
  """

  require Logger

  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Emulator

  @doc """
  Moves the cursor to a specific position.
  """
  @spec move_to(Emulator.t(), non_neg_integer(), non_neg_integer()) :: Emulator.t()
  def move_to(%Emulator{} = emulator, row, col) do
    new_cursor = Manager.move_to(emulator.cursor, row, col)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  @spec move_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_up(%Emulator{} = emulator, lines) do
    new_cursor = Manager.move_up(emulator.cursor, lines, emulator.mode_manager, emulator.scroll_region)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  @spec move_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_down(%Emulator{} = emulator, lines) do
    new_cursor = Manager.move_down(emulator.cursor, lines, emulator.mode_manager, emulator.scroll_region)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  @spec move_left(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_left(%Emulator{} = emulator, cols) do
    new_cursor = Manager.move_left(emulator.cursor, cols, emulator.mode_manager, emulator.scroll_region)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  @spec move_right(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def move_right(%Emulator{} = emulator, cols) do
    new_cursor = Manager.move_right(emulator.cursor, cols, emulator.mode_manager, emulator.scroll_region)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Sets the cursor style.
  """
  @spec set_style(Emulator.t(), atom()) :: Emulator.t()
  def set_style(%Emulator{} = emulator, style) do
    %{emulator | cursor_style: style}
  end

  @doc """
  Saves the current cursor state.
  """
  @spec save_state(Emulator.t()) :: Emulator.t()
  def save_state(%Emulator{} = emulator) do
    saved_cursor = emulator.cursor
    %{emulator | saved_cursor: saved_cursor}
  end

  @doc """
  Restores the previously saved cursor state.
  """
  @spec restore_state(Emulator.t()) :: Emulator.t()
  def restore_state(%Emulator{} = emulator) do
    case emulator.saved_cursor do
      nil -> emulator
      saved_cursor -> %{emulator | cursor: saved_cursor}
    end
  end

  @doc """
  Shows the cursor.
  """
  @spec show(Emulator.t()) :: Emulator.t()
  def show(%Emulator{} = emulator) do
    new_cursor = Manager.set_state(emulator.cursor, :visible)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Hides the cursor.
  """
  @spec hide(Emulator.t()) :: Emulator.t()
  def hide(%Emulator{} = emulator) do
    new_cursor = Manager.set_state(emulator.cursor, :hidden)
    %{emulator | cursor: new_cursor}
  end
end
