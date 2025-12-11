defmodule Raxol.Terminal.ScreenBuffer.Attributes do
  @moduledoc """
  Manages buffer attributes including formatting, charset, and cursor state.
  Consolidates: Formatting, TextFormatting, Charset, Cursor functionality.
  """

  alias Raxol.Terminal.ScreenBuffer.Core
  alias Raxol.Terminal.ScreenBuffer.SharedOperations
  alias Raxol.Terminal.ANSI.TextFormatting

  # Cursor operations

  @doc """
  Sets the cursor position.
  """
  @spec set_cursor_position(map(), non_neg_integer(), non_neg_integer()) ::
          map()
  def set_cursor_position(buffer, x, y) do
    x = max(0, min(x, buffer.width - 1))
    y = max(0, min(y, buffer.height - 1))
    %{buffer | cursor_position: {x, y}}
  end

  @doc """
  Gets the cursor position.
  """
  @spec get_cursor_position(map()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(buffer) do
    buffer.cursor_position
  end

  @doc """
  Moves the cursor relative to its current position.
  """
  @spec move_cursor(map(), integer(), integer()) :: map()
  def move_cursor(buffer, dx, dy) do
    {x, y} = buffer.cursor_position
    set_cursor_position(buffer, x + dx, y + dy)
  end

  @doc """
  Sets cursor visibility.
  """
  @spec set_cursor_visible(map(), boolean()) :: map()
  def set_cursor_visible(buffer, visible) do
    %{buffer | cursor_visible: visible}
  end

  @doc """
  Sets cursor style.
  """
  @spec set_cursor_style(map(), atom()) :: map()
  def set_cursor_style(buffer, style)
      when style in [:block, :underline, :bar] do
    %{buffer | cursor_style: style}
  end

  def set_cursor_style(buffer, _), do: buffer

  @doc """
  Sets cursor blink state.
  """
  @spec set_cursor_blink(map(), boolean()) :: map()
  def set_cursor_blink(buffer, blink) do
    %{buffer | cursor_blink: blink}
  end

  @doc """
  Saves the current cursor position.
  """
  @spec save_cursor(map()) :: map()
  def save_cursor(buffer) do
    Map.put(buffer, :saved_cursor_position, buffer.cursor_position)
  end

  @doc """
  Restores the saved cursor position.
  """
  @spec restore_cursor(map()) :: map()
  def restore_cursor(buffer) do
    case Map.get(buffer, :saved_cursor_position) do
      {x, y} -> set_cursor_position(buffer, x, y)
      nil -> buffer
    end
  end

  # Formatting operations

  @doc """
  Sets the default text style for the buffer.
  """
  @spec set_default_style(map(), map()) :: map()
  def set_default_style(buffer, style) do
    %{buffer | default_style: style}
  end

  @doc """
  Gets the default text style.
  """
  @spec get_default_style(map()) :: map()
  def get_default_style(buffer) do
    buffer.default_style || TextFormatting.new()
  end

  @doc """
  Creates a text style from SGR parameters.
  """
  @spec create_style(list(integer())) :: map()
  def create_style(params) do
    # Create a default style and apply SGR parameters
    initial_style = TextFormatting.new()

    Enum.reduce(params, initial_style, fn param, style ->
      TextFormatting.parse_sgr_param(param, style)
    end)
  end

  @doc """
  Merges two styles, with the second taking precedence.
  """
  @spec merge_styles(map(), map()) :: map()
  def merge_styles(base, override) do
    Map.merge(base, override)
  end

  # Charset operations

  @doc """
  Sets the active charset (G0, G1, G2, G3).
  """
  @spec set_charset(map(), atom(), atom()) :: map()
  def set_charset(buffer, slot, charset) when slot in [:g0, :g1, :g2, :g3] do
    charsets =
      Map.get(buffer, :charsets, %{
        g0: :ascii,
        g1: :ascii,
        g2: :ascii,
        g3: :ascii
      })

    new_charsets = Map.put(charsets, slot, charset)
    Map.put(buffer, :charsets, new_charsets)
  end

  def set_charset(buffer, _, _), do: buffer

  @doc """
  Gets the active charset for a slot.
  """
  @spec get_charset(map(), atom()) :: atom()
  def get_charset(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    charsets =
      Map.get(buffer, :charsets, %{
        g0: :ascii,
        g1: :ascii,
        g2: :ascii,
        g3: :ascii
      })

    Map.get(charsets, slot, :ascii)
  end

  def get_charset(_buffer, _), do: :ascii

  @doc """
  Selects which charset slot is active.
  """
  @spec select_charset(map(), atom()) :: map()
  def select_charset(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    Map.put(buffer, :active_charset, slot)
  end

  def select_charset(buffer, _), do: buffer

  @doc """
  Gets the currently active charset.
  """
  @spec get_active_charset(map()) :: atom()
  def get_active_charset(buffer) do
    slot = Map.get(buffer, :active_charset, :g0)
    get_charset(buffer, slot)
  end

  @doc """
  Translates a character according to the active charset.
  """
  @spec translate_char(map(), String.t()) :: String.t()
  def translate_char(buffer, char) do
    charset = get_active_charset(buffer)
    translate_with_charset(char, charset)
  end

  # Screen mode operations

  @doc """
  Switches between main and alternate screen buffers.
  """
  @spec set_alternate_screen(map(), boolean()) :: map()
  def set_alternate_screen(buffer, use_alternate) do
    %{buffer | alternate_screen: use_alternate}
  end

  @doc """
  Checks if using alternate screen.
  """
  @spec using_alternate_screen?(map()) :: boolean()
  def using_alternate_screen?(buffer) do
    buffer.alternate_screen
  end

  # Tab stop operations

  @doc """
  Sets a tab stop at the current cursor position.
  """
  @spec set_tab_stop(map()) :: map()
  def set_tab_stop(buffer) do
    {x, _y} = buffer.cursor_position
    tab_stops = Map.get(buffer, :tab_stops, default_tab_stops(buffer.width))
    new_tab_stops = MapSet.put(tab_stops, x)
    Map.put(buffer, :tab_stops, new_tab_stops)
  end

  @doc """
  Clears a tab stop at the current cursor position.
  """
  @spec clear_tab_stop(map()) :: map()
  def clear_tab_stop(buffer) do
    {x, _y} = buffer.cursor_position
    tab_stops = Map.get(buffer, :tab_stops, default_tab_stops(buffer.width))
    new_tab_stops = MapSet.delete(tab_stops, x)
    Map.put(buffer, :tab_stops, new_tab_stops)
  end

  @doc """
  Clears all tab stops.
  """
  @spec clear_all_tab_stops(map()) :: map()
  def clear_all_tab_stops(buffer) do
    Map.put(buffer, :tab_stops, MapSet.new())
  end

  @doc """
  Resets tab stops to default (every 8 columns).
  """
  @spec reset_tab_stops(map()) :: map()
  def reset_tab_stops(buffer) do
    Map.put(buffer, :tab_stops, default_tab_stops(buffer.width))
  end

  @doc """
  Finds the next tab stop position from the current cursor.
  """
  @spec next_tab_stop(map()) :: non_neg_integer()
  def next_tab_stop(buffer) do
    {x, _y} = buffer.cursor_position
    tab_stops = Map.get(buffer, :tab_stops, default_tab_stops(buffer.width))

    # Find next tab stop after current position
    tab_stops
    |> Enum.filter(fn stop -> stop > x end)
    |> Enum.min(fn -> buffer.width - 1 end)
  end

  # Private helper functions

  defp translate_with_charset(char, :ascii), do: char

  defp translate_with_charset(char, :dec_special) do
    # DEC Special Graphics character set mapping
    case char do
      "`" -> "◆"
      "a" -> "▒"
      "b" -> "␉"
      "c" -> "␌"
      "d" -> "␍"
      "e" -> "␊"
      "f" -> "°"
      "g" -> "±"
      "h" -> "␤"
      "i" -> "␋"
      "j" -> "┘"
      "k" -> "┐"
      "l" -> "┌"
      "m" -> "└"
      "n" -> "┼"
      "o" -> "⎺"
      "p" -> "⎻"
      "q" -> "─"
      "r" -> "⎼"
      "s" -> "⎽"
      "t" -> "├"
      "u" -> "┤"
      "v" -> "┴"
      "w" -> "┬"
      "x" -> "│"
      "y" -> "≤"
      "z" -> "≥"
      "{" -> "π"
      "|" -> "≠"
      "}" -> "£"
      "~" -> "·"
      _ -> char
    end
  end

  defp translate_with_charset(char, _), do: char

  defp default_tab_stops(width) do
    # Default tab stops every 8 columns
    0..(width - 1)
    |> Enum.filter(fn x -> rem(x, 8) == 0 end)
    |> MapSet.new()
  end

  # === Stub Implementations for Test Compatibility ===
  # These functions are referenced by delegations but not critical for core functionality

  @doc """
  Checks if cursor is visible (stub).
  """
  @spec cursor_visible?(map()) :: boolean()
  def cursor_visible?(buffer), do: buffer.cursor_visible

  @doc """
  Checks if cursor is blinking (stub).
  """
  @spec cursor_blinking?(map()) :: boolean()
  def cursor_blinking?(buffer), do: Map.get(buffer, :cursor_blink, true)

  @doc """
  Gets cursor style (stub).
  """
  @spec get_cursor_style(map()) :: atom()
  def get_cursor_style(buffer), do: buffer.cursor_style

  @doc """
  Gets text style (stub).
  """
  @spec get_style(map()) :: TextFormatting.text_style()
  def get_style(buffer), do: buffer.default_style

  @doc """
  Updates text style (stub).
  """
  @spec update_style(map(), TextFormatting.text_style()) :: map()
  def update_style(buffer, style), do: %{buffer | default_style: style}

  @doc """
  Gets foreground color (stub).
  """
  @spec get_foreground(map()) :: atom() | tuple()
  def get_foreground(buffer), do: buffer.default_style.foreground

  @doc """
  Gets background color (stub).
  """
  @spec get_background(map()) :: atom() | tuple()
  def get_background(buffer), do: buffer.default_style.background

  @doc """
  Starts selection (stub).
  """
  @spec start_selection(map(), non_neg_integer(), non_neg_integer()) ::
          map()
  def start_selection(buffer, x, y), do: %{buffer | selection: {x, y, nil, nil}}

  @doc """
  Updates selection (stub).
  """
  @spec update_selection(map(), non_neg_integer(), non_neg_integer()) ::
          map()
  def update_selection(buffer, x, y) do
    case buffer.selection do
      {sx, sy, _, _} -> %{buffer | selection: {sx, sy, x, y}}
      nil -> buffer
    end
  end

  @doc """
  Clears selection (stub).
  """
  @spec clear_selection(map()) :: map()
  def clear_selection(buffer), do: %{buffer | selection: nil}

  @doc """
  Gets selection (stub).
  """
  @spec get_selection(map()) ::
          {integer(), integer(), integer(), integer()} | nil
  def get_selection(buffer), do: buffer.selection

  @doc """
  Gets selection start (stub).
  """
  @spec get_selection_start(map()) :: {integer(), integer()} | nil
  def get_selection_start(buffer) do
    case buffer.selection do
      {sx, sy, _, _} -> {sx, sy}
      nil -> nil
    end
  end

  @doc """
  Gets selection end (stub).
  """
  @spec get_selection_end(map()) :: {integer(), integer()} | nil
  def get_selection_end(buffer) do
    case buffer.selection do
      {_, _, nil, nil} -> nil
      {_, _, ex, ey} -> {ex, ey}
      nil -> nil
    end
  end

  @doc """
  Gets selection boundaries (stub).
  """
  @spec get_selection_boundaries(map()) ::
          {integer(), integer(), integer(), integer()} | nil
  def get_selection_boundaries(buffer), do: buffer.selection

  @doc """
  Checks if position is in selection (stub).
  """
  @spec in_selection?(map(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def in_selection?(buffer, x, y) do
    case buffer.selection do
      {sx, sy, ex, ey} when ex != nil and ey != nil ->
        {start_x, start_y, end_x, end_y} =
          SharedOperations.normalize_selection(sx, sy, ex, ey)

        SharedOperations.position_in_selection?(
          x,
          y,
          start_x,
          start_y,
          end_x,
          end_y
        )

      _ ->
        false
    end
  end

  @doc """
  Gets text in region.
  """
  @spec get_text_in_region(map(), integer(), integer(), integer(), integer()) ::
          String.t()
  def get_text_in_region(buffer, x1, y1, x2, y2) do
    # Extract text from the specified region
    case buffer.cells do
      nil ->
        ""

      cells when is_list(cells) ->
        # Ensure coordinates are within bounds and properly ordered
        start_y = max(0, min(y1, y2))
        end_y = min(length(cells) - 1, max(y1, y2))

        if start_y > end_y do
          ""
        else
          cells
          |> Enum.slice(start_y..end_y)
          |> Enum.map(fn line when is_list(line) ->
            start_x = max(0, min(x1, x2))
            end_x = min(length(line) - 1, max(x1, x2))

            if start_x > end_x do
              ""
            else
              line
              |> Enum.slice(start_x..end_x)
              |> Enum.map_join("", fn
                %{char: char} -> char
                _ -> " "
              end)
              |> String.trim_trailing()
            end
          end)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("\n")
        end

      _ ->
        ""
    end
  end

  @doc """
  Checks if attribute is set (stub).
  """
  @spec attribute_set?(map(), atom()) :: boolean()
  def attribute_set?(_buffer, _attr), do: false

  @doc """
  Gets set attributes (stub).
  """
  @spec get_set_attributes(map()) :: list(atom())
  def get_set_attributes(_buffer), do: []

  @doc """
  Applies single shift (stub).
  """
  @spec apply_single_shift(map(), integer()) :: map()
  def apply_single_shift(buffer, _set), do: buffer

  @doc """
  Gets single shift state (stub).
  """
  @spec get_single_shift(map()) :: integer() | nil
  def get_single_shift(_buffer), do: nil

  @doc """
  Gets current G set (stub).
  """
  @spec get_current_g_set(map()) :: integer()
  def get_current_g_set(_buffer), do: 0

  @doc """
  Designates charset (stub).
  """
  @spec designate_charset(map(), integer(), atom()) :: map()
  def designate_charset(buffer, _set, _charset), do: buffer

  @doc """
  Gets designated charset (stub).
  """
  @spec get_designated_charset(map(), integer()) :: atom()
  def get_designated_charset(_buffer, _set), do: :us

  @doc """
  Invokes G set (stub).
  """
  @spec invoke_g_set(map(), integer()) :: map()
  def invoke_g_set(buffer, _set), do: buffer

  @doc """
  Resets all attributes to defaults (stub).
  """
  @spec reset_all_attributes(map()) :: map()
  def reset_all_attributes(buffer) do
    %{buffer | default_style: TextFormatting.default_style()}
  end

  @doc """
  Resets specific attribute (stub).
  """
  @spec reset_attribute(map(), atom()) :: map()
  def reset_attribute(buffer, _attr), do: buffer

  @doc """
  Resets charset state (stub).
  """
  @spec reset_charset_state(map()) :: map()
  def reset_charset_state(buffer), do: buffer

  @doc """
  Checks if selection is active (stub).
  """
  @spec selection_active?(map()) :: boolean()
  def selection_active?(buffer), do: buffer.selection != nil

  @doc """
  Sets specific attribute (stub).
  """
  @spec set_attribute(map(), atom()) :: map()
  def set_attribute(buffer, _attr), do: buffer

  @doc """
  Sets background color (stub).
  """
  @spec set_background(map(), atom() | tuple()) :: map()
  def set_background(buffer, color) do
    style = Map.put(buffer.default_style, :background, color)
    %{buffer | default_style: style}
  end

  @doc """
  Sets cursor visibility (stub).
  """
  @spec set_cursor_visibility(map(), boolean()) :: map()
  def set_cursor_visibility(buffer, visible) do
    %{buffer | cursor_visible: visible}
  end

  @doc """
  Sets foreground color (stub).
  """
  @spec set_foreground(map(), atom() | tuple()) :: map()
  def set_foreground(buffer, color) do
    style = Map.put(buffer.default_style, :foreground, color)
    %{buffer | default_style: style}
  end
end
