defmodule Raxol.Terminal.Emulator.CommandHandler do
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

        Raxol.Terminal.Commands.CursorHandler.move_cursor_to(
          emulator,
          {row - 1, col - 1},
          emulator.width,
          emulator.height
        )

      [pos_str] ->
        pos = String.to_integer(pos_str)

        Raxol.Terminal.Commands.CursorHandler.move_cursor_to(
          emulator,
          {0, pos - 1},
          emulator.width,
          emulator.height
        )

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
        "" ->
          0

        mode_str ->
          case Integer.parse(mode_str) do
            {val, _} -> val
            :error -> 0
          end
      end

    case mode do
      0 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 0)

      1 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 1)

      2 ->
        Raxol.Terminal.Operations.ScreenOperations.erase_in_display(emulator, 2)

      _ ->
        emulator
    end
  end

  # handle_el_command/2
  def handle_el_command(params, emulator) do
    mode =
      case params do
        "" ->
          0

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
      [mode_code] -> try_set_mode(emulator, mode_code, true)
      _ -> emulator
    end
  end

  # handle_reset_mode/2
  def handle_reset_mode(params, emulator) do
    case parse_mode_params(params) do
      [mode_code] -> try_set_mode(emulator, mode_code, false)
      _ -> emulator
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
    updated_style =
      Raxol.Terminal.ANSI.SGRProcessor.handle_sgr(params, emulator.style)

    log_sgr_debug(
      "DEBUG: handle_sgr - emulator.style before: #{inspect(emulator.style)}"
    )

    log_sgr_debug(
      "DEBUG: handle_sgr - updated_style: #{inspect(updated_style)}"
    )

    result = %{emulator | style: updated_style}

    log_sgr_debug(
      "DEBUG: handle_sgr - emulator.style after: #{inspect(result.style)}"
    )

    result
  end

  # handle_csi_general/4
  def handle_csi_general(params, final_byte, emulator, intermediates \\ "") do
    handle_csi_command(final_byte, params, emulator, intermediates)
  end

  # handle_device_attributes/3
  def handle_device_attributes(params, emulator, intermediates) do
    param_list = parse_params(params)

    case {intermediates, param_list} do
      {">", []} ->
        # CSI > c or CSI > 0 c (Secondary DA)
        response = "\e[>0;0;0c"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      {">", [0]} ->
        # CSI > 0 c (Secondary DA)
        response = "\e[>0;0;0c"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      {"", []} ->
        # CSI c (Primary DA)
        response = "\e[?6c"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      {"", [0]} ->
        # CSI 0 c (Primary DA)
        response = "\e[?6c"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      _ ->
        # Ignore all other params (including [1], [1, ...], etc)
        emulator
    end
  end

  # handle_device_status_report/2
  def handle_device_status_report(params, emulator) do
    # Parse parameters
    param_list = parse_params(params)

    case param_list do
      [5] ->
        # DSR 5n - Report device status (OK)
        # ESC [ 0 n (ready, no malfunctions)
        response = "\e[0n"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      [] ->
        # DSR with no parameters - Report device status (OK)
        # ESC [ 0 n (ready, no malfunctions)
        response = "\e[0n"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      [6] ->
        # DSR 6n - Report cursor position
        # ESC [ row ; col R
        {row, col} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
        response = "\e[#{row + 1};#{col + 1}R"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      _ ->
        # Unknown parameter, ignore
        emulator
    end
  end

  # parse_params/1 - Helper to parse parameter string into list of integers
  defp parse_params(params) when is_binary(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn param ->
      case Integer.parse(param) do
        {val, _} -> val
        :error -> 0
      end
    end)
  end

  defp parse_params(_), do: []

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
    case value do
      true ->
        case Raxol.Terminal.ModeManager.set_mode(emulator, [mode_name]) do
          {:ok, new_emulator} ->
            handle_screen_buffer_switch(new_emulator, mode_name, value)

          {:error, _} ->
            emulator
        end

      false ->
        case Raxol.Terminal.ModeManager.reset_mode(emulator, [mode_name]) do
          {:ok, new_emulator} ->
            handle_screen_buffer_switch(new_emulator, mode_name, value)

          {:error, _} ->
            emulator
        end
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

  defp log_sgr_debug(_msg) do
    # Disabled for performance - uncomment for debugging
    # File.write!("tmp/sgr_debug.log", msg <> "\n", [:append])
    :ok
  end

  defp handle_csi_command(final_byte, params, emulator, intermediates) do
    case csi_handlers()[final_byte] do
      {handler, _arity} -> apply(handler, [params, emulator, intermediates])
      nil -> emulator
    end
  end

  defp try_set_mode(emulator, mode_code, value) do
    case lookup_standard_mode(mode_code) do
      {:ok, mode_name} -> set_mode_in_manager(emulator, mode_name, value)
      :error -> try_private_mode(emulator, mode_code, value)
    end
  end

  defp try_private_mode(emulator, mode_code, value) do
    case lookup_mode(mode_code) do
      {:ok, mode_name} -> set_mode_in_manager(emulator, mode_name, value)
      :error -> emulator
    end
  end

  defp csi_handlers do
    %{
      "J" => {&handle_ed_command/2, 2},
      "K" => {&handle_el_command/2, 2},
      "H" => {&handle_cursor_position/2, 2},
      "A" => {&handle_cursor_up/2, 2},
      "B" => {&handle_cursor_down/2, 2},
      "C" => {&handle_cursor_forward/2, 2},
      "D" => {&handle_cursor_back/2, 2},
      "c" => {&handle_device_attributes/3, 3},
      "n" => {&handle_device_status_report/2, 2}
    }
  end
end
