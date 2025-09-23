defmodule Raxol.Terminal.ScreenBuffer.Attributes do
  @moduledoc """
  Consolidated attribute management for ScreenBuffer including cursor, selection, charset, and formatting.
  This module combines functionality from Cursor, Selection, Charset, and Formatting modules.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  # ========== Cursor Operations ==========

  @doc """
  Sets the cursor position in the buffer.
  """
  @spec set_cursor_position(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def set_cursor_position(buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | cursor_position: {x, y}}
  end

  def set_cursor_position(buffer, _, _), do: buffer

  @doc """
  Gets the cursor position from the buffer.
  """
  @spec get_cursor_position(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(buffer) do
    buffer.cursor_position || {0, 0}
  end

  @doc """
  Sets cursor visibility.
  """
  @spec set_cursor_visibility(ScreenBuffer.t(), boolean()) :: ScreenBuffer.t()
  def set_cursor_visibility(buffer, visible) when is_boolean(visible) do
    %{buffer | cursor_visible: visible}
  end

  def set_cursor_visibility(buffer, _), do: buffer

  @doc """
  Checks if cursor is visible.
  """
  @spec cursor_visible?(ScreenBuffer.t()) :: boolean()
  def cursor_visible?(buffer) do
    buffer.cursor_visible || false
  end

  @doc """
  Sets the cursor style.
  """
  @spec set_cursor_style(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def set_cursor_style(buffer, style) when is_atom(style) do
    Map.put(buffer, :cursor_style, style)
  end

  def set_cursor_style(buffer, _), do: buffer

  @doc """
  Gets the cursor style.
  """
  @spec get_cursor_style(ScreenBuffer.t()) :: atom()
  def get_cursor_style(buffer) do
    Map.get(buffer, :cursor_style, :block)
  end

  @doc """
  Sets cursor blink state.
  """
  @spec set_cursor_blink(ScreenBuffer.t(), boolean()) :: ScreenBuffer.t()
  def set_cursor_blink(buffer, blink) when is_boolean(blink) do
    Map.put(buffer, :cursor_blink, blink)
  end

  def set_cursor_blink(buffer, _), do: buffer

  @doc """
  Checks if cursor is blinking.
  """
  @spec cursor_blinking?(ScreenBuffer.t()) :: boolean()
  def cursor_blinking?(buffer) do
    Map.get(buffer, :cursor_blink, true)
  end

  # ========== Selection Operations ==========

  @doc """
  Starts a selection at the given position.
  """
  @spec start_selection(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def start_selection(buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | selection: {x, y, x, y}}
  end

  def start_selection(buffer, _, _), do: buffer

  @doc """
  Updates the selection end point.
  """
  @spec update_selection(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def update_selection(buffer, x, y) when x >= 0 and y >= 0 do
    case buffer.selection do
      {start_x, start_y, _, _} ->
        %{buffer | selection: {start_x, start_y, x, y}}
      nil ->
        start_selection(buffer, x, y)
      _ ->
        buffer
    end
  end

  def update_selection(buffer, _, _), do: buffer

  @doc """
  Gets the selected text from the buffer.
  """
  @spec get_selection(ScreenBuffer.t()) :: String.t()
  def get_selection(buffer) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        extract_text(buffer, start_x, start_y, end_x, end_y)
      _ ->
        ""
    end
  end

  @doc """
  Checks if a position is within the selection.
  """
  @spec in_selection?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def in_selection?(buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        # Normalize selection coordinates
        {min_x, min_y, max_x, max_y} = normalize_selection(start_x, start_y, end_x, end_y)

        cond do
          y < min_y -> false
          y > max_y -> false
          y == min_y and y == max_y -> x >= min_x and x <= max_x
          y == min_y -> x >= min_x
          y == max_y -> x <= max_x
          true -> true
        end
      _ ->
        false
    end
  end

  @doc """
  Clears the selection.
  """
  @spec clear_selection(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_selection(buffer) do
    %{buffer | selection: nil}
  end

  @doc """
  Checks if a selection is active.
  """
  @spec selection_active?(ScreenBuffer.t()) :: boolean()
  def selection_active?(buffer) do
    buffer.selection != nil
  end

  @doc """
  Gets the selection boundaries.
  """
  @spec get_selection_boundaries(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def get_selection_boundaries(buffer) do
    buffer.selection
  end

  @doc """
  Gets the selection start position.
  """
  @spec get_selection_start(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_selection_start(buffer) do
    case buffer.selection do
      {start_x, start_y, _, _} -> {start_x, start_y}
      _ -> nil
    end
  end

  @doc """
  Gets the selection end position.
  """
  @spec get_selection_end(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_selection_end(buffer) do
    case buffer.selection do
      {_, _, end_x, end_y} -> {end_x, end_y}
      _ -> nil
    end
  end

  @doc """
  Gets text in a region.
  """
  @spec get_text_in_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_text_in_region(buffer, start_x, start_y, end_x, end_y) do
    extract_text(buffer, start_x, start_y, end_x, end_y)
  end

  # ========== Charset Operations ==========

  @doc """
  Designates a character set to a G-set slot.
  """
  @spec designate_charset(ScreenBuffer.t(), atom(), atom()) :: ScreenBuffer.t()
  def designate_charset(buffer, slot, charset) when slot in [:g0, :g1, :g2, :g3] do
    slot_num = case slot do
      :g0 -> 0
      :g1 -> 1
      :g2 -> 2
      :g3 -> 3
    end
    charsets = Map.get(buffer, :charsets, %{})
    new_charsets = Map.put(charsets, slot_num, charset)
    Map.put(buffer, :charsets, new_charsets)
  end

  def designate_charset(buffer, _, _), do: buffer

  @doc """
  Gets the designated charset for a slot.
  """
  @spec get_designated_charset(ScreenBuffer.t(), atom()) :: atom()
  def get_designated_charset(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    slot_num = case slot do
      :g0 -> 0
      :g1 -> 1
      :g2 -> 2
      :g3 -> 3
    end
    Map.get(buffer, :charsets, %{})
    |> Map.get(slot_num, :ascii)
  end

  def get_designated_charset(_, _), do: :ascii

  @doc """
  Invokes a G-set.
  """
  @spec invoke_g_set(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def invoke_g_set(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    slot_num = case slot do
      :g0 -> 0
      :g1 -> 1
      :g2 -> 2
      :g3 -> 3
    end
    Map.put(buffer, :current_g_set, slot_num)
  end

  def invoke_g_set(buffer, _), do: buffer

  @doc """
  Gets the current G-set.
  """
  @spec get_current_g_set(ScreenBuffer.t()) :: atom()
  def get_current_g_set(buffer) do
    slot_num = Map.get(buffer, :current_g_set, 0)
    case slot_num do
      0 -> :g0
      1 -> :g1
      2 -> :g2
      3 -> :g3
      _ -> :g0
    end
  end

  @doc """
  Applies single shift to a G-set.
  """
  @spec apply_single_shift(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def apply_single_shift(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    slot_num = case slot do
      :g0 -> 0
      :g1 -> 1
      :g2 -> 2
      :g3 -> 3
    end
    Map.put(buffer, :single_shift, slot_num)
  end

  def apply_single_shift(buffer, _), do: buffer

  @doc """
  Gets the single shift state.
  """
  @spec get_single_shift(ScreenBuffer.t()) :: atom()
  def get_single_shift(buffer) do
    slot_num = Map.get(buffer, :single_shift)
    case slot_num do
      0 -> :g0
      1 -> :g1
      2 -> :g2
      3 -> :g3
      nil -> :g0
      _ -> :g0
    end
  end

  @doc """
  Resets charset state.
  """
  @spec reset_charset_state(ScreenBuffer.t()) :: ScreenBuffer.t()
  def reset_charset_state(buffer) do
    buffer
    |> Map.put(:charsets, %{0 => :ascii, 1 => :ascii, 2 => :ascii, 3 => :ascii})
    |> Map.put(:current_g_set, 0)
    |> Map.delete(:single_shift)
  end

  # ========== Formatting Operations ==========

  @doc """
  Gets the current style.
  """
  @spec get_style(ScreenBuffer.t()) :: TextFormatting.text_style()
  def get_style(buffer) do
    buffer.default_style || TextFormatting.new()
  end

  @doc """
  Updates the style.
  """
  @spec update_style(ScreenBuffer.t(), TextFormatting.text_style()) :: ScreenBuffer.t()
  def update_style(buffer, style) do
    %{buffer | default_style: style}
  end

  @doc """
  Sets a text attribute.
  """
  @spec set_attribute(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def set_attribute(buffer, attribute) when is_atom(attribute) do
    style = buffer.default_style || TextFormatting.new()
    new_style = Map.put(style, attribute, true)
    %{buffer | default_style: new_style}
  end

  def set_attribute(buffer, _), do: buffer

  @doc """
  Resets a text attribute.
  """
  @spec reset_attribute(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def reset_attribute(buffer, attribute) when is_atom(attribute) do
    style = buffer.default_style || TextFormatting.new()
    new_style = Map.put(style, attribute, false)
    %{buffer | default_style: new_style}
  end

  def reset_attribute(buffer, _), do: buffer

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(ScreenBuffer.t(), any()) :: ScreenBuffer.t()
  def set_foreground(buffer, color) do
    style = buffer.default_style || TextFormatting.new()
    new_style = Map.put(style, :foreground, color)
    %{buffer | default_style: new_style}
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(ScreenBuffer.t(), any()) :: ScreenBuffer.t()
  def set_background(buffer, color) do
    style = buffer.default_style || TextFormatting.new()
    new_style = Map.put(style, :background, color)
    %{buffer | default_style: new_style}
  end

  @doc """
  Resets all attributes.
  """
  @spec reset_all_attributes(ScreenBuffer.t()) :: ScreenBuffer.t()
  def reset_all_attributes(buffer) do
    %{buffer | default_style: TextFormatting.new()}
  end

  @doc """
  Gets the foreground color.
  """
  @spec get_foreground(ScreenBuffer.t()) :: any()
  def get_foreground(buffer) do
    style = buffer.default_style || TextFormatting.new()
    Map.get(style, :foreground)
  end

  @doc """
  Gets the background color.
  """
  @spec get_background(ScreenBuffer.t()) :: any()
  def get_background(buffer) do
    style = buffer.default_style || TextFormatting.new()
    Map.get(style, :background)
  end

  @doc """
  Checks if an attribute is set.
  """
  @spec attribute_set?(ScreenBuffer.t(), atom()) :: boolean()
  def attribute_set?(buffer, attribute) when is_atom(attribute) do
    style = buffer.default_style || TextFormatting.new()
    Map.get(style, attribute, false) == true
  end

  def attribute_set?(_, _), do: false

  @doc """
  Gets all set attributes.
  """
  @spec get_set_attributes(ScreenBuffer.t()) :: list(atom())
  def get_set_attributes(buffer) do
    style = buffer.default_style || TextFormatting.new()

    style
    |> Map.to_list()
    |> Enum.filter(fn {_k, v} -> v == true end)
    |> Enum.map(fn {k, _v} -> k end)
  end

  # ========== Helper Functions ==========

  defp normalize_selection(start_x, start_y, end_x, end_y) do
    if start_y > end_y or (start_y == end_y and start_x > end_x) do
      {end_x, end_y, start_x, start_y}
    else
      {start_x, start_y, end_x, end_y}
    end
  end

  defp extract_text(buffer, start_x, start_y, end_x, end_y) do
    {min_x, min_y, max_x, max_y} = normalize_selection(start_x, start_y, end_x, end_y)

    cells = buffer.cells || []

    cells
    |> Enum.with_index()
    |> Enum.filter(fn {_, y} -> y >= min_y and y <= max_y end)
    |> Enum.map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.filter(fn {_, x} ->
        cond do
          y == min_y and y == max_y -> x >= min_x and x <= max_x
          y == min_y -> x >= min_x
          y == max_y -> x <= max_x
          true -> true
        end
      end)
      |> Enum.map(fn {cell, _} -> cell.char || " " end)
      |> Enum.join()
      |> String.trim_trailing()  # Trim trailing spaces from each line
    end)
    |> Enum.join("\n")
  end
end