defmodule Raxol.Terminal.Commands.BufferHandlers do
  @moduledoc false

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Editor

  def handle_l(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.insert_lines(active_buffer, y, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_m(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_lines(active_buffer, y, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_x(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.erase_chars(active_buffer, y, x, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_L(emulator, count) do
    buffer = emulator.main_screen_buffer
    {_x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    Raxol.Core.Runtime.Log.debug(
      "handle_L: calling Editor.insert_lines with buffer: #{inspect(buffer)}, y: #{y}, n: #{n}, style: #{inspect(style)}"
    )

    updated_buffer = Editor.insert_lines(buffer, y, n, style)

    Raxol.Core.Runtime.Log.debug(
      "handle_L: Editor.insert_lines returned: #{inspect(updated_buffer)}"
    )

    result = {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
    Raxol.Core.Runtime.Log.debug("handle_L: returning: #{inspect(result)}")
    result
  end

  def handle_M(emulator, count) do
    buffer = emulator.main_screen_buffer
    {_x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_lines(buffer, y, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_P(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_X(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.erase_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_at(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.insert_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end
end
