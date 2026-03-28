defmodule Raxol.Terminal.Commands.CommandServer.ModeOps do
  @moduledoc false

  alias Raxol.Terminal.ScreenBuffer

  def handle_set_mode(
        emulator,
        %{params: params, private_markers: private},
        _context
      ) do
    case private do
      "?" -> handle_dec_private_mode(emulator, params, :set)
      _ -> handle_ansi_mode(emulator, params, :set)
    end
  end

  def handle_reset_mode(
        emulator,
        %{params: params, private_markers: private},
        _context
      ) do
    case private do
      "?" -> handle_dec_private_mode(emulator, params, :reset)
      _ -> handle_ansi_mode(emulator, params, :reset)
    end
  end

  defp handle_ansi_mode(emulator, params, action) do
    updated_emulator =
      Enum.reduce(params, emulator, fn mode, acc ->
        apply_ansi_mode(acc, mode, action)
      end)

    {:ok, updated_emulator}
  end

  defp handle_dec_private_mode(emulator, params, action) do
    updated_emulator =
      Enum.reduce(params, emulator, fn mode, acc ->
        apply_dec_private_mode(acc, mode, action)
      end)

    {:ok, updated_emulator}
  end

  defp apply_ansi_mode(emulator, mode, action) do
    case {mode, action} do
      {4, :set} -> %{emulator | insert_mode: true}
      {4, :reset} -> %{emulator | insert_mode: false}
      {20, :set} -> %{emulator | automatic_newline: true}
      {20, :reset} -> %{emulator | automatic_newline: false}
      _ -> emulator
    end
  end

  defp apply_dec_private_mode(emulator, mode, action) do
    case {mode, action} do
      {1, :set} ->
        %{emulator | cursor_keys_mode: :application}

      {1, :reset} ->
        %{emulator | cursor_keys_mode: :normal}

      {25, :set} ->
        %{emulator | cursor_visible: true}

      {25, :reset} ->
        %{emulator | cursor_visible: false}

      {47, :set} ->
        switch_to_alternate_screen(emulator)

      {47, :reset} ->
        switch_to_main_screen(emulator)

      {1049, :set} ->
        emulator
        |> save_cursor_position()
        |> switch_to_alternate_screen_with_clear()

      {1049, :reset} ->
        emulator
        |> switch_to_main_screen()
        |> restore_cursor_position()

      _ ->
        emulator
    end
  end

  defp switch_to_alternate_screen(emulator) do
    %{emulator | screen_mode: :alternate, active_buffer_type: :alternate}
  end

  defp switch_to_alternate_screen_with_clear(emulator) do
    emulator
    |> switch_to_alternate_screen()
    |> clear_alternate_buffer()
  end

  defp switch_to_main_screen(emulator) do
    %{emulator | screen_mode: :main, active_buffer_type: :main}
  end

  defp save_cursor_position(emulator) do
    cursor = emulator.cursor

    updated_cursor = %{
      cursor
      | saved_row: cursor.row,
        saved_col: cursor.col,
        saved_position: {cursor.row, cursor.col}
    }

    %{emulator | cursor: updated_cursor}
  end

  defp restore_cursor_position(emulator) do
    cursor = emulator.cursor

    {new_row, new_col} =
      case {cursor.saved_row, cursor.saved_col} do
        {nil, nil} -> {0, 0}
        {row, col} -> {row, col}
      end

    updated_cursor = %{
      cursor
      | row: new_row,
        col: new_col,
        position: {new_row, new_col}
    }

    %{emulator | cursor: updated_cursor}
  end

  defp clear_alternate_buffer(emulator) do
    blank_buffer = ScreenBuffer.new(emulator.width, emulator.height)
    %{emulator | alternate_screen_buffer: blank_buffer}
  end
end
