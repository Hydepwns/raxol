defmodule Raxol.Terminal.Commands.WindowHandlers do
  @moduledoc """
  Handles window-related commands and operations for the terminal.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  @spec default_char_width_px() :: non_neg_integer()
  def default_char_width_px, do: 8

  @spec default_char_height_px() :: non_neg_integer()
  def default_char_height_px, do: 16

  @spec calculate_width_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_width_chars(pixel_width) do
    div(pixel_width, default_char_width_px())
  end

  @spec calculate_height_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_height_chars(pixel_height) do
    div(pixel_height, default_char_height_px())
  end

  @spec handle_t(Emulator.t(), list()) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_t(emulator, params) do
    op = Enum.at(params, 0, 0)
    case op do
      0 -> handle_window_title(emulator, params)
      1 -> handle_deiconify(emulator)
      2 -> handle_iconify(emulator)
      3 -> handle_move(emulator, params)
      4 -> handle_resize(emulator, params)
      5 -> handle_raise(emulator)
      6 -> handle_lower(emulator)
      7 -> handle_refresh(emulator)
      8 -> handle_icon_name(emulator, params)
      9 -> handle_maximize(emulator)
      10 -> handle_restore(emulator)
      11 -> handle_report_state(emulator)
      13 -> handle_report_size_pixels(emulator)
      14 -> handle_report_position(emulator)
      18 -> handle_report_text_area_size(emulator)
      19 -> handle_report_desktop_size(emulator)
      _ -> {:ok, emulator}
    end
  end

  defp handle_window_title(emulator, params) do
    # Get title from params or emulator.window_title or use empty string
    title = Enum.at(params, 1, emulator.window_title || "")
    output = "\x1b]0;#{title}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_icon_name(emulator, params) do
    # ESC]1;iconBEL
    icon = Enum.at(params, 1, "")
    output = "\x1b]1;#{icon}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_icon_title(emulator, params) do
    # ESC]2;titleBEL
    title = Enum.at(params, 1, "")
    output = "\x1b]2;#{title}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_deiconify(emulator) do
    updated_window_state = %{emulator.window_state | iconified: false}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  defp handle_iconify(emulator) do
    updated_window_state = %{emulator.window_state | iconified: true}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  defp handle_move(emulator, params) do
    y = Enum.at(params, 1, 0)
    x = Enum.at(params, 2, 0)

    # Ensure non-negative values, default to 0 for invalid input
    safe_x = if is_integer(x) and x >= 0, do: x, else: 0
    safe_y = if is_integer(y) and y >= 0, do: y, else: 0

    updated_window_state = %{emulator.window_state | position: {safe_x, safe_y}}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  @doc """
  Resizes the window with the given parameters.
  Parameters can be a list of integers representing width and/or height.
  """
  @spec resize(Emulator.t(), list()) :: Emulator.t()
  def resize(emulator, params) do
    case handle_resize(emulator, params) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  defp handle_resize(emulator, params) do
    # Extract resize parameters from the parameter list
    # Parameters are [op, height_px, width_px] where op=4
    height_px = Enum.at(params, 1, nil)
    width_px = Enum.at(params, 2, nil)

    # Use proper defaults if missing, not current window state
    safe_width_px =
      cond do
        is_integer(width_px) and width_px > 0 -> width_px
        true -> 640  # Default width in pixels
      end

    safe_height_px =
      cond do
        is_integer(height_px) and height_px > 0 -> height_px
        true -> 384  # Default height in pixels
      end

    char_width = calculate_width_chars(safe_width_px)
    char_height = calculate_height_chars(safe_height_px)

    size = {char_width, char_height}
    size_pixels = {safe_width_px, safe_height_px}

    updated_window_state = %{
      emulator.window_state
      | size: size,
        size_pixels: size_pixels
    }

    # Only update screen buffer if we have valid dimensions and a valid buffer
    updated_main_buffer = case {emulator.main_screen_buffer, char_width, char_height} do
      {nil, _, _} -> ScreenBuffer.new(char_width, char_height)
      {buffer, w, h} when w > 0 and h > 0 ->
        try do
          ScreenBuffer.resize(buffer, w, h)
        rescue
          _ -> ScreenBuffer.new(w, h)
        end
      _ -> emulator.main_screen_buffer
    end

    updated_emulator = %{
      emulator
      | window_state: updated_window_state,
        main_screen_buffer: updated_main_buffer,
        width: char_width,
        height: char_height
    }

    {:ok, updated_emulator}
  end

  defp handle_raise(emulator) do
    updated_window_state = %{emulator.window_state | stacking_order: :above}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  defp handle_lower(emulator) do
    updated_window_state = %{emulator.window_state | stacking_order: :below}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  defp handle_refresh(emulator) do
    # Refresh is a no-op
    {:ok, emulator}
  end

  defp handle_maximize(emulator) do
    # Store current size before maximizing
    current_size = emulator.window_state.size
    maximized_size = {160, 60}  # Default maximized size

    updated_window_state = %{
      emulator.window_state
      | maximized: true,
        previous_size: current_size,
        size: maximized_size,
        size_pixels: {elem(maximized_size, 0) * default_char_width_px(),
                     elem(maximized_size, 1) * default_char_height_px()}
    }

    # Update screen buffer dimensions
    updated_main_buffer = ScreenBuffer.resize(emulator.main_screen_buffer, 160, 60)
    updated_emulator = %{
      emulator
      | window_state: updated_window_state,
        main_screen_buffer: updated_main_buffer,
        width: 160,
        height: 60
    }

    {:ok, updated_emulator}
  end

  defp handle_restore(emulator) do
    # Restore to previous size, fallback to {80, 24} if missing/invalid
    previous_size =
      case emulator.window_state.previous_size do
        {w, h} when is_integer(w) and is_integer(h) and w > 0 and h > 0 -> {w, h}
        _ -> {80, 24}
      end
    char_width = elem(previous_size, 0)
    char_height = elem(previous_size, 1)

    updated_window_state = %{
      emulator.window_state
      | maximized: false,
        size: previous_size,
        size_pixels: {char_width * default_char_width_px(),
                     char_height * default_char_height_px()}
    }

    # Update screen buffer dimensions, create new if nil
    updated_main_buffer =
      case emulator.main_screen_buffer do
        nil -> ScreenBuffer.new(char_width, char_height)
        buffer -> ScreenBuffer.resize(buffer, char_width, char_height)
      end

    updated_emulator = %{
      emulator
      | window_state: updated_window_state,
        main_screen_buffer: updated_main_buffer,
        width: char_width,
        height: char_height
    }

    {:ok, updated_emulator}
  end

  defp handle_report_state(emulator) do
    # Report window state via output buffer
    state_code = if emulator.window_state.iconified, do: "2", else: "1"
    output = "\x1b[#{state_code}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_report_size_pixels(emulator) do
    # Report window size in pixels - calculate from current size
    {width, height} = emulator.window_state.size
    width_px = width * default_char_width_px()
    height_px = height * default_char_height_px()
    output = "\x1b[4;#{height_px};#{width_px}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_report_position(emulator) do
    # Report window position
    {x, y} = emulator.window_state.position
    output = "\x1b[3;#{y};#{x}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_report_text_area_size(emulator) do
    # Report text area size in characters
    {width, height} = emulator.window_state.size
    output = "\x1b[8;#{height};#{width}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  defp handle_report_desktop_size(emulator) do
    # Report desktop size in characters (hardcoded defaults)
    output = "\x1b[9;60;160t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end
end
