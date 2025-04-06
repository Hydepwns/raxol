defmodule Raxol.Terminal.EscapeSequence do
  @moduledoc """
  Handles escape sequence processing for the terminal emulator.

  This module provides functions for parsing and processing ANSI escape sequences
  for cursor movement, terminal modes, and other terminal operations.
  """

  alias Raxol.Terminal.Cursor.{Manager, Movement, Style}
  alias Raxol.Terminal.Modes

  @doc """
  Processes an escape sequence for cursor movement.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> {cursor, _} = EscapeSequence.process_cursor_movement(cursor, "10;5H")
      iex> cursor.position
      {4, 9}  # 0-based indexing
  """
  def process_cursor_movement(%Manager{} = cursor, sequence) do
    case sequence do
      # Cursor Position (H)
      <<n1::binary-size(1), ";", n2::binary-size(1), "H">> ->
        {row, _} = Integer.parse(n1)
        {col, _} = Integer.parse(n2)
        {Movement.move_to_position(cursor, col - 1, row - 1), "Moved cursor to row #{row}, column #{col}"}

      # Cursor Up (A)
      <<n::binary-size(1), "A">> ->
        {count, _} = Integer.parse(n)
        {Movement.move_up(cursor, count), "Moved cursor up #{count} lines"}

      # Cursor Down (B)
      <<n::binary-size(1), "B">> ->
        {count, _} = Integer.parse(n)
        {Movement.move_down(cursor, count), "Moved cursor down #{count} lines"}

      # Cursor Forward (C)
      <<n::binary-size(1), "C">> ->
        {count, _} = Integer.parse(n)
        {Movement.move_right(cursor, count), "Moved cursor right #{count} columns"}

      # Cursor Backward (D)
      <<n::binary-size(1), "D">> ->
        {count, _} = Integer.parse(n)
        {Movement.move_left(cursor, count), "Moved cursor left #{count} columns"}

      # Cursor Next Line (E)
      <<n::binary-size(1), "E">> ->
        {count, _} = Integer.parse(n)
        cursor = Movement.move_down(cursor, count)
        {Movement.move_to_line_start(cursor), "Moved cursor to beginning of next line #{count} times"}

      # Cursor Previous Line (F)
      <<n::binary-size(1), "F">> ->
        {count, _} = Integer.parse(n)
        cursor = Movement.move_up(cursor, count)
        {Movement.move_to_line_start(cursor), "Moved cursor to beginning of previous line #{count} times"}

      # Cursor Horizontal Absolute (G)
      <<n::binary-size(1), "G">> ->
        {col, _} = Integer.parse(n)
        # Convert from 1-based to 0-based indexing
        {Movement.move_to_column(cursor, col - 1), "Moved cursor to column #{col}"}

      # Save Cursor Position (s)
      "s" ->
        {Manager.save_position(cursor), "Saved cursor position"}

      # Restore Cursor Position (u)
      "u" ->
        {Manager.restore_position(cursor), "Restored cursor position"}

      # Unknown sequence
      _ ->
        {cursor, "Unknown cursor movement sequence: #{sequence}"}
    end
  end

  @doc """
  Processes an escape sequence for cursor style and visibility.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> {cursor, _} = EscapeSequence.process_cursor_style(cursor, "?25h")
      iex> cursor.state
      :visible
  """
  def process_cursor_style(%Manager{} = cursor, sequence) do
    case sequence do
      # Cursor Visible (h)
      "?25h" ->
        {Style.show(cursor), "Cursor visible"}

      # Cursor Hidden (l)
      "?25l" ->
        {Style.hide(cursor), "Cursor hidden"}

      # Cursor Blinking (h)
      "?12h" ->
        {Style.blink(cursor), "Cursor blinking"}

      # Cursor Steady (l)
      "?12l" ->
        {Style.show(cursor), "Cursor steady"}

      # Block Cursor (h)
      "?1h" ->
        {Style.set_block(cursor), "Block cursor"}

      # Underline Cursor (l)
      "?1l" ->
        {Style.set_underline(cursor), "Underline cursor"}

      # Bar Cursor (h)
      "?5h" ->
        {Style.set_bar(cursor), "Bar cursor"}

      # Unknown sequence
      _ ->
        {cursor, "Unknown cursor style sequence: #{sequence}"}
    end
  end

  @doc """
  Processes an escape sequence for terminal modes.

  ## Examples

      iex> modes = Modes.new()
      iex> {modes, _} = EscapeSequence.process_terminal_mode(modes, "?1049h")
      iex> Modes.active?(modes, :alternate_screen)
      true
  """
  def process_terminal_mode(%{} = modes, sequence) do
    Modes.process_escape(modes, sequence)
  end

  @doc """
  Parses an escape sequence and determines its type.

  ## Examples

      iex> EscapeSequence.parse_sequence("\e[10;5H")
      {:cursor_movement, "10;5H"}

      iex> EscapeSequence.parse_sequence("\e[?25h")
      {:cursor_style, "?25h"}

      iex> EscapeSequence.parse_sequence("\e[?1049h")
      {:terminal_mode, "?1049h"}
  """
  def parse_sequence(sequence) do
    case sequence do
      # Check for specific known CSI sequences first
      "\e[?25h" -> {:cursor_style, "?25h"}
      "\e[?25l" -> {:cursor_style, "?25l"}
      "\e[?12h" -> {:cursor_style, "?12h"}
      "\e[?12l" -> {:cursor_style, "?12l"}
      "\e[?1h" -> {:cursor_style, "?1h"}
      "\e[?1l" -> {:cursor_style, "?1l"}
      "\e[?5h" -> {:cursor_style, "?5h"}
      "\e[?1049h" -> {:terminal_mode, "?1049h"}
      "\e[?1049l" -> {:terminal_mode, "?1049l"}
      "\e[?7h" -> {:terminal_mode, "?7h"}
      "\e[?7l" -> {:terminal_mode, "?7l"}
      "\e[?8h" -> {:terminal_mode, "?8h"}
      "\e[?8l" -> {:terminal_mode, "?8l"}
      "\e[4h" -> {:terminal_mode, "4h"}
      "\e[4l" -> {:terminal_mode, "4l"}
      "\e[?1000h" -> {:terminal_mode, "?1000h"}
      "\e[?1000l" -> {:terminal_mode, "?1000l"}
      "\e[?1001h" -> {:terminal_mode, "?1001h"}
      "\e[?1001l" -> {:terminal_mode, "?1001l"}
      "\e[?1002h" -> {:terminal_mode, "?1002h"}
      "\e[?1002l" -> {:terminal_mode, "?1002l"}

      # General Cursor movement CSI sequences
      <<"\e[", rest::binary>> ->
        # Basic check to identify common cursor movement patterns
        # This is simplified; a robust parser would analyze 'rest' further
        if Regex.match?(~r/^[\d;]*[A-HJKST]/, rest) do
          {:cursor_movement, rest}
        else
          {:unknown, sequence}
        end

      # Other escape sequences (OSC, etc.) - can be added here if needed

      # Unknown sequence
      _ ->
        {:unknown, sequence}
    end
  end

  @doc """
  Processes an escape sequence and returns the updated state.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> modes = Modes.new()
      iex> {cursor, modes, _} = EscapeSequence.process_sequence(cursor, modes, "\e[10;5H")
      iex> cursor.position
      {4, 9}  # 0-based indexing
  """
  def process_sequence(%Manager{} = cursor, %{} = modes, sequence) do
    case parse_sequence(sequence) do
      {:cursor_movement, rest} ->
        {updated_cursor, message} = process_cursor_movement(cursor, rest)
        {updated_cursor, modes, message}

      {:cursor_style, rest} ->
        {updated_cursor, message} = process_cursor_style(cursor, rest)
        {updated_cursor, modes, message}

      {:terminal_mode, rest} ->
        {updated_modes, message} = process_terminal_mode(modes, rest)
        {cursor, updated_modes, message}

      {:unknown, rest} ->
        {cursor, modes, "Unknown escape sequence: #{rest}"}
    end
  end
end
