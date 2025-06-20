defmodule Raxol.Terminal.Commands.BufferHandlers do
  @moduledoc """
  Handles buffer manipulation commands.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Editor

  @doc """
  Handles the "l" command (insert blank lines).
  """
  def handle_l(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {:ok, updated_buffer} = Editor.insert_lines(active_buffer, y, count, nil)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  @doc """
  Handles the "m" command (delete lines).
  """
  def handle_m(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {:ok, updated_buffer} = Editor.delete_lines(active_buffer, y, count, nil)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  @doc """
  Handles the "x" command (erase characters).
  """
  def handle_x(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)
    {:ok, updated_buffer} = Editor.erase_chars(active_buffer, y, x, count, nil)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  # Functions expected by tests
  @doc """
  Handles the "L" command (insert lines) - alias for handle_l.
  """
  def handle_L(emulator, params) do
    count = Enum.at(params, 0, 1)
    handle_l(emulator, count)
  end

  @doc """
  Handles the "M" command (delete lines) - alias for handle_m.
  """
  def handle_M(emulator, params) do
    count = Enum.at(params, 0, 1)
    handle_m(emulator, count)
  end

  @doc """
  Handles the "P" command (delete characters).
  """
  def handle_P(emulator, params) do
    count = Enum.at(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)
    {:ok, updated_buffer} = Editor.delete_chars(active_buffer, y, x, count, nil)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  @doc """
  Handles the "X" command (erase characters) - alias for handle_x.
  """
  def handle_X(emulator, params) do
    count = Enum.at(params, 0, 1)
    handle_x(emulator, count)
  end

  @doc """
  Handles the "@" command (insert characters).
  """
  def handle_at(emulator, params) do
    count = Enum.at(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)
    {:ok, updated_buffer} = Editor.insert_chars(active_buffer, y, x, count, nil)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end
end
