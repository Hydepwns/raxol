defmodule Raxol.Terminal.Commands.CSIHandlers.Basic do
  @moduledoc false

  alias Raxol.Terminal.Emulator

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
    case params do
      [] ->
        {:ok,
         Emulator.update_style(
           emulator,
           %{}
           |> Map.put(:bold, false)
           |> Map.put(:faint, false)
           |> Map.put(:italic, false)
           |> Map.put(:underline, false)
           |> Map.put(:blink, false)
           |> Map.put(:reverse, false)
           |> Map.put(:conceal, false)
           |> Map.put(:crossed_out, false)
         )}

      [0] ->
        {:ok,
         Emulator.update_style(
           emulator,
           %{}
           |> Map.put(:bold, false)
           |> Map.put(:faint, false)
           |> Map.put(:italic, false)
           |> Map.put(:underline, false)
           |> Map.put(:blink, false)
           |> Map.put(:reverse, false)
           |> Map.put(:conceal, false)
           |> Map.put(:crossed_out, false)
         )}

      [n] when n in 1..9 ->
        current_style = emulator.style || %{}
        new_style = Map.put(current_style, get_attribute_key(n), true)
        {:ok, Emulator.update_style(emulator, new_style)}

      [n] when n in 30..37 ->
        current_style = emulator.style || %{}
        new_style = Map.put(current_style, :foreground, get_color(n - 30))
        {:ok, Emulator.update_style(emulator, new_style)}

      [n] when n in 40..47 ->
        current_style = emulator.style || %{}
        new_style = Map.put(current_style, :background, get_color(n - 40))
        {:ok, Emulator.update_style(emulator, new_style)}

      [n] when n in 90..97 ->
        current_style = emulator.style || %{}

        new_style =
          Map.put(current_style, :foreground, get_bright_color(n - 90))

        {:ok, Emulator.update_style(emulator, new_style)}

      [n] when n in 100..107 ->
        current_style = emulator.style || %{}

        new_style =
          Map.put(current_style, :background, get_bright_color(n - 100))

        {:ok, Emulator.update_style(emulator, new_style)}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_cup(emulator, params) do
    row = Enum.at(params, 0, 1)
    col = Enum.at(params, 1, 1)

    {:ok,
     Emulator.move_cursor_to(
       emulator,
       {col - 1, row - 1},
       emulator.width,
       emulator.height
     )}
  end

  def handle_decstbm(emulator, params) do
    top = Enum.at(params, 0, 1)
    bottom = Enum.at(params, 1, emulator.height)

    if top >= 1 and bottom <= emulator.height and top < bottom do
      {:ok, Emulator.update_scroll_region(emulator, {top - 1, bottom - 1})}
    else
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
    saved_cursor = %{
      position: Emulator.get_cursor_position(emulator),
      style: emulator.style,
      attributes: emulator.cursor.attributes
    }

    {:ok, %{emulator | saved_cursor: saved_cursor}}
  end

  def handle_decrc(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        {:ok, emulator}

      saved ->
        emulator =
          Emulator.move_cursor_to(
            emulator,
            saved.position,
            emulator.width,
            emulator.height
          )

        {:ok,
         %{
           emulator
           | style: saved.style,
             cursor: Map.put(emulator.cursor, :attributes, saved.attributes)
         }}
    end
  end

  def handle_dsr(emulator, params) do
    case params do
      [5] ->
        {:ok, Emulator.write_to_output(emulator, "\e[0n")}

      [6] ->
        {x, y} = Emulator.get_cursor_position(emulator)
        {:ok, Emulator.write_to_output(emulator, "\e[#{y + 1};#{x + 1}R")}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_da(emulator, params) do
    case params do
      [0] ->
        {:ok, Emulator.write_to_output(emulator, "\e[?1;2c")}

      [1] ->
        {:ok, Emulator.write_to_output(emulator, "\e[?62;1;6;9;15;22;29c")}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_decscusr(emulator, params) do
    case params do
      [0] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :block}}}
      [1] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :block}}}
      [2] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :block}}}
      [3] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :underline}}}
      [4] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :underline}}}
      [5] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :bar}}}
      [6] -> {:ok, %{emulator | cursor: %{emulator.cursor | style: :bar}}}
      _ -> {:ok, emulator}
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
    new_buffer = Raxol.Terminal.ScreenBuffer.clear_region(buffer, 0, 0, x, y)
    Emulator.update_active_buffer(emulator, new_buffer)
  end

  defp clear_entire_screen(emulator) do
    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.clear_region(
        buffer,
        0,
        0,
        emulator.width - 1,
        emulator.height - 1
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
