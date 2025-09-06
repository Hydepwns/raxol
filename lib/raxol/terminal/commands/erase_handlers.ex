defmodule Raxol.Terminal.Commands.EraseHandlers do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Eraser
  require Raxol.Core.Runtime.Log

  @spec get_buffer_state(Emulator.t()) ::
          {ScreenBuffer.t(), {integer(), integer()},
           Raxol.Terminal.ANSI.TextFormatting.text_style()}
  def get_buffer_state(emulator) do
    active_buffer = Emulator.get_screen_buffer(emulator)

    cursor_pos =
      case is_pid(emulator.cursor) do
        true ->
          result = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

          case result do
            {:ok, pos} -> pos
            pos when is_tuple(pos) and tuple_size(pos) == 2 -> pos
            _ -> {0, 0}
          end

        false ->
          {0, 0}
      end

    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()
    {active_buffer, cursor_pos, blank_style}
  end

  @spec handle_erase(
          Emulator.t(),
          :screen | :line,
          integer(),
          {integer(), integer()}
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_erase(emulator, type, erase_param, _pos) do
    {active_buffer, cursor_pos, default_style} = get_buffer_state(emulator)
    {row, col} = cursor_pos

    new_buffer =
      apply_erase_operation(
        active_buffer,
        type,
        erase_param,
        row,
        col,
        default_style
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  defp apply_erase_operation(
         active_buffer,
         type,
         erase_param,
         row,
         col,
         default_style
       ) do
    case {type, erase_param} do
      {:screen, 0} ->
        Eraser.clear_screen_from(active_buffer, row, col, default_style)

      {:screen, 1} ->
        Eraser.clear_screen_to(active_buffer, row, col, default_style)

      {:screen, 2} ->
        Eraser.clear_screen(active_buffer, default_style)

      {:screen, 3} ->
        clear_scrollback(active_buffer, default_style)

      {:line, 0} ->
        Eraser.clear_line_from(active_buffer, row, col, default_style)

      {:line, 1} ->
        Eraser.clear_line_to(active_buffer, row, col, default_style)

      {:line, 2} ->
        Eraser.clear_line(active_buffer, row, default_style)

      _ ->
        active_buffer
    end
  end

  @spec handle_j(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_j(emulator, params) do
    mode = get_valid_non_neg_param(params, 0, 0)
    active_buffer = Emulator.get_screen_buffer(emulator)

    # Get cursor position from emulator
    cursor_pos = get_cursor_position(emulator.cursor)

    # Update buffer with cursor position
    buffer_with_cursor = %{active_buffer | cursor_position: cursor_pos}

    new_buffer = Eraser.erase_in_display(buffer_with_cursor, mode)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @spec handle_k(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_k(emulator, params) do
    mode = get_valid_non_neg_param(params, 0, 0)
    active_buffer = Emulator.get_screen_buffer(emulator)

    # Get cursor position from emulator
    cursor_pos = get_cursor_position(emulator.cursor)

    # Update buffer with cursor position
    buffer_with_cursor = %{active_buffer | cursor_position: cursor_pos}

    new_buffer = Eraser.erase_in_line(buffer_with_cursor, mode)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @spec clear_scrollback(ScreenBuffer.t(), Cell.style()) :: ScreenBuffer.t()
  defp clear_scrollback(buffer, _default_style) do
    current_width = ScreenBuffer.get_width(buffer)
    current_height = ScreenBuffer.get_height(buffer)

    current_cells =
      Enum.map(0..(current_height - 1), fn y ->
        ScreenBuffer.get_line(buffer, y) ||
          List.duplicate(Cell.new(), current_width)
      end)

    %ScreenBuffer{
      cells: current_cells,
      width: current_width,
      height: current_height,
      scrollback: [],
      scrollback_limit: buffer.scrollback_limit,
      selection: nil,
      scroll_region: nil
    }
  end

  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          integer()
        ) :: integer()
  defp get_valid_non_neg_param(params, index, default) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= 0 ->
        value

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid parameter value at index #{index}, using default #{default}",
          %{}
        )

        default
    end
  end

  def handle_j_alias(emulator, params), do: handle_j(emulator, params)
  def handle_k_alias(emulator, params), do: handle_k(emulator, params)

  # Helper function to get cursor position from either PID or struct
  defp get_cursor_position(cursor) when is_pid(cursor) do
    Raxol.Terminal.Cursor.Manager.get_position(cursor)
  end

  defp get_cursor_position(%Raxol.Terminal.Cursor.Manager{} = cursor) do
    cursor.position
  end

  defp get_cursor_position(_) do
    # Default fallback
    {0, 0}
  end
end
