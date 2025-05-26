defmodule Raxol.Terminal.Commands.WindowHandlers do
  @moduledoc """
  Handles window manipulation related CSI commands.
  These commands are used to control the terminal window's position, size, and state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  require Raxol.Core.Runtime.Log

  # Assuming average character cell dimensions for pixel reports if not otherwise available
  @default_char_width_px 8
  @default_char_height_px 16
  @default_desktop_cols 120
  @default_desktop_rows 40

  @doc """
  Handles window manipulation commands (CSI t).
  """
  @spec handle_t(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_t(emulator, params) do
    case params do
      [] ->
        Raxol.Core.Runtime.Log.warning_with_context("Window manipulation command received with empty parameters", %{})

        {:error, :empty_params, emulator}

      [nil] ->
        Raxol.Core.Runtime.Log.warning_with_context("Window manipulation command received with nil operation", %{})

        {:error, :nil_operation, emulator}

      [op | rest] when not is_integer(op) ->
        Raxol.Core.Runtime.Log.warning_with_context("Window manipulation command received with invalid operation type: #{inspect(op)}", %{})

        {:error, :invalid_operation_type, emulator}

      [op | rest] when op < 0 ->
        Raxol.Core.Runtime.Log.warning_with_context("Window manipulation command received with negative operation: #{op}", %{})

        {:error, :negative_operation, emulator}

      [op | rest] ->
        {:ok, handle_window_operation(emulator, op, rest)}
    end
  end

  # Helper function to handle window operations
  defp handle_window_operation(emulator, op, params) do
    case op do
      1 ->
        handle_deiconify(emulator)

      2 ->
        handle_iconify(emulator)

      3 ->
        handle_move_window(emulator, params)

      4 ->
        handle_resize_window_pixels(emulator, params)

      5 ->
        handle_raise(emulator)

      6 ->
        handle_lower(emulator)

      7 ->
        handle_refresh(emulator)

      9 ->
        handle_maximize(emulator)

      10 ->
        handle_restore(emulator)

      11 ->
        report_window_state(emulator)

      13 ->
        report_window_size_pixels(emulator)

      14 ->
        report_window_position(emulator)

      18 ->
        report_text_area_size(emulator)

      19 ->
        report_desktop_size_chars(emulator)

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context("Unknown window operation: #{op}", %{})
        emulator
    end
  end

  # Helper function to get window position from parameters (pixels)
  defp get_window_position_params(params) do
    case params do
      [y, x | _] when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 ->
        {x, y}

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context("Window move command received with invalid/insufficient parameters: #{inspect(params)}", %{})

        {0, 0}
    end
  end

  # Helper function to get window size from parameters (pixels)
  defp get_window_size_params_pixels(params) do
    case params do
      [height, width | _]
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 ->
        {width, height}

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context("Window resize (pixels) command received with invalid/insufficient parameters: #{inspect(params)}", %{})

        {640, 384}
    end
  end

  # Window operation handlers
  defp handle_deiconify(emulator) do
    %{
      emulator
      | window_state: Map.put(emulator.window_state, :iconified, false)
    }
  end

  defp handle_iconify(emulator) do
    %{emulator | window_state: Map.put(emulator.window_state, :iconified, true)}
  end

  defp handle_move_window(emulator, params) do
    {x, y} = get_window_position_params(params)

    %{
      emulator
      | window_state: Map.put(emulator.window_state, :position, {x, y})
    }
  end

  defp handle_resize_window_pixels(emulator, params) do
    {px_width, px_height} = get_window_size_params_pixels(params)
    # Convert pixels to character cells for buffer resizing
    # This assumes a fixed char cell size, which might not always be true
    # but is a common simplification for terminals not tightly integrated with GUI toolkit.
    char_width = div(px_width, @default_char_width_px)
    char_height = div(px_height, @default_char_height_px)

    new_ws_size_chars = {char_width, char_height}

    new_window_state =
      emulator.window_state
      # Store actual pixel size if different logic
      |> Map.put(:size_pixels, {px_width, px_height})
      # Keep :size as char dimensions for consistency with Emulator.new
      |> Map.put(:size, new_ws_size_chars)

    %{
      emulator
      | window_state: new_window_state,
        main_screen_buffer:
          ScreenBuffer.resize(
            emulator.main_screen_buffer,
            char_width,
            char_height
          ),
        alternate_screen_buffer:
          ScreenBuffer.resize(
            emulator.alternate_screen_buffer,
            char_width,
            char_height
          ),
        width: char_width,
        height: char_height
    }
  end

  defp handle_raise(emulator) do
    %{
      emulator
      | window_state: Map.put(emulator.window_state, :stacking_order, :above)
    }
  end

  defp handle_lower(emulator) do
    %{
      emulator
      | window_state: Map.put(emulator.window_state, :stacking_order, :below)
    }
  end

  defp handle_refresh(emulator) do
    emulator
  end

  defp handle_maximize(emulator) do
    # Get current char dimensions for previous_size storage
    current_char_width = ScreenBuffer.get_width(emulator.main_screen_buffer)
    current_char_height = ScreenBuffer.get_height(emulator.main_screen_buffer)
    previous_char_size = {current_char_width, current_char_height}

    # Assume maximization leads to a fixed large character grid
    max_char_width = 160
    max_char_height = 60

    new_window_state = %{
      emulator.window_state
      | maximized: true,
        # Store char dimensions
        previous_size: previous_char_size,
        # Update :size to new char dimensions
        size: {max_char_width, max_char_height}
    }

    %{
      emulator
      | window_state: new_window_state,
        main_screen_buffer:
          ScreenBuffer.resize(
            emulator.main_screen_buffer,
            max_char_width,
            max_char_height
          ),
        alternate_screen_buffer:
          ScreenBuffer.resize(
            emulator.alternate_screen_buffer,
            max_char_width,
            max_char_height
          ),
        width: max_char_width,
        height: max_char_height
    }
  end

  defp handle_restore(emulator) do
    # Previous size is stored in character dimensions
    {char_width, char_height} =
      emulator.window_state.previous_size ||
        {ScreenBuffer.get_width(emulator.main_screen_buffer),
         ScreenBuffer.get_height(emulator.main_screen_buffer)}

    new_window_state = %{
      emulator.window_state
      | maximized: false,
        # Update :size to restored char dimensions
        size: {char_width, char_height}
    }

    %{
      emulator
      | window_state: new_window_state,
        main_screen_buffer:
          ScreenBuffer.resize(
            emulator.main_screen_buffer,
            char_width,
            char_height
          ),
        alternate_screen_buffer:
          ScreenBuffer.resize(
            emulator.alternate_screen_buffer,
            char_width,
            char_height
          ),
        width: char_width,
        height: char_height
    }
  end

  # Window report handlers
  defp report_window_state(emulator) do
    state_code = if emulator.window_state.iconified, do: 2, else: 1
    output = "\e[#{state_code}t"
    %{emulator | output_buffer: emulator.output_buffer <> output}
  end

  defp report_window_position(emulator) do
    {x, y} = emulator.window_state.position
    output = "\e[3;#{y};#{x}t"
    %{emulator | output_buffer: emulator.output_buffer <> output}
  end

  defp report_window_size_pixels(emulator) do
    {char_cols, char_rows} = emulator.window_state.size
    px_width = char_cols * @default_char_width_px
    px_height = char_rows * @default_char_height_px
    output = "\e[4;#{px_height};#{px_width}t"
    %{emulator | output_buffer: emulator.output_buffer <> output}
  end

  defp report_text_area_size(emulator) do
    cols = ScreenBuffer.get_width(emulator.main_screen_buffer)
    rows = ScreenBuffer.get_height(emulator.main_screen_buffer)
    output = "\e[8;#{rows};#{cols}t"
    %{emulator | output_buffer: emulator.output_buffer <> output}
  end

  defp report_desktop_size_chars(emulator) do
    output = "\e[9;#{@default_desktop_rows};#{@default_desktop_cols}t"
    %{emulator | output_buffer: emulator.output_buffer <> output}
  end

  # Public getters for test access
  def default_char_width_px, do: @default_char_width_px
  def default_char_height_px, do: @default_char_height_px
  def default_desktop_cols, do: @default_desktop_cols
  def default_desktop_rows, do: @default_desktop_rows
end
