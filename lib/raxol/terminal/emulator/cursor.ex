defmodule Raxol.Terminal.Emulator.Cursor do
  @moduledoc """
  Handles cursor operations for the terminal emulator.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Moves the cursor to a specific position.
  """
  @spec move_to(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) ::
          EmulatorStruct.t()
  def move_to(%EmulatorStruct{} = emulator, row, col) do
    new_cursor = Manager.move_to(emulator.cursor, row, col)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  """
  @spec move_up(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_up(%EmulatorStruct{} = emulator, lines) do
    new_cursor =
      Manager.move_up(emulator.cursor, lines, emulator.width, emulator.height)

    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  """
  @spec move_down(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_down(%EmulatorStruct{} = emulator, lines) do
    new_cursor =
      Manager.move_down(emulator.cursor, lines, emulator.width, emulator.height)

    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  """
  @spec move_left(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_left(%EmulatorStruct{} = emulator, cols) do
    new_cursor =
      Manager.move_left(
        emulator.cursor,
        cols,
        emulator.mode_manager,
        emulator.scroll_region
      )

    %{emulator | cursor: new_cursor}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  """
  @spec move_right(EmulatorStruct.t(), non_neg_integer()) :: EmulatorStruct.t()
  def move_right(%EmulatorStruct{} = emulator, cols) do
    new_cursor =
      Manager.move_right(
        emulator.cursor,
        cols,
        emulator.mode_manager,
        emulator.scroll_region
      )

    %{emulator | cursor: new_cursor}
  end

  @doc """
  Sets the cursor style for the emulator.
  """
  @spec set_style(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def set_style(%EmulatorStruct{} = emulator, style) do
    %{emulator | cursor_style: style}
  end

  @doc """
  Saves the current cursor state.
  """
  @spec save_state(EmulatorStruct.t()) :: EmulatorStruct.t()
  def save_state(%EmulatorStruct{} = emulator) do
    saved_cursor = emulator.cursor
    %{emulator | saved_cursor: saved_cursor}
  end

  @doc """
  Restores the previously saved cursor state.
  """
  @spec restore_state(EmulatorStruct.t()) :: EmulatorStruct.t()
  def restore_state(%EmulatorStruct{} = emulator) do
    case emulator.saved_cursor do
      nil -> {:error, :no_saved_cursor}
      saved_cursor -> {:ok, %{emulator | cursor: saved_cursor}}
    end
  end

  @doc """
  Shows the cursor.
  """
  @spec show(EmulatorStruct.t()) :: EmulatorStruct.t()
  def show(%EmulatorStruct{} = emulator) do
    new_cursor = Manager.set_state(emulator.cursor, :visible)
    %{emulator | cursor: new_cursor}
  end

  @doc """
  Hides the cursor.
  """
  @spec hide(EmulatorStruct.t()) :: EmulatorStruct.t()
  def hide(%EmulatorStruct{} = emulator) do
    new_cursor = Manager.set_state(emulator.cursor, :hidden)
    %{emulator | cursor: new_cursor}
  end
end
