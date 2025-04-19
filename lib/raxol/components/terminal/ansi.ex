defmodule Raxol.Components.Terminal.ANSI do
  @moduledoc """
  Handles ANSI escape code processing for the terminal component.

  This module provides:
  - ANSI escape code parsing
  - Terminal state updates based on escape codes
  - Cursor movement and styling
  - Screen clearing and manipulation
  """

  alias Raxol.Components.Terminal.Emulator

  @type cell :: Emulator.cell()
  @type screen_cells :: [[cell()]]
  @type cursor :: {integer(), integer()}
  @type dimensions :: {integer(), integer()}
  @type style :: map()

  @type ansi_state :: %{
          cursor: cursor(),
          dimensions: dimensions(),
          style: style(),
          cells: screen_cells()
        }

  @doc """
  Processes ANSI escape codes in the input string and updates the terminal state (cells, cursor, style).

  Accepts the current state (cells, cursor, style, dimensions) and the input string.
  Returns the updated state: `{updated_cells, updated_cursor, updated_style}`.

  ## Examples

      iex> ANSI.process("\\e[31mHello\\e[0m", %{cells: [], cursor: {0, 0}, style: %{}, dimensions: {80, 24}})
      %{
        cells: ["Hello"],
        cursor: {5, 0},
        style: %{color: :red},
        dimensions: {80, 24}
      }
  """
  @spec process(
          String.t(),
          screen_cells(),
          cursor(),
          style(),
          dimensions()
        ) :: {screen_cells(), cursor(), style()}
  def process(input, cells, cursor, style, dimensions) do
    initial_state = %{
      cells: cells,
      cursor: cursor,
      style: style,
      dimensions: dimensions
    }

    final_state =
      input
      |> String.to_charlist()
      |> process_charlist(initial_state)

    {final_state.cells, final_state.cursor, final_state.style}
  end

  # --- Main Processing Loop ---

  defp process_charlist([], state), do: state

  # Escape Sequence Start
  defp process_charlist([?\e | rest], state) do
    process_escape(rest, state)
  end

  # Normal Character
  defp process_charlist([char | rest], state) do
    new_state = process_char(char, state)
    process_charlist(rest, new_state)
  end

  # --- Escape Sequence Parsing ---

  defp process_escape([?[ | rest], state) do
    # Entering CSI sequence
    parse_csi(rest, state, [])
  end

  defp process_escape(other_charlist, state) do
    # Unknown escape sequence, treat first char as literal, continue processing rest
    # In a more complete implementation, we might handle other escape types (like OSC)
    IO.inspect(other_charlist, label: "Unknown Escape Sequence Start")
    # Treat as literal chars
    new_state = process_charlist(other_charlist, state)
    new_state
  end

  # --- CSI Sequence Parsing ---

  # Collect parameters (digits and ';')
  defp parse_csi([char | rest], state, params)
       when char in ?0..?9 or char == ?; do
    parse_csi(rest, state, [char | params])
  end

  # Final command character
  defp parse_csi([command | rest], state, params_rev) do
    params =
      params_rev
      |> Enum.reverse()
      |> List.to_string()
      |> String.split(";", trim: true)
      |> Enum.map(fn
        # Default parameter value if empty
        "" -> 0
        s -> String.to_integer(s)
      end)

    new_state = handle_csi(command, params, state)
    # Continue processing after the escape sequence
    process_charlist(rest, new_state)
  end

  # Malformed/incomplete CSI
  defp parse_csi([], state, _params_rev) do
    IO.inspect("Incomplete CSI sequence")
    # Ignore incomplete sequence
    state
  end

  # --- Handle CSI Commands ---
  # Map command characters to handler functions

  defp handle_csi(command, params, state) do
    case command do
      # Cursor Movement
      # CUU - Cursor Up
      ?A ->
        move_cursor_up(state, List.first(params) || 1)

      # CUD - Cursor Down
      ?B ->
        move_cursor_down(state, List.first(params) || 1)

      # CUF - Cursor Forward
      ?C ->
        move_cursor_forward(state, List.first(params) || 1)

      # CUB - Cursor Backward
      ?D ->
        move_cursor_backward(state, List.first(params) || 1)

      # CUP - Cursor Position
      ?H ->
        move_cursor_position(state, params)

      # HVP - Horizontal Vertical Position (same as CUP)
      ?f ->
        move_cursor_position(state, params)

      # Erasing Text
      # ED - Erase Display
      ?J ->
        erase_display(state, List.first(params) || 0)

      # EL - Erase Line
      ?K ->
        erase_line(state, List.first(params) || 0)

      # Select Graphic Rendition (SGR)
      ?m ->
        set_style(state, params)

      # Other common commands can be added here (e.g., scrolling)
      _ ->
        IO.inspect({command, params}, label: "Unhandled CSI Command")
        # Ignore unhandled commands
        state
    end
  end

  # --- Process Normal Character ---

  defp process_char(char, state) do
    %{cells: cells, cursor: {x, y}, style: style, dimensions: {cols, rows}} =
      state

    # Check if cursor is within bounds
    if x >= 0 and x < cols and y >= 0 and y < rows do
      # Update the cell at the cursor position
      updated_row =
        List.update_at(Enum.at(cells, y), x, fn cell ->
          %{cell | char: <<char>>, style: style, dirty: true}
        end)

      updated_cells = List.replace_at(cells, y, updated_row)

      # Move cursor forward, handle wrapping
      new_x = x + 1
      new_y = y

      if new_x >= cols do
        # Wrap to next line
        new_cursor = {0, min(rows - 1, new_y + 1)}
        %{state | cells: updated_cells, cursor: new_cursor}
      else
        new_cursor = {new_x, new_y}
        %{state | cells: updated_cells, cursor: new_cursor}
      end
    else
      # Cursor out of bounds, potentially log or ignore
      IO.inspect({x, y}, label: "Cursor out of bounds during char processing")
      state
    end
  end

  # --- CSI Command Implementations ---

  defp move_cursor_up(state, n) do
    {x, y} = state.cursor
    new_y = max(0, y - n)
    %{state | cursor: {x, new_y}}
  end

  defp move_cursor_down(state, n) do
    {x, y} = state.cursor
    {_cols, rows} = state.dimensions
    new_y = min(rows - 1, y + n)
    %{state | cursor: {x, new_y}}
  end

  defp move_cursor_forward(state, n) do
    {x, y} = state.cursor
    {cols, _rows} = state.dimensions
    new_x = min(cols - 1, x + n)
    %{state | cursor: {new_x, y}}
  end

  defp move_cursor_backward(state, n) do
    {x, y} = state.cursor
    new_x = max(0, x - n)
    %{state | cursor: {new_x, y}}
  end

  # CUP / HVP - Cursor Position
  # Parameters: [row, col] (1-based, default is {1, 1})
  defp move_cursor_position(state, params) do
    {_cols, rows} = state.dimensions
    row = Enum.at(params, 0, 1)
    col = Enum.at(params, 1, 1)
    # Convert 1-based ANSI coords to 0-based internal coords
    new_y = max(0, min(rows - 1, row - 1))
    new_x = max(0, min(state.dimensions |> elem(0) |> Kernel.-(1), col - 1))
    %{state | cursor: {new_x, new_y}}
  end

  # ED - Erase Display
  defp erase_display(state, n) do
    %{cells: cells, cursor: {cx, cy}, dimensions: {cols, rows}} = state
    default_cell = %{char: " ", style: %{}, dirty: true}

    new_cells =
      case n do
        # Clear from cursor to end of screen
        0 ->
          Enum.with_index(cells)
          |> Enum.map(&erase_display_row(&1, n, cx, cy, cols, default_cell))

        # Clear from beginning of screen to cursor
        1 ->
          Enum.with_index(cells)
          |> Enum.map(&erase_display_row(&1, n, cx, cy, cols, default_cell))

        # Clear entire screen
        2 ->
          List.duplicate(List.duplicate(default_cell, cols), rows)

        # 3 -> # Clear entire screen and delete scrollback (not implemented here)
        # Unknown parameter
        _ ->
          cells
      end

    %{state | cells: new_cells}
  end

  # Helper for erase_display
  # Erase from cursor down
  defp erase_display_row({row, y}, 0, cx, cy, cols, default_cell) do
    cond do
      y > cy ->
        List.duplicate(default_cell, cols)

      y == cy ->
        Enum.with_index(row)
        |> Enum.map(fn {cell, x} ->
          if x >= cx, do: default_cell, else: cell
        end)

      true ->
        row
    end
  end

  # Erase from cursor up
  defp erase_display_row({row, y}, 1, cx, cy, cols, default_cell) do
    cond do
      y < cy ->
        List.duplicate(default_cell, cols)

      y == cy ->
        Enum.with_index(row)
        |> Enum.map(fn {cell, x} ->
          if x <= cx, do: default_cell, else: cell
        end)

      true ->
        row
    end
  end

  # EL - Erase Line
  defp erase_line(state, n) do
    %{cells: cells, cursor: {cx, cy}, dimensions: {cols, rows}} = state
    default_cell = %{char: " ", style: %{}, dirty: true}

    if cy >= 0 and cy < rows do
      current_row = Enum.at(cells, cy)

      new_row =
        case n do
          # Clear from cursor to end of line
          0 ->
            Enum.with_index(current_row)
            |> Enum.map(fn {cell, x} ->
              if x >= cx, do: default_cell, else: cell
            end)

          # Clear from beginning of line to cursor
          1 ->
            Enum.with_index(current_row)
            |> Enum.map(fn {cell, x} ->
              if x <= cx, do: default_cell, else: cell
            end)

          # Clear entire line
          2 ->
            List.duplicate(default_cell, cols)

          # Unknown parameter
          _ ->
            current_row
        end

      %{state | cells: List.replace_at(cells, cy, new_row)}
    else
      # Cursor out of bounds
      state
    end
  end

  # SGR - Select Graphic Rendition
  defp set_style(state, params) do
    # Handle empty params (equivalent to [0])
    params = if params == [] or params == [0], do: [0], else: params
    style = Enum.reduce(params, state.style, &apply_style_param/2)
    %{state | style: style}
  end

  # --- Style Helpers ---

  defp apply_style_param(param, style) do
    case param do
      # Reset
      # Reset all attributes
      0 -> %{}
      # Text styles
      1 -> Map.put(style, :bold, true)
      # Dim
      2 -> Map.put(style, :faint, true)
      3 -> Map.put(style, :italic, true)
      4 -> Map.put(style, :underline, true)
      # Slow blink
      5 -> Map.put(style, :blink, true)
      7 -> Map.put(style, :inverse, true)
      # Conceal
      8 -> Map.put(style, :hidden, true)
      9 -> Map.put(style, :strikethrough, true)
      # Reset specific styles
      # Normal intensity
      22 -> Map.drop(style, [:bold, :faint])
      23 -> Map.delete(style, :italic)
      24 -> Map.delete(style, :underline)
      25 -> Map.delete(style, :blink)
      27 -> Map.delete(style, :inverse)
      28 -> Map.delete(style, :hidden)
      29 -> Map.delete(style, :strikethrough)
      # Foreground colors (30-37)
      n when n in 30..37 -> Map.put(style, :fg, color_for_code(n - 30))
      # Default foreground color
      39 -> Map.delete(style, :fg)
      # Background colors (40-47)
      n when n in 40..47 -> Map.put(style, :bg, color_for_code(n - 40))
      # Default background color
      49 -> Map.delete(style, :bg)
      # Bright Foreground colors (90-97)
      # Map to bright variants
      n when n in 90..97 -> Map.put(style, :fg, color_for_code(n - 90 + 8))
      # Bright Background colors (100-107)
      # Map to bright variants
      n when n in 100..107 -> Map.put(style, :bg, color_for_code(n - 100 + 8))
      # TODO: Add support for 256-color (38;5;<code>, 48;5;<code>) and RGB (38;2;<r>;<g>;<b>, 48;2;<r>;<g>;<b>)

      # Ignore unsupported SGR codes
      _ -> style
    end
  end

  # Basic 8/16 colors
  defp color_for_code(code) do
    case code do
      0 -> :black
      1 -> :red
      2 -> :green
      3 -> :yellow
      4 -> :blue
      5 -> :magenta
      6 -> :cyan
      7 -> :white
      # Bright variants
      # gray
      8 -> :bright_black
      9 -> :bright_red
      10 -> :bright_green
      11 -> :bright_yellow
      12 -> :bright_blue
      13 -> :bright_magenta
      14 -> :bright_cyan
      15 -> :bright_white
      # Or nil, depending on desired handling
      _ -> :default
    end
  end

  # --- Color Conversion Helpers (Keep existing ones for potential future use) ---

  def rgb_to_ansi256({r, g, b}) do
    # Convert RGB values to 0-5 range for ANSI 256 color cube
    r_index = trunc(r / 255.0 * 5)
    g_index = trunc(g / 255.0 * 5)
    b_index = trunc(b / 255.0 * 5)

    # Calculate color cube index (16..231)
    cube_index = 16 + 36 * r_index + 6 * g_index + b_index

    # Handle grayscale colors (232..255)
    gray_value = (r + g + b) / 3
    gray_index = trunc(gray_value / 255.0 * 23) + 232

    # Find closest color between color cube and grayscale
    cube_color = {
      r_index * 51,
      g_index * 51,
      b_index * 51
    }

    gray_rgb = {gray_value, gray_value, gray_value}

    cube_distance = color_distance({r, g, b}, cube_color)
    gray_distance = color_distance({r, g, b}, gray_rgb)

    if cube_distance <= gray_distance do
      cube_index
    else
      gray_index
    end
  end

  defp color_distance({r1, g1, b1}, {r2, g2, b2}) do
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    :math.sqrt(dr * dr + dg * dg + db * db)
  end

  def ansi256_to_rgb(code) when code in 16..231 do
    code = code - 16
    r = div(code, 36) * 51
    g = div(rem(code, 36), 6) * 51
    b = rem(code, 6) * 51
    {r, g, b}
  end

  def ansi256_to_rgb(code) when code in 232..255 do
    gray = (code - 232) * 10 + 8
    {gray, gray, gray}
  end
end
