defmodule Raxol.Terminal.Emulator.CommandHandlers do
  @moduledoc """
  Handles CSI/ESC/SGR/OSC and related command logic for the terminal emulator.
  Extracted from the main emulator module for clarity and maintainability.
  """

  # Import/alias as needed for dependencies
  alias Raxol.Terminal.Emulator

  # handle_cursor_position/2
  def handle_cursor_position(params, emulator) do
    case String.split(params, ";") do
      [row_str, col_str] ->
        row = String.to_integer(row_str)
        col = String.to_integer(col_str)
        Emulator.move_cursor_to(
          emulator,
          {row - 1, col - 1},
          emulator.width,
          emulator.height
        )
      [pos_str] ->
        pos = String.to_integer(pos_str)
        Raxol.Terminal.Commands.CursorHandlers.move_cursor_to(emulator, {0, pos - 1}, emulator.width, emulator.height)
      _ ->
        emulator
    end
  end

  # handle_cursor_up/2
  def handle_cursor_up(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end
    Emulator.move_cursor_up(emulator, count)
  end

  # handle_cursor_down/2
  def handle_cursor_down(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end
    Emulator.move_cursor_down(emulator, count)
  end

  # handle_cursor_forward/2
  def handle_cursor_forward(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end
    Emulator.move_cursor_forward(emulator, count)
  end

  # handle_cursor_back/2
  def handle_cursor_back(params, emulator) do
    count =
      case params do
        "" -> 1
        count_str -> String.to_integer(count_str)
      end
    Emulator.move_cursor_back(emulator, count)
  end

  # handle_ed_command/2
  def handle_ed_command(params, emulator) do
    mode =
      case params do
        "" -> 0
        mode_str ->
          case Integer.parse(mode_str) do
            {val, _} -> val
            :error -> 0
          end
      end
    case mode do
      0 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 0)
      1 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 1)
      2 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 2)
      _ -> emulator
    end
  end

  # handle_el_command/2
  def handle_el_command(params, emulator) do
    mode =
      case params do
        "" -> 0
        mode_str ->
          case Integer.parse(mode_str) do
            {val, _} -> val
            :error -> 0
          end
      end
    case mode do
      0 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 0)
      1 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 1)
      2 -> Raxol.Terminal.Operations.ScreenOperations.erase_in_line(emulator, 2)
      _ -> emulator
    end
  end

  # handle_set_scroll_region/2
  def handle_set_scroll_region(params, emulator) do
    case String.split(params, ";") do
      [top_str, bottom_str] ->
        top = String.to_integer(top_str)
        bottom = String.to_integer(bottom_str)
        %{emulator | scroll_region: {top - 1, bottom - 1}}
      [""] ->
        %{emulator | scroll_region: nil}
      _ ->
        emulator
    end
  end

  # handle_set_mode/2
  def handle_set_mode(params, emulator) do
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, true)
          _ ->
            emulator
        end
      _ ->
        emulator
    end
  end

  # handle_reset_mode/2
  def handle_reset_mode(params, emulator) do
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, false)
          _ ->
            emulator
        end
      _ ->
        emulator
    end
  end

  # handle_set_standard_mode/2
  def handle_set_standard_mode(params, emulator) do
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_standard_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, true)
          _ ->
            emulator
        end
      _ ->
        emulator
    end
  end

  # handle_reset_standard_mode/2
  def handle_reset_standard_mode(params, emulator) do
    case parse_mode_params(params) do
      [mode_code] ->
        case lookup_standard_mode(mode_code) do
          {:ok, mode_name} ->
            set_mode_in_manager(emulator, mode_name, false)
          _ ->
            emulator
        end
      _ ->
        emulator
    end
  end

  # handle_esc_equals/1
  def handle_esc_equals(emulator) do
    set_mode_in_manager(emulator, :decckm, true)
  end

  # handle_esc_greater/1
  def handle_esc_greater(emulator) do
    set_mode_in_manager(emulator, :decckm, false)
  end

  # handle_sgr/2
  def handle_sgr(params, emulator) do
    updated_style = Raxol.Terminal.ANSI.SGRProcessor.handle_sgr(params, emulator.style)
    %{emulator | style: updated_style}
  end

  # handle_csi_general/3
  def handle_csi_general(params, final_byte, emulator) do
    case final_byte do
      "J" -> handle_ed_command(params, emulator)
      "K" -> handle_el_command(params, emulator)
      "H" -> handle_cursor_position(params, emulator)
      "A" -> handle_cursor_up(params, emulator)
      "B" -> handle_cursor_down(params, emulator)
      "C" -> handle_cursor_forward(params, emulator)
      "D" -> handle_cursor_back(params, emulator)
      _ -> emulator
    end
  end

  # Private helper functions
  defp parse_mode_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp lookup_mode(mode_code) do
    case Raxol.Terminal.ModeManager.lookup_private(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end

  defp lookup_standard_mode(mode_code) do
    case Raxol.Terminal.ModeManager.lookup_standard(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end

  defp set_mode_in_manager(emulator, mode_name, value) do
    mode_manager = emulator.mode_manager
    new_mode_manager = update_mode_manager_state(mode_manager, mode_name, value)
    emulator = %{emulator | mode_manager: new_mode_manager}
    handle_screen_buffer_switch(emulator, mode_name, value)
  end

  defp update_mode_manager_state(mode_manager, mode_name, value) do
    case get_mode_update_function(mode_name, value) do
      {:ok, update_fn} -> update_fn.(mode_manager)
      :error -> mode_manager
    end
  end

  defp get_mode_update_function(mode_name, value) do
    case Map.fetch(Raxol.Terminal.ModeHandlers.mode_updates(), mode_name) do
      {:ok, update_fn} ->
        {:ok, fn mode_manager -> update_fn.(mode_manager, value) end}
      :error ->
        :error
    end
  end

  defp handle_screen_buffer_switch(emulator, mode, true)
       when mode in [:alt_screen_buffer, :dec_alt_screen_save] do
    alt_buf =
      emulator.alternate_screen_buffer ||
        Raxol.Terminal.ScreenBuffer.new(emulator.width, emulator.height)

    Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 0})

    %{
      emulator
      | active_buffer_type: :alternate,
        alternate_screen_buffer: alt_buf
    }
  end

  defp handle_screen_buffer_switch(emulator, mode, false)
       when mode in [:alt_screen_buffer, :dec_alt_screen_save] do
    Raxol.Terminal.Cursor.Manager.set_position(emulator.cursor, {0, 0})
    %{emulator | active_buffer_type: :main}
  end

  defp handle_screen_buffer_switch(emulator, _mode, _value), do: emulator
end
