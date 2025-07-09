defmodule Raxol.Terminal.Commands.CSIHandlers.Basic do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  require Logger

  def handle_command(emulator, params, byte) do
    case byte do
      ?m -> handle_sgr(emulator, params)
      ?H -> handle_cup(emulator, params)
      ?r -> handle_decstbm(emulator, params)
      ?J -> handle_ed(emulator, params)
      ?K -> handle_el(emulator, params)
      ?l -> handle_rm(emulator, params)
      ?h -> handle_sm(emulator, params)
      ?s -> handle_decsc(emulator, params)
      ?u -> handle_decrc(emulator, params)
      ?n -> handle_dsr(emulator, params)
      ?c -> handle_da(emulator, params)
      ?q -> handle_decscusr(emulator, params)
      ?p -> handle_decstr(emulator, params)
      ?t -> handle_decslrm(emulator, params)
      _ -> {:ok, emulator}
    end
  end

  def handle_sgr(emulator, params) do
    require Logger
    Logger.debug("handle_sgr called with params=#{inspect(params)}")

    # Convert params to string format for the SGR processor
    params_string = Enum.join(params, ";")

    # Use the correct SGR processor
    updated_style = Raxol.Terminal.ANSI.SGRProcessor.handle_sgr(params_string, emulator.style)

    Logger.debug("handle_sgr: updated_style -> #{inspect(updated_style)}")

    {:ok, %{emulator | style: updated_style}}
  end

  defp process_sgr_parameter(param) do
    case param do
      0 ->
        {:ok, %{
          bold: false, faint: false, italic: false, underline: false,
          blink: false, reverse: false, conceal: false, crossed_out: false,
          foreground: nil, background: nil
        }}

      n when n in 1..9 ->
        {:ok, %{get_attribute_key(n) => true}}

      n when n in 30..37 ->
        {:ok, %{foreground: get_color(n - 30)}}

      n when n in 40..47 ->
        {:ok, %{background: get_color(n - 40)}}

      n when n in 90..97 ->
        {:ok, %{foreground: get_bright_color(n - 90)}}

      n when n in 100..107 ->
        {:ok, %{background: get_bright_color(n - 100)}}

      _ ->
        :error
    end
  end

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
    Logger.debug("handle_decstbm called with params=#{inspect(params)}, emulator.height=#{emulator.height}")
    case params do
      [] ->
        # \e[r - Reset scroll region to full viewport
        {:ok, %{emulator | scroll_region: nil}}
      [top, bottom] when top == 1 and bottom == emulator.height ->
        # \e[r - Reset scroll region to full viewport (default params)
        {:ok, %{emulator | scroll_region: nil}}
      [top, bottom] ->
        # \e[top;bottomr - Set scroll region
        if top >= 1 and bottom <= emulator.height and top < bottom do
          {:ok, %{emulator | scroll_region: {top - 1, bottom - 1}}}
        else
          {:ok, emulator}
        end
      [top] ->
        # \e[topr - Set top of scroll region, bottom defaults to screen height
        bottom = emulator.height
        if top >= 1 and bottom <= emulator.height and top < bottom do
          {:ok, %{emulator | scroll_region: {top - 1, bottom - 1}}}
        else
          {:ok, emulator}
        end
      _ ->
        # Invalid parameters, don't change scroll region
        {:ok, emulator}
    end
  end

  def handle_ed(emulator, params) do
    mode = Enum.at(params, 0, 0)
    {x, y} = Emulator.get_cursor_position(emulator)

    case mode do
      0 ->
        {:ok, clear_from_cursor_to_end(emulator, x, y)}

      1 ->
        {:ok, clear_from_start_to_cursor(emulator, x, y)}

      2 ->
        {:ok, clear_entire_screen(emulator)}

      3 ->
        {:ok, clear_entire_screen_and_scrollback(emulator)}

      _ ->
        {:ok, emulator}
    end
  end

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

    saved_cursor = case cursor do
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

    {:ok, %{emulator | saved_cursor: saved_cursor}}
  end

  def handle_decrc(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        {:ok, emulator}

      saved ->
        # Restore cursor position and style
        {col, row} = saved.position

        emulator =
          Emulator.move_cursor_to(
            emulator,
            {row, col},
            emulator.width,
            emulator.height
          )

        # Update cursor style and visibility
        cursor = emulator.cursor
        updated_cursor = case cursor do
          %{row: _, col: _, style: _, visible: _} ->
            %{cursor |
              style: saved.style,
              visible: saved.visible
            }
          _ ->
            cursor
        end

        {:ok, %{emulator | cursor: updated_cursor}}
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

      _ ->
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
    case n do
      1 -> :bold
      2 -> :faint
      3 -> :italic
      4 -> :underline
      5 -> :blink
      7 -> :reverse
      8 -> :conceal
      9 -> :crossed_out
      _ -> :unknown
    end
  end

  defp get_color(n) do
    case n do
      0 -> :black
      1 -> :red
      2 -> :green
      3 -> :yellow
      4 -> :blue
      5 -> :magenta
      6 -> :cyan
      7 -> :white
      _ -> :default
    end
  end

  defp get_bright_color(n) do
    case n do
      0 -> :bright_black
      1 -> :bright_red
      2 -> :bright_green
      3 -> :bright_yellow
      4 -> :bright_blue
      5 -> :bright_magenta
      6 -> :bright_cyan
      7 -> :bright_white
      _ -> :default
    end
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
    buffer = Enum.reduce(0..(y-1), buffer, fn row, buf ->
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

  defp handle_private_rm(emulator, params) do
    case params do
      [1] -> {:ok, %{emulator | cursor_keys: :normal}}
      [2] -> {:ok, %{emulator | ansi_mode: false}}
      [3] -> {:ok, %{emulator | column_mode: false}}
      [4] -> {:ok, %{emulator | smooth_scroll: false}}
      [5] -> {:ok, %{emulator | reverse_video: false}}
      [6] -> {:ok, %{emulator | origin_mode: false}}
      [7] -> {:ok, %{emulator | wrap_mode: false}}
      [8] -> {:ok, %{emulator | auto_repeat: false}}
      [9] -> {:ok, %{emulator | interlacing: false}}
      [12] -> {:ok, %{emulator | cursor_blink: false}}
      [25] -> {:ok, %{emulator | cursor_visible: false}}
      [47] -> {:ok, %{emulator | alternate_screen: false}}
      _ -> {:ok, emulator}
    end
  end

  defp handle_private_sm(emulator, params) do
    case params do
      [1] -> {:ok, %{emulator | cursor_keys: :application}}
      [2] -> {:ok, %{emulator | ansi_mode: true}}
      [3] -> {:ok, %{emulator | column_mode: true}}
      [4] -> {:ok, %{emulator | smooth_scroll: true}}
      [5] -> {:ok, %{emulator | reverse_video: true}}
      [6] -> {:ok, %{emulator | origin_mode: true}}
      [7] -> {:ok, %{emulator | wrap_mode: true}}
      [8] -> {:ok, %{emulator | auto_repeat: true}}
      [9] -> {:ok, %{emulator | interlacing: true}}
      [12] -> {:ok, %{emulator | cursor_blink: true}}
      [25] -> {:ok, %{emulator | cursor_visible: true}}
      [47] -> {:ok, %{emulator | alternate_screen: true}}
      _ -> {:ok, emulator}
    end
  end
end
