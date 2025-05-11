defmodule Raxol.Terminal.Commands.WindowHandlers do
  @moduledoc """
  Handles window manipulation related CSI commands.
  These commands are used to control the terminal window's position, size, and state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  require Logger

  @doc """
  Handles window manipulation commands (CSI t).
  """
  def handle_t(emulator, params) do
    case params do
      [] ->
        Logger.warning("Window manipulation command received with empty parameters")
        emulator
      [nil] ->
        Logger.warning("Window manipulation command received with nil operation")
        emulator
      [op | rest] when not is_integer(op) ->
        Logger.warning("Window manipulation command received with invalid operation type: #{inspect(op)}")
        emulator
      [op | rest] when op < 0 ->
        Logger.warning("Window manipulation command received with negative operation: #{op}")
        emulator
      [op | rest] ->
        handle_window_operation(emulator, op, rest)
    end
  end

  # Helper function to handle window operations
  defp handle_window_operation(emulator, op, params) do
    case op do
      1 -> handle_deiconify(emulator)
      2 -> handle_iconify(emulator)
      3 -> handle_move(emulator, params)
      4 -> handle_resize(emulator, params)
      5 -> handle_raise(emulator)
      6 -> handle_lower(emulator)
      7 -> handle_refresh(emulator)
      9 -> handle_maximize(emulator)
      10 -> handle_restore(emulator)
      11 -> handle_state_report(emulator)
      13 -> handle_size_report(emulator)
      14 -> handle_position_report(emulator)
      18 -> handle_screen_size_report(emulator)
      19 -> handle_screen_size_pixels_report(emulator)
      _ ->
        Logger.warning("Unknown window operation: #{op}")
        emulator
    end
  end

  # Helper function to get window position from parameters
  defp get_window_position(params) do
    case params do
      [x, y | _] when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 ->
        {x, y}
      [x, y | _] when is_integer(x) and is_integer(y) ->
        Logger.warning("Window move command received with negative position: x=#{x}, y=#{y}")
        {0, 0}
      [x | _] when is_integer(x) and x >= 0 ->
        Logger.warning("Window move command received with missing y coordinate")
        {x, 0}
      [x | _] when is_integer(x) ->
        Logger.warning("Window move command received with negative x coordinate: #{x}")
        {0, 0}
      [x, y | _] ->
        Logger.warning("Window move command received with invalid parameter types: x=#{inspect(x)}, y=#{inspect(y)}")
        {0, 0}
      _ ->
        Logger.warning("Window move command received with insufficient parameters")
        {0, 0}
    end
  end

  # Helper function to get window size from parameters
  defp get_window_size(params) do
    case params do
      [width, height | _] when is_integer(width) and is_integer(height) and width > 0 and height > 0 ->
        {width, height}
      [width, height | _] when is_integer(width) and is_integer(height) ->
        Logger.warning("Window resize command received with non-positive dimensions: width=#{width}, height=#{height}")
        {80, 24}
      [width | _] when is_integer(width) and width > 0 ->
        Logger.warning("Window resize command received with missing height parameter")
        {width, 24}
      [width | _] when is_integer(width) ->
        Logger.warning("Window resize command received with non-positive width: #{width}")
        {80, 24}
      [width, height | _] ->
        Logger.warning("Window resize command received with invalid parameter types: width=#{inspect(width)}, height=#{inspect(height)}")
        {80, 24}
      _ ->
        Logger.warning("Window resize command received with insufficient parameters")
        {80, 24}
    end
  end

  # Window operation handlers
  defp handle_deiconify(emulator) do
    %{emulator | window_state: Map.put(emulator.window_state, :iconified, false)}
  end

  defp handle_iconify(emulator) do
    %{emulator | window_state: Map.put(emulator.window_state, :iconified, true)}
  end

  defp handle_move(emulator, params) do
    {x, y} = get_window_position(params)
    %{emulator | window_state: Map.put(emulator.window_state, :position, {x, y})}
  end

  defp handle_resize(emulator, params) do
    {width, height} = get_window_size(params)
    %{emulator |
      window_state: Map.put(emulator.window_state, :size, {width, height}),
      main_screen_buffer: ScreenBuffer.resize(emulator.main_screen_buffer, width, height),
      alternate_screen_buffer: ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
    }
  end

  defp handle_raise(emulator) do
    %{emulator | window_state: Map.put(emulator.window_state, :stacking_order, :above)}
  end

  defp handle_lower(emulator) do
    %{emulator | window_state: Map.put(emulator.window_state, :stacking_order, :below)}
  end

  defp handle_refresh(emulator) do
    emulator
  end

  defp handle_maximize(emulator) do
    %{emulator |
      window_state: %{emulator.window_state |
        maximized: true,
        previous_size: emulator.window_state.size,
        size: {9999, 9999}
      },
      main_screen_buffer: ScreenBuffer.resize(emulator.main_screen_buffer, 9999, 9999),
      alternate_screen_buffer: ScreenBuffer.resize(emulator.alternate_screen_buffer, 9999, 9999)
    }
  end

  defp handle_restore(emulator) do
    {width, height} = emulator.window_state.previous_size || {80, 24}
    %{emulator |
      window_state: %{emulator.window_state |
        maximized: false,
        size: {width, height}
      },
      main_screen_buffer: ScreenBuffer.resize(emulator.main_screen_buffer, width, height),
      alternate_screen_buffer: ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
    }
  end

  defp handle_state_report(emulator) do
    state = cond do
      emulator.window_state.iconified -> 2
      emulator.window_state.maximized -> 1
      true -> 0
    end
    %{emulator | output_buffer: emulator.output_buffer <> "\x1b[11t#{state}\x1b\\"}
  end

  defp handle_size_report(emulator) do
    {width, height} = emulator.window_state.size
    %{emulator | output_buffer: emulator.output_buffer <> "\x1b[13t#{height};#{width}\x1b\\"}
  end

  defp handle_position_report(emulator) do
    {x, y} = emulator.window_state.position
    %{emulator | output_buffer: emulator.output_buffer <> "\x1b[14t#{y};#{x}\x1b\\"}
  end

  defp handle_screen_size_report(emulator) do
    {width, height} = emulator.window_state.size
    %{emulator | output_buffer: emulator.output_buffer <> "\x1b[18t#{height};#{width}\x1b\\"}
  end

  defp handle_screen_size_pixels_report(emulator) do
    {width, height} = emulator.window_state.size
    %{emulator | output_buffer: emulator.output_buffer <> "\x1b[19t#{height};#{width}\x1b\\"}
  end
end
