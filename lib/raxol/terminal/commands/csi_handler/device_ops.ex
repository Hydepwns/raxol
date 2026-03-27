defmodule Raxol.Terminal.Commands.CSIHandler.DeviceOps do
  @moduledoc false
  alias Raxol.Terminal.Commands.CursorUtils

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

  defp save_cursor_position(emulator),
    do: CursorUtils.save_cursor_position(emulator)

  defp restore_cursor_position(emulator),
    do: CursorUtils.restore_cursor_position(emulator)
end
