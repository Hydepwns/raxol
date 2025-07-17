defmodule Raxol.Terminal.Commands.CSIHandlers.SequenceParser do
  @moduledoc """
  Parser for CSI sequences.
  """

  @doc """
  Parses a cursor sequence and returns the handler and parameters.
  """
  def parse_cursor_sequence(sequence) when is_list(sequence) do
    cond do
      parse_position_sequence(sequence) != :error ->
        parse_position_sequence(sequence)
      parse_movement_sequence(sequence) != :error ->
        parse_movement_sequence(sequence)
      parse_screen_sequence(sequence) != :error ->
        parse_screen_sequence(sequence)
      parse_scroll_sequence(sequence) != :error ->
        parse_scroll_sequence(sequence)
      parse_attribute_sequence(sequence) != :error ->
        parse_attribute_sequence(sequence)
      parse_device_sequence(sequence) != :error ->
        parse_device_sequence(sequence)
      parse_charset_sequence(sequence) != :error ->
        parse_charset_sequence(sequence)
      parse_save_restore_sequence(sequence) != :error ->
        parse_save_restore_sequence(sequence)
      true ->
        {:error, :unknown_sequence, sequence}
    end
  end
  def parse_cursor_sequence(_), do: :error

  @doc """
  Parses position-related sequences.
  """
  def parse_position_sequence([row, ?;, col, ?H]) when is_integer(row) and is_integer(col) do
    {:ok, :cursor_position, [normalize_param(row), normalize_param(col)]}
  end
  def parse_position_sequence([row, ?H]) when is_integer(row) do
    {:ok, :cursor_position, [normalize_param(row)]}
  end
  def parse_position_sequence([?H]), do: {:ok, :cursor_position, []}
  def parse_position_sequence([col, ?G]) when is_integer(col) do
    {:ok, :cursor_column, [normalize_param(col)]}
  end
  def parse_position_sequence([?G]), do: {:ok, :cursor_column, [1]}
  def parse_position_sequence(_), do: :error

  @doc """
  Parses movement-related sequences.
  """
  def parse_movement_sequence([amount, ?A]) when is_integer(amount) do
    {:ok, :cursor_up, [normalize_param(amount)]}
  end
  def parse_movement_sequence([?A]), do: {:ok, :cursor_up, [1]}
  def parse_movement_sequence([amount, ?B]) when is_integer(amount) do
    {:ok, :cursor_down, [normalize_param(amount)]}
  end
  def parse_movement_sequence([?B]), do: {:ok, :cursor_down, [1]}
  def parse_movement_sequence([amount, ?C]) when is_integer(amount) do
    {:ok, :cursor_forward, [normalize_param(amount)]}
  end
  def parse_movement_sequence([?C]), do: {:ok, :cursor_forward, [1]}
  def parse_movement_sequence([amount, ?D]) when is_integer(amount) do
    {:ok, :cursor_backward, [normalize_param(amount)]}
  end
  def parse_movement_sequence([?D]), do: {:ok, :cursor_backward, [1]}
  def parse_movement_sequence(_), do: :error

  @doc """
  Parses screen-related sequences.
  """
  def parse_screen_sequence([mode, ?J]) when is_integer(mode) do
    {:ok, :screen_clear, [normalize_param(mode)]}
  end
  def parse_screen_sequence([?J]), do: {:ok, :screen_clear, [0]}
  def parse_screen_sequence([mode, ?K]) when is_integer(mode) do
    {:ok, :line_clear, [normalize_param(mode)]}
  end
  def parse_screen_sequence([?K]), do: {:ok, :line_clear, [0]}
  def parse_screen_sequence(_), do: :error

  @doc """
  Parses scroll-related sequences.
  """
  def parse_scroll_sequence([lines, ?S]) when is_integer(lines) do
    {:ok, :scroll_up, [normalize_param(lines)]}
  end
  def parse_scroll_sequence([?S]), do: {:ok, :scroll_up, [1]}
  def parse_scroll_sequence([lines, ?T]) when is_integer(lines) do
    {:ok, :scroll_down, [normalize_param(lines)]}
  end
  def parse_scroll_sequence([?T]), do: {:ok, :scroll_down, [1]}
  def parse_scroll_sequence(_), do: :error

  @doc """
  Parses attribute-related sequences.
  """
  def parse_attribute_sequence([amount, ?m]) when is_integer(amount) do
    {:ok, :text_attributes, [normalize_param(amount)]}
  end
  def parse_attribute_sequence([?m]), do: {:ok, :text_attributes, [0]}
  def parse_attribute_sequence(_), do: :error

  @doc """
  Parses device-related sequences.
  """
  def parse_device_sequence([amount, ?n]) when is_integer(amount) do
    {:ok, :device_status, [normalize_param(amount)]}
  end
  def parse_device_sequence([?n]), do: {:ok, :device_status, []}
  def parse_device_sequence([?6, ?n]), do: {:ok, :device_status_report, []}
  def parse_device_sequence([?6, ?R]), do: {:ok, :cursor_position_report, []}
  def parse_device_sequence(_), do: :error

  @doc """
  Parses charset-related sequences.
  """
  def parse_charset_sequence([?N]), do: {:ok, :locking_shift_g0, []}
  def parse_charset_sequence([?O]), do: {:ok, :locking_shift_g1, []}
  def parse_charset_sequence([?R]), do: {:ok, :single_shift_g2, []}
  def parse_charset_sequence(_), do: :error

  @doc """
  Parses save/restore sequences.
  """
  def parse_save_restore_sequence([?s]), do: {:ok, :save_cursor, []}
  def parse_save_restore_sequence([?u]), do: {:ok, :restore_cursor, []}
  def parse_save_restore_sequence(_), do: :error

  @doc """
  Normalizes a parameter value.
  """
  def normalize_param(param) do
    if param >= ?0 and param <= ?9, do: param - ?0, else: param
  end
end
