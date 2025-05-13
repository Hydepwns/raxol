defmodule Raxol.Terminal.Emulator.Cursor do
  @moduledoc """
  Handles cursor management for the terminal emulator.
  Provides functions for cursor position, style, movement, and state management.
  """

  require Logger

  alias Raxol.Terminal.{
    Cursor.Manager,
    Core
  }

  @doc """
  Moves the cursor to the specified position.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec move_to(Core.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def move_to(%Core{} = emulator, row, col) do
    case Manager.move_to(emulator.cursor, row, col) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Moves the cursor up by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec move_up(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def move_up(%Core{} = emulator, lines) when lines > 0 do
    case Manager.move_up(emulator.cursor, lines) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def move_up(%Core{} = _emulator, lines) do
    {:error, "Invalid move lines: #{inspect(lines)}"}
  end

  @doc """
  Moves the cursor down by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec move_down(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def move_down(%Core{} = emulator, lines) when lines > 0 do
    case Manager.move_down(emulator.cursor, lines) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def move_down(%Core{} = _emulator, lines) do
    {:error, "Invalid move lines: #{inspect(lines)}"}
  end

  @doc """
  Moves the cursor left by the specified number of columns.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec move_left(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def move_left(%Core{} = emulator, cols) when cols > 0 do
    case Manager.move_left(emulator.cursor, cols) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def move_left(%Core{} = _emulator, cols) do
    {:error, "Invalid move columns: #{inspect(cols)}"}
  end

  @doc """
  Moves the cursor right by the specified number of columns.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec move_right(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def move_right(%Core{} = emulator, cols) when cols > 0 do
    case Manager.move_right(emulator.cursor, cols) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def move_right(%Core{} = _emulator, cols) do
    {:error, "Invalid move columns: #{inspect(cols)}"}
  end

  @doc """
  Sets the cursor style.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_style(Core.t(), Core.cursor_style_type()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def set_style(%Core{} = emulator, style)
      when style in [
             :blinking_block,
             :steady_block,
             :blinking_underline,
             :steady_underline,
             :blinking_bar,
             :steady_bar
           ] do
    {:ok, %{emulator | cursor_style: style}}
  end

  def set_style(%Core{} = _emulator, invalid_style) do
    {:error, "Invalid cursor style: #{inspect(invalid_style)}"}
  end

  @doc """
  Saves the current cursor state.
  Returns {:ok, updated_emulator}.
  """
  @spec save_state(Core.t()) :: {:ok, Core.t()}
  def save_state(%Core{} = emulator) do
    saved_cursor = emulator.cursor
    {:ok, %{emulator | saved_cursor: saved_cursor}}
  end

  @doc """
  Restores the previously saved cursor state.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec restore_state(Core.t()) :: {:ok, Core.t()} | {:error, String.t()}
  def restore_state(%Core{} = emulator) do
    case emulator.saved_cursor do
      nil ->
        {:error, "No saved cursor state"}

      saved_cursor ->
        {:ok, %{emulator | cursor: saved_cursor}}
    end
  end

  @doc """
  Shows the cursor.
  Returns {:ok, updated_emulator}.
  """
  @spec show(Core.t()) :: {:ok, Core.t()}
  def show(%Core{} = emulator) do
    case Manager.show(emulator.cursor) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Hides the cursor.
  Returns {:ok, updated_emulator}.
  """
  @spec hide(Core.t()) :: {:ok, Core.t()}
  def hide(%Core{} = emulator) do
    case Manager.hide(emulator.cursor) do
      {:ok, updated_cursor} ->
        {:ok, %{emulator | cursor: updated_cursor}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
