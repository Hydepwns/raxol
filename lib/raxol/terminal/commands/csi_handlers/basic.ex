defmodule Raxol.Terminal.Commands.CSIHandlers.Basic do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  require Logger

  # Replace the single handle_command function with multiple pattern-matched functions
  def handle_command(emulator, params, ?m), do: handle_sgr(emulator, params)
  def handle_command(emulator, params, ?H), do: handle_cup(emulator, params)
  def handle_command(emulator, params, ?r), do: handle_decstbm(emulator, params)
  def handle_command(emulator, params, ?J), do: handle_ed(emulator, params)
  def handle_command(emulator, params, ?K), do: handle_el(emulator, params)
  def handle_command(emulator, params, ?l), do: handle_rm(emulator, params)
  def handle_command(emulator, params, ?h), do: handle_sm(emulator, params)
  def handle_command(emulator, params, ?s), do: handle_decsc(emulator, params)
  def handle_command(emulator, params, ?u), do: handle_decrc(emulator, params)
  def handle_command(emulator, params, ?n), do: handle_dsr(emulator, params)
  def handle_command(emulator, params, ?c), do: handle_da(emulator, params)

  def handle_command(emulator, params, ?q),
    do: handle_decscusr(emulator, params)

  def handle_command(emulator, params, ?p), do: handle_decstr(emulator, params)
  def handle_command(emulator, params, ?t), do: handle_decslrm(emulator, params)
  def handle_command(emulator, _params, _byte), do: {:ok, emulator}

  def handle_sgr(emulator, params) do
    require Logger
    Logger.debug("handle_sgr called with params=#{inspect(params)}")

    # Convert params to string format for the SGR processor
    params_string = Enum.join(params, ";")

    # Use the correct SGR processor
    updated_style =
      Raxol.Terminal.ANSI.SGRProcessor.handle_sgr(params_string, emulator.style)

    Logger.debug("handle_sgr: updated_style -> #{inspect(updated_style)}")

    {:ok, %{emulator | style: updated_style}}
  end

  # Replace the process_sgr_parameter function with a map-based approach
  @sgr_attributes %{
    1 => :bold,
    2 => :faint,
    3 => :italic,
    4 => :underline,
    5 => :blink,
    7 => :reverse,
    8 => :conceal,
    9 => :crossed_out
  }

  @sgr_colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white
  }

  @sgr_bright_colors %{
    0 => :bright_black,
    1 => :bright_red,
    2 => :bright_green,
    3 => :bright_yellow,
    4 => :bright_blue,
    5 => :bright_magenta,
    6 => :bright_cyan,
    7 => :bright_white
  }

  defp process_sgr_parameter(0) do
    {:ok,
     %{
       bold: false,
       faint: false,
       italic: false,
       underline: false,
       blink: false,
       reverse: false,
       conceal: false,
       crossed_out: false,
       foreground: nil,
       background: nil
     }}
  end

  defp process_sgr_parameter(n) when n in 1..9 do
    case Map.get(@sgr_attributes, n) do
      nil -> :error
      attr -> {:ok, %{attr => true}}
    end
  end

  defp process_sgr_parameter(n) when n in 30..37 do
    case Map.get(@sgr_colors, n - 30) do
      nil -> :error
      color -> {:ok, %{foreground: color}}
    end
  end

  defp process_sgr_parameter(n) when n in 40..47 do
    case Map.get(@sgr_colors, n - 40) do
      nil -> :error
      color -> {:ok, %{background: color}}
    end
  end

  defp process_sgr_parameter(n) when n in 90..97 do
    case Map.get(@sgr_bright_colors, n - 90) do
      nil -> :error
      color -> {:ok, %{foreground: color}}
    end
  end

  defp process_sgr_parameter(n) when n in 100..107 do
    case Map.get(@sgr_bright_colors, n - 100) do
      nil -> :error
      color -> {:ok, %{background: color}}
    end
  end

  defp process_sgr_parameter(_), do: :error

  def handle_cup(emulator, params) do
    row = Enum.at(params, 0, 1)
    col = Enum.at(params, 1, 1)

    {:ok,
     Emulator.move_cursor_to(
       emulator,
       {row - 1, col - 1}
     )}
  end

  def handle_decstbm(emulator, params) do
    require Logger

    Logger.debug(
      "handle_decstbm called with params=#{inspect(params)}, emulator.height=#{emulator.height}"
    )

    case parse_scroll_region(params, emulator.height) do
      {:ok, region} -> {:ok, %{emulator | scroll_region: region}}
      :error -> {:ok, emulator}
    end
  end

  defp parse_scroll_region([], _height), do: {:ok, nil}

  defp parse_scroll_region([1, bottom], height) when bottom == height,
    do: {:ok, nil}

  defp parse_scroll_region([top, bottom], height)
       when top >= 1 and bottom <= height and top < bottom do
    {:ok, {top - 1, bottom - 1}}
  end

  defp parse_scroll_region([top], height) when top >= 1 and top < height do
    {:ok, {top - 1, height - 1}}
  end

  defp parse_scroll_region(_, _), do: :error

  def handle_ed(emulator, params) do
    mode = Enum.at(params, 0, 0)
    {x, y} = Emulator.get_cursor_position(emulator)
    {:ok, clear_screen_by_mode(emulator, mode, x, y)}
  end

  defp clear_screen_by_mode(emulator, 0, x, y),
    do: clear_from_cursor_to_end(emulator, x, y)

  defp clear_screen_by_mode(emulator, 1, x, y),
    do: clear_from_start_to_cursor(emulator, x, y)

  defp clear_screen_by_mode(emulator, 2, _x, _y),
    do: clear_entire_screen(emulator)

  defp clear_screen_by_mode(emulator, 3, _x, _y),
    do: clear_entire_screen_and_scrollback(emulator)

  defp clear_screen_by_mode(emulator, _mode, _x, _y), do: emulator

  def handle_el(emulator, params) do
    mode = Enum.at(params, 0, 0)
    {x, y} = Emulator.get_cursor_position(emulator)

    case mode do
      0 ->
        {:ok, clear_from_cursor_to_end_of_line(emulator, x, y)}

      1 ->
        {:ok, clear_from_start_of_line_to_cursor(emulator, x, y)}

      2 ->
        {:ok, clear_entire_line(emulator, y)}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_rm(emulator, params) do
    case params do
      [?\s | rest] -> handle_private_rm(emulator, rest)
      _ -> {:ok, emulator}
    end
  end

  def handle_sm(emulator, params) do
    case params do
      [?\s | rest] -> handle_private_sm(emulator, rest)
      _ -> {:ok, emulator}
    end
  end

  def handle_decsc(emulator, _params) do
    # Save cursor position and style
    cursor = emulator.cursor

    saved_cursor =
      case cursor do
        %{row: row, col: col, style: style, visible: visible} ->
          %{
            position: {col, row},
            style: style,
            visible: visible,
            attributes: %{}
          }

        _ ->
          # Fallback for other cursor formats
          %{
            position: {0, 0},
            style: :block,
            visible: true,
            attributes: %{}
          }
      end

    {:ok, %{emulator | saved_cursor: saved_cursor, cursor_saved: true}}
  end

  def handle_decrc(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        {:ok, emulator}

      saved ->
        # Handle both CursorManager struct and map with position field
        {col, row} =
          case saved do
            %{position: pos} when is_tuple(pos) -> pos
            %{col: c, row: r} -> {c, r}
            _ -> {0, 0}
          end

        emulator =
          Emulator.move_cursor_to(
            emulator,
            {col, row},
            emulator.width,
            emulator.height
          )

        # Update cursor style and visibility on the updated cursor
        updated_cursor =
          case emulator.cursor do
            %{row: _, col: _, style: _, visible: _} = cur ->
              %{
                cur
                | style: Map.get(saved, :style, cur.style),
                  visible: Map.get(saved, :visible, cur.visible)
              }

            _ ->
              emulator.cursor
          end

        {:ok, %{emulator | cursor: updated_cursor, cursor_restored: true}}
    end
  end

  def handle_dsr(emulator, params) do
    case params do
      [5] ->
        # Report device status - ready, no malfunctions
        output = "\e[0n"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      [6] ->
        # Report cursor position
        {x, y} = Emulator.get_cursor_position(emulator)
        output = "\e[#{y + 1};#{x + 1}R"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_da(emulator, params) do
    case params do
      [0] ->
        # Report device attributes
        output = "\e[?1;2c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      [1] ->
        # Report device attributes with more details
        output = "\e[?62;1;6;9;15;22;29c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_decscusr(emulator, params) do
    case params do
      [0] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}

      [1] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}

      [2] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :steady_block}}}

      [3] ->
        {:ok,
         %{emulator | cursor: %{emulator.cursor | style: :blink_underline}}}

      [4] ->
        {:ok,
         %{emulator | cursor: %{emulator.cursor | style: :steady_underline}}}

      [5] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_bar}}}

      [6] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :steady_bar}}}

      [param] when is_integer(param) ->
        # Invalid style code - keep current style
        {:ok, emulator}

      _ ->
        # Invalid parameter type - default to blink_block
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}
    end
  end

  def handle_decstr(emulator, _params) do
    {:ok,
     %{
       emulator
       | style: %{},
         cursor: %{emulator.cursor | style: :block},
         scroll_region: nil,
         insert_mode: false,
         newline_mode: false,
         tab_stops: MapSet.new()
     }}
  end

  def handle_decslrm(emulator, params) do
    left = Enum.at(params, 0, 1)
    right = Enum.at(params, 1, emulator.width)

    if left >= 1 and right <= emulator.width and left < right do
      {:ok, %{emulator | horizontal_margins: {left - 1, right - 1}}}
    else
      {:ok, emulator}
    end
  end

  defp get_attribute_key(n) do
    Map.get(@sgr_attributes, n, :unknown)
  end

  defp get_color(n) do
    Map.get(@sgr_colors, n, :default)
  end

  defp get_bright_color(n) do
    Map.get(@sgr_bright_colors, n, :default)
  end

  defp clear_from_cursor_to_end(emulator, x, y) do
    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.clear_region(
        buffer,
        x,
        y,
        emulator.width - 1,
        emulator.height - 1
      )

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  defp clear_from_start_to_cursor(emulator, x, y) do
    buffer = Emulator.get_active_buffer(emulator)
    # Clear all lines before the cursor's line
    buffer =
      Enum.reduce(0..(y - 1), buffer, fn row, buf ->
        Raxol.Terminal.ScreenBuffer.clear_region(buf, 0, row, emulator.width, 1)
      end)

    # Clear from start to cursor on the cursor's line
    buffer = Raxol.Terminal.ScreenBuffer.clear_region(buffer, 0, y, x + 1, 1)
    Emulator.update_active_buffer(emulator, buffer)
  end

  defp clear_entire_screen(emulator) do
    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.clear_region(
        buffer,
        0,
        0,
        emulator.width,
        emulator.height
      )

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  defp clear_entire_screen_and_scrollback(emulator) do
    emulator = clear_entire_screen(emulator)
    %{emulator | scrollback_buffer: []}
  end

  defp clear_from_cursor_to_end_of_line(emulator, x, y) do
    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.clear_region(
        buffer,
        x,
        y,
        emulator.width - 1,
        y
      )

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  defp clear_from_start_of_line_to_cursor(emulator, x, y) do
    buffer = Emulator.get_active_buffer(emulator)
    new_buffer = Raxol.Terminal.ScreenBuffer.clear_region(buffer, 0, y, x, y)
    Emulator.update_active_buffer(emulator, new_buffer)
  end

  defp clear_entire_line(emulator, y) do
    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.clear_region(
        buffer,
        0,
        y,
        emulator.width - 1,
        y
      )

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @private_rm_mappings %{
    1 => {:cursor_keys, :normal},
    2 => {:ansi_mode, false},
    3 => {:column_mode, false},
    4 => {:smooth_scroll, false},
    5 => {:reverse_video, false},
    6 => {:origin_mode, false},
    7 => {:wrap_mode, false},
    8 => {:auto_repeat, false},
    9 => {:interlacing, false},
    12 => {:cursor_blink, false},
    25 => {:cursor_visible, false},
    47 => {:alternate_screen, false}
  }

  @private_sm_mappings %{
    1 => {:cursor_keys, :application},
    2 => {:ansi_mode, true},
    3 => {:column_mode, true},
    4 => {:smooth_scroll, true},
    5 => {:reverse_video, true},
    6 => {:origin_mode, true},
    7 => {:wrap_mode, true},
    8 => {:auto_repeat, true},
    9 => {:interlacing, true},
    12 => {:cursor_blink, true},
    25 => {:cursor_visible, true},
    47 => {:alternate_screen, true}
  }

  defp handle_private_rm(emulator, params) do
    case params do
      [param] when is_integer(param) ->
        case Map.get(@private_rm_mappings, param) do
          {field, value} -> {:ok, %{emulator | field => value}}
          nil -> {:ok, emulator}
        end

      _ ->
        {:ok, emulator}
    end
  end

  defp handle_private_sm(emulator, params) do
    case params do
      [param] when is_integer(param) ->
        case Map.get(@private_sm_mappings, param) do
          {field, value} -> {:ok, %{emulator | field => value}}
          nil -> {:ok, emulator}
        end

      _ ->
        {:ok, emulator}
    end
  end
end
