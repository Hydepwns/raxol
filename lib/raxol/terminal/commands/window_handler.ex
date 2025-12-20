defmodule Raxol.Terminal.Commands.WindowHandler do
  @moduledoc """
  Handles window-related commands and operations for the terminal.
  """

  alias Raxol.Terminal.ScreenBuffer

  def default_char_width_px, do: 8

  def default_char_height_px, do: 16

  def calculate_width_chars(pixel_width) do
    div(pixel_width, default_char_width_px())
  end

  def calculate_height_chars(pixel_height) do
    div(pixel_height, default_char_height_px())
  end

  def handle_t(emulator, params) do
    op = Enum.at(params, 0, 0)
    handler = get_handler(op)
    call_handler(handler, emulator, params)
  end

  defp call_handler(handler, emulator, params) do
    case :erlang.fun_info(handler, :arity) do
      {:arity, 1} -> handler.(emulator)
      {:arity, 2} -> handler.(emulator, params)
      _ -> {:ok, emulator}
    end
  end

  defp get_handler(op) do
    Map.get(window_handlers(), op, &default_handler/2)
  end

  defp default_handler(emulator, _params), do: {:ok, emulator}

  defp window_handlers do
    %{
      0 => &handle_window_title/2,
      1 => &handle_deiconify/1,
      2 => &handle_iconify/1,
      3 => &handle_move/2,
      4 => &handle_resize/2,
      5 => &handle_raise/1,
      6 => &handle_lower/1,
      7 => &handle_refresh/1,
      8 => &handle_icon_name/2,
      9 => &handle_maximize/1,
      10 => &handle_restore/1,
      11 => &handle_report_state/1,
      13 => &handle_report_size_pixels/1,
      14 => &handle_report_position/1,
      18 => &handle_report_text_area_size/1,
      19 => &handle_report_desktop_size/1
    }
  end

  def handle_window_title(emulator, params) do
    # Get title from params or emulator.window_title or use empty string
    title = Enum.at(params, 1, emulator.window_title || "")
    output = "\x1b]0;#{title}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_icon_name(emulator, params) do
    # ESC]1;iconBEL
    icon = Enum.at(params, 1, "")
    output = "\x1b]1;#{icon}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_icon_title(emulator, params) do
    # ESC]2;titleBEL
    title = Enum.at(params, 1, "")
    output = "\x1b]2;#{title}\x07"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_deiconify(emulator) do
    updated_window_state = %{emulator.window_state | iconified: false}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  def handle_iconify(emulator) do
    updated_window_state = %{emulator.window_state | iconified: true}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  def handle_move(emulator, params) do
    y = Enum.at(params, 1, 0)
    x = Enum.at(params, 2, 0)

    # Ensure non-negative values, default to 0 for invalid input
    safe_x =
      case is_integer(x) and x >= 0 do
        true -> x
        false -> 0
      end

    safe_y =
      case is_integer(y) and y >= 0 do
        true -> y
        false -> 0
      end

    updated_window_state = %{emulator.window_state | position: {safe_x, safe_y}}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  @doc """
  Resizes the window with the given parameters.
  Parameters can be a list of integers representing width and/or height.
  """
  def resize(emulator, params) do
    case handle_resize(emulator, params) do
      {:ok, updated_emulator} -> updated_emulator
    end
  end

  def handle_resize(emulator, params) do
    {width_px, height_px} = parse_resize_params(emulator, params)

    {safe_width_px, safe_height_px} =
      validate_dimensions(emulator, width_px, height_px)

    {char_width, char_height} =
      calculate_char_dimensions(safe_width_px, safe_height_px)

    updated_emulator =
      update_emulator_size(
        emulator,
        char_width,
        char_height,
        safe_width_px,
        safe_height_px
      )

    {:ok, updated_emulator}
  end

  defp validate_dimensions(emulator, width_px, height_px) do
    safe_width =
      validate_dimension(width_px, elem(emulator.window_state.size_pixels, 0))

    safe_height =
      validate_dimension(height_px, elem(emulator.window_state.size_pixels, 1))

    {safe_width, safe_height}
  end

  defp calculate_char_dimensions(width_px, height_px) do
    {calculate_width_chars(width_px), calculate_height_chars(height_px)}
  end

  defp update_emulator_size(
         emulator,
         char_width,
         char_height,
         width_px,
         height_px
       ) do
    size = {char_width, char_height}
    size_pixels = {width_px, height_px}

    updated_window_state = %{
      emulator.window_state
      | size: size,
        size_pixels: size_pixels
    }

    updated_main_buffer =
      resize_screen_buffer(emulator.main_screen_buffer, char_width, char_height)

    %{
      emulator
      | window_state: updated_window_state,
        main_screen_buffer: updated_main_buffer,
        width: char_width,
        height: char_height
    }
  end

  defp parse_resize_params(emulator, params) do
    case params do
      [op, h, w] when is_integer(op) and op == 4 ->
        {w, h}

      [op, h] when is_integer(op) and op == 4 ->
        {default_width_px(), h}

      [op] when is_integer(op) and op == 4 ->
        {default_width_px(), default_height_px()}

      [w] when is_integer(w) ->
        {w, get_current_height(emulator)}

      [w, h] when is_integer(w) and is_integer(h) ->
        {w, h}

      _ ->
        emulator.window_state.size_pixels
    end
  end

  defp default_width_px, do: 80 * default_char_width_px()
  defp default_height_px, do: 24 * default_char_height_px()

  defp get_current_height(emulator),
    do: elem(emulator.window_state.size_pixels, 1)

  defp validate_dimension(value, fallback) do
    case is_integer(value) and value > 0 do
      true -> value
      false -> fallback
    end
  end

  defp resize_screen_buffer(buffer, width, height) do
    case {buffer, width, height} do
      {nil, _, _} ->
        ScreenBuffer.new(width, height)

      {buf, w, h} when w > 0 and h > 0 ->
        case Raxol.Core.ErrorHandling.safe_call(fn ->
               ScreenBuffer.resize(buf, w, h)
             end) do
          {:ok, resized_buffer} -> resized_buffer
          {:error, _reason} -> ScreenBuffer.new(w, h)
        end

      _ ->
        buffer
    end
  end

  def handle_raise(emulator) do
    updated_window_state = %{emulator.window_state | stacking_order: :above}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  def handle_lower(emulator) do
    updated_window_state = %{emulator.window_state | stacking_order: :below}
    updated_emulator = %{emulator | window_state: updated_window_state}
    {:ok, updated_emulator}
  end

  def handle_refresh(emulator) do
    # Refresh is a no-op
    {:ok, emulator}
  end

  def handle_maximize(emulator) do
    # Store current size before maximizing
    current_size = emulator.window_state.size
    # Default maximized size
    maximized_size = {160, 60}

    updated_window_state = %{
      emulator.window_state
      | maximized: true,
        previous_size: current_size,
        size: maximized_size,
        size_pixels:
          {elem(maximized_size, 0) * default_char_width_px(),
           elem(maximized_size, 1) * default_char_height_px()}
    }

    # Update screen buffer dimensions
    updated_main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, 160, 60)

    updated_emulator = %{
      emulator
      | window_state: updated_window_state,
        main_screen_buffer: updated_main_buffer,
        width: 160,
        height: 60
    }

    {:ok, updated_emulator}
  end

  def handle_restore(emulator) do
    # Restore to previous size, fallback to {80, 24} if missing/invalid
    previous_size =
      case emulator.window_state.previous_size do
        {w, h} when is_integer(w) and is_integer(h) and w > 0 and h > 0 ->
          {w, h}

        _ ->
          {80, 24}
      end

    char_width = elem(previous_size, 0)
    char_height = elem(previous_size, 1)

    updated_window_state = %{
      emulator.window_state
      | maximized: false,
        size: previous_size,
        size_pixels:
          {char_width * default_char_width_px(),
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

  def handle_report_state(emulator) do
    # Report window state via output buffer
    state_code =
      case emulator.window_state.iconified do
        true -> "2"
        false -> "1"
      end

    output = "\x1b[#{state_code}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_report_size_pixels(emulator) do
    # Report window size in pixels - use actual pixel size
    {width_px, height_px} = emulator.window_state.size_pixels
    output = "\x1b[4;#{height_px};#{width_px}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_report_position(emulator) do
    # Report window position
    {x, y} = emulator.window_state.position
    output = "\x1b[3;#{y};#{x}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_report_text_area_size(emulator) do
    # Report text area size in characters
    {width, height} = emulator.window_state.size
    output = "\x1b[8;#{height};#{width}t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  def handle_report_desktop_size(emulator) do
    # Report desktop size in characters (hardcoded defaults)
    output = "\x1b[9;60;160t"
    updated_emulator = %{emulator | output_buffer: output}
    {:ok, updated_emulator}
  end

  # Caching support functions
  # Originally from WindowHandler module

  alias Raxol.Core.Performance.Caches.FontMetricsCache
  alias Raxol.Terminal.Font.Manager, as: FontManager

  @default_font_size 14
  @default_line_height 1.143

  @doc """
  Gets cached font dimensions for performance.
  """
  def get_cached_char_dimensions do
    font_manager = get_default_font_manager()
    FontMetricsCache.get_font_dimensions(font_manager)
  end

  defp get_default_font_manager do
    %FontManager{
      family: "monospace",
      size: @default_font_size,
      weight: :normal,
      style: :normal,
      line_height: @default_line_height,
      letter_spacing: 0,
      fallback_fonts: [],
      custom_fonts: %{}
    }
  end

  @doc """
  Cached version of char width calculation.
  """
  def cached_char_width_px do
    {char_width, _} = get_cached_char_dimensions()
    char_width
  end

  @doc """
  Cached version of char height calculation.
  """
  def cached_char_height_px do
    {_, char_height} = get_cached_char_dimensions()
    char_height
  end
end
