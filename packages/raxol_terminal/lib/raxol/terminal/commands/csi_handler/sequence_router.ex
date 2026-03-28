defmodule Raxol.Terminal.Commands.CSIHandler.SequenceRouter do
  @moduledoc false

  alias Raxol.Terminal.Commands.CSIHandler

  def handle_sequence(emulator, params) do
    case params do
      [?A] ->
        unwrap(CSIHandler.handle_cursor_up(emulator, 1))

      [?B] ->
        unwrap(CSIHandler.handle_cursor_down(emulator, 1))

      [?C] ->
        unwrap(CSIHandler.handle_cursor_forward(emulator, 1))

      [?D] ->
        unwrap(CSIHandler.handle_cursor_backward(emulator, 1))

      [?H] ->
        %{emulator | cursor: %{emulator.cursor | row: 0, col: 0}}

      [?2, ?;, ?3, ?H] ->
        %{emulator | cursor: %{emulator.cursor | row: 1, col: 2}}

      [?s] ->
        unwrap(CSIHandler.handle_s(emulator, []))

      [?u] ->
        unwrap(CSIHandler.handle_u(emulator, []))

      [?J] ->
        unwrap(CSIHandler.handle_erase_display(emulator, 0))

      [?1, ?J] ->
        unwrap(CSIHandler.handle_erase_display(emulator, 1))

      [?2, ?J] ->
        unwrap(CSIHandler.handle_erase_display(emulator, 2))

      [?K] ->
        unwrap(CSIHandler.handle_erase_line(emulator, 0))

      [?1, ?K] ->
        unwrap(CSIHandler.handle_erase_line(emulator, 1))

      [?2, ?K] ->
        unwrap(CSIHandler.handle_erase_line(emulator, 2))

      [?N] ->
        unwrap(CSIHandler.handle_locking_shift(emulator, :g0))

      [?O] ->
        unwrap(CSIHandler.handle_locking_shift(emulator, :g1))

      [?P] ->
        unwrap(CSIHandler.handle_locking_shift(emulator, :g2))

      [?Q] ->
        unwrap(CSIHandler.handle_locking_shift(emulator, :g3))

      [?R] ->
        unwrap(CSIHandler.handle_single_shift(emulator, :g2))

      [?S] ->
        unwrap(CSIHandler.handle_single_shift(emulator, :g3))

      [?6, ?n] ->
        updated = CSIHandler.handle_device_status(emulator, 6)
        %{updated | device_status_reported: true}

      [?6, ?R] ->
        updated = CSIHandler.handle_device_status(emulator, 6)
        %{updated | cursor_position_reported: true}

      _ ->
        emulator
    end
  end

  defp unwrap({:ok, emulator}), do: emulator

  def handle_save_restore_cursor(emulator, [command]) do
    case command do
      ?s -> CSIHandler.handle_s(emulator, [])
      ?u -> CSIHandler.handle_u(emulator, [])
      _ -> {:ok, emulator}
    end
  end

  def handle_screen_clear(emulator, params) do
    mode =
      case params do
        [] -> 0
        [mode] -> mode
        [mode | _] -> mode
      end

    CSIHandler.handle_erase_display(emulator, mode)
  end

  def handle_line_clear(emulator, params) do
    mode =
      case params do
        [] -> 0
        [mode] -> mode
        [mode | _] -> mode
      end

    CSIHandler.handle_erase_line(emulator, mode)
  end
end
