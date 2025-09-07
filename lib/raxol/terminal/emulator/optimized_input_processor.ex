defmodule Raxol.Terminal.Emulator.OptimizedInputProcessor do
  @moduledoc """
  Optimized input processing for the terminal emulator.

  This module provides performance-optimized versions of input processing
  functions with the following improvements:

  - Removed debug IO.puts statements
  - Optimized string concatenation using iolists
  - Reduced function calls and pattern matching
  - Implemented caching for charset commands
  - Minimized cursor position checks
  """

  import Raxol.Core.Performance.Optimizer
  import :erlang, only: [iolist_to_binary: 1]
  alias Raxol.Core.Performance.Profiler
  alias Raxol.Terminal.{ScreenBuffer, Input.CoreHandler}

  # Cache charset commands for faster lookup
  @charset_commands %{
    "\e)0" => {:g1, :dec_special_graphics},
    "\e(B" => {:g0, :us_ascii},
    "\e*0" => {:g2, :dec_special_graphics},
    "\x0E" => {:gl, :g1},
    "\x0F" => {:gl, :g0},
    "\en" => {:gl, :g2},
    "\eo" => {:gl, :g3},
    "\e~" => {:gr, :g2},
    "\e}" => {:gr, :g1},
    "\e|" => {:gr, :g3}
  }

  @doc """
  Optimized version of process_input that minimizes allocations and function calls.
  """
  def process_input(emulator, input) do
    cached :input_processing, key: "process_#{:erlang.phash2(input)}", ttl: 1000 do
      do_process_input(emulator, input)
    end
  end

  defp do_process_input(emulator, input) do
    # Fast path for common single character input
    case byte_size(input) do
      1 -> process_single_char(emulator, input)
      _ -> process_multi_char(emulator, input)
    end
  end

  defp process_single_char(emulator, <<char>>)
       when char >= 32 and char <= 126 do
    # Fast path for printable ASCII
    CoreHandler.process_terminal_input(emulator, <<char>>)
  end

  defp process_single_char(emulator, input) do
    process_multi_char(emulator, input)
  end

  defp process_multi_char(emulator, input) do
    # Check for mouse events using binary pattern matching
    case input do
      <<0x1B, ?[, ?M, button, x, y, rest::binary>> ->
        handle_mouse_event(emulator, button, x, y, rest)

      _ ->
        handle_non_mouse_input(emulator, input)
    end
  end

  defp handle_mouse_event(emulator, button, x, y, rest) do
    output =
      get_mouse_output(emulator.mode_manager.mouse_report_mode, button, x, y)

    handle_remaining_input(emulator, rest, output)
  end

  defp handle_non_mouse_input(emulator, input) do
    case Map.get(@charset_commands, input) do
      {field, value} ->
        handle_charset_command(emulator, field, value)

      nil ->
        handle_parser_input(emulator, input)
    end
  end

  defp handle_charset_command(emulator, field, value) do
    updated_charset = Map.put(emulator.charset_state, field, value)
    {%{emulator | charset_state: updated_charset}, ""}
  end

  defp handle_parser_input(emulator, input) do
    {updated_emulator, output} =
      CoreHandler.process_terminal_input(emulator, input)

    final_emulator =
      apply_cursor_check(
        needs_cursor_check?(updated_emulator),
        updated_emulator
      )

    {final_emulator, output}
  end

  @doc """
  Optimized cursor visibility check that minimizes repeated calculations.
  """
  def ensure_cursor_visible_optimized(emulator) do
    # Early return for autowrap flag
    case emulator do
      %{cursor_handled_by_autowrap: true} ->
        %{emulator | cursor_handled_by_autowrap: false}

      _ ->
        # Use lazy evaluation for expensive operations
        lazy_stream :cursor_check do
          Stream.unfold(emulator, &unfold_cursor_check/1)
          |> Enum.reduce(emulator, fn _, acc -> acc end)
        end
    end
  end

  defp unfold_cursor_check(emu) do
    handle_cursor_scroll(cursor_needs_scroll?(emu), emu)
  end

  defp needs_cursor_check?(%{last_operation: :scroll}), do: false
  defp needs_cursor_check?(%{last_operation: :cursor_move}), do: true
  defp needs_cursor_check?(_), do: true

  defp cursor_needs_scroll?(emulator) do
    # Memoize cursor position within the same operation
    cursor_y = memoize_cursor_y(emulator)
    cursor_y >= get_buffer_height(emulator)
  end

  defp memoize_cursor_y(emulator) do
    case Raxol.Core.Performance.Memoization.Server.get_memoized(
           {:get_cursor_y, [emulator]}
         ) do
      nil ->
        result =
          case emulator.cursor do
            pid when is_pid(pid) ->
              {_, y} = Raxol.Terminal.Cursor.Manager.get_position(pid)
              y

            %{row: y} ->
              y

            _ ->
              0
          end

        Raxol.Core.Performance.Memoization.Server.memoize(
          {:get_cursor_y, [emulator]},
          result
        )

        result

      cached ->
        cached
    end
  end

  defp get_buffer_height(emulator) do
    # Cache buffer height as it rarely changes
    case Raxol.Core.Performance.Memoization.Server.get_memoized(
           {:buffer_height, emulator.active_buffer}
         ) do
      nil ->
        height = ScreenBuffer.get_height(emulator.active_buffer)

        Raxol.Core.Performance.Memoization.Server.memoize(
          {:buffer_height, emulator.active_buffer},
          height
        )

        height

      height ->
        height
    end
  end

  defp scroll_once(emulator) do
    # Delegate to scroll operations
    Raxol.Terminal.Emulator.ScrollOperations.scroll_up(emulator, 1)
  end

  @doc """
  Batch process multiple input chunks for better performance.
  """
  def batch_process_inputs(emulator, inputs) when is_list(inputs) do
    batch_process(inputs, [batch_size: 10], fn batch ->
      Enum.reduce(batch, {emulator, []}, fn input, {emu, outputs} ->
        {new_emu, output} = process_input(emu, input)
        {new_emu, [output | outputs]}
      end)
    end)
    |> then(fn {final_emu, outputs} ->
      {final_emu, outputs |> Enum.reverse() |> iolist_to_binary()}
    end)
  end

  @doc """
  Precompile common escape sequences for faster matching.
  """
  def precompile_sequences do
    # Generate optimized pattern matching functions at compile time
    sequences = [
      {~r/^\e\[(\d+)A/, :cursor_up},
      {~r/^\e\[(\d+)B/, :cursor_down},
      {~r/^\e\[(\d+)C/, :cursor_forward},
      {~r/^\e\[(\d+)D/, :cursor_back},
      {~r/^\e\[(\d+);(\d+)H/, :cursor_position},
      {~r/^\e\[2J/, :clear_screen},
      {~r/^\e\[K/, :clear_line}
    ]

    :persistent_term.put(:compiled_sequences, sequences)
  end

  @doc """
  Profile input processing performance.
  """
  def profile_input_processing(emulator, sample_inputs) do
    Profiler.compare(:input_processing,
      old: fn ->
        Enum.each(sample_inputs, fn input ->
          Raxol.Terminal.Emulator.process_input(emulator, input)
        end)
      end,
      new: fn ->
        Enum.each(sample_inputs, fn input ->
          process_input(emulator, input)
        end)
      end
    )
  end

  # Helper functions for pattern matching instead of if statements
  defp get_mouse_output(:none, _button, _x, _y), do: []
  defp get_mouse_output(_mode, button, x, y), do: ["\e[M", button, x, y]

  defp handle_remaining_input(emulator, <<>>, output) do
    {emulator, iolist_to_binary(output)}
  end

  defp handle_remaining_input(emulator, rest, output) do
    {final_emulator, remaining_output} = process_input(emulator, rest)
    {final_emulator, iolist_to_binary([output | remaining_output])}
  end

  defp apply_cursor_check(true, emulator),
    do: ensure_cursor_visible_optimized(emulator)

  defp apply_cursor_check(false, emulator), do: emulator

  defp handle_cursor_scroll(true, emu), do: {emu, scroll_once(emu)}
  defp handle_cursor_scroll(false, _emu), do: nil
end
