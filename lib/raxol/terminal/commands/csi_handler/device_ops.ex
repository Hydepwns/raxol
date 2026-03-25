defmodule Raxol.Terminal.Commands.CSIHandler.DeviceOps do
  @moduledoc false

  def handle_device_command(emulator, params, intermediates, final_byte) do
    case final_byte do
      ?c ->
        Raxol.Terminal.Emulator.CommandHandler.handle_device_attributes(
          params,
          emulator,
          intermediates
        )

      ?n ->
        handle_device_status_report(emulator, params)

      ?s ->
        save_cursor_position(emulator)

      ?u ->
        restore_cursor_position(emulator)

      _ ->
        emulator
    end
  end

  def handle_device_status_report(emulator, params) do
    case params do
      [5] ->
        response = "\e[0n"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      [] ->
        response = "\e[0n"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      [6] ->
        response = "\e[#{emulator.cursor.row + 1};#{emulator.cursor.col + 1}R"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      _ ->
        emulator
    end
  end

  def handle_device_status(emulator, params) do
    param =
      case params do
        param when is_integer(param) -> param
        [param] when is_integer(param) -> param
        _ -> nil
      end

    case param do
      5 ->
        output = "\e[0n"
        %{emulator | output_buffer: emulator.output_buffer <> output}

      6 ->
        output = "\e[#{emulator.cursor.row + 1};#{emulator.cursor.col + 1}R"
        %{emulator | output_buffer: emulator.output_buffer <> output}

      _ ->
        emulator
    end
  end

  defp save_cursor_position(emulator) do
    cursor = emulator.cursor

    updated_cursor = %{
      cursor
      | saved_row: cursor.row,
        saved_col: cursor.col,
        saved_position: {cursor.row, cursor.col}
    }

    saved_cursor = cursor
    %{emulator | cursor: updated_cursor, saved_cursor: saved_cursor}
  end

  defp restore_cursor_position(emulator) do
    case Map.get(emulator, :saved_cursor) do
      nil ->
        cursor = emulator.cursor

        {new_row, new_col} =
          case {cursor.saved_row, cursor.saved_col} do
            {nil, nil} -> {cursor.row, cursor.col}
            {row, col} -> {row, col}
          end

        updated_cursor = %{
          cursor
          | row: new_row,
            col: new_col,
            position: {new_row, new_col}
        }

        %{emulator | cursor: updated_cursor}

      saved_cursor ->
        row = saved_cursor.row
        col = saved_cursor.col

        updated_cursor = %{
          emulator.cursor
          | row: row,
            col: col,
            position: {row, col},
            shape: Map.get(saved_cursor, :shape, emulator.cursor.shape),
            visible: Map.get(saved_cursor, :visible, emulator.cursor.visible)
        }

        %{emulator | cursor: updated_cursor}
    end
  end
end
