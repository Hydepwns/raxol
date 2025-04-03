defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Terminal emulator module that handles screen buffer operations and state management.
  
  This module provides the core functionality for terminal emulation, including:
  - Screen buffer management
  - Cursor movement
  - Text input handling
  - Scrolling functionality
  - ANSI escape code processing
  """

  defstruct [
    :width,
    :height,
    :cursor_x,
    :cursor_y,
    :screen_buffer,
    :scroll_buffer,
    :scroll_offset,
    :mode,
    :attributes
  ]

  @type t :: %__MODULE__{
    width: non_neg_integer,
    height: non_neg_integer,
    cursor_x: non_neg_integer,
    cursor_y: non_neg_integer,
    screen_buffer: list(list(String.t())),
    scroll_buffer: list(list(String.t())),
    scroll_offset: non_neg_integer,
    mode: atom,
    attributes: map
  }

  @doc """
  Creates a new terminal emulator with the specified dimensions.
  """
  def new(width, height) do
    %__MODULE__{
      width: width,
      height: height,
      cursor_x: 0,
      cursor_y: 0,
      screen_buffer: create_empty_buffer(width, height),
      scroll_buffer: [],
      scroll_offset: 0,
      mode: :normal,
      attributes: %{
        foreground: :default,
        background: :default,
        bold: false,
        underline: false,
        blink: false,
        reverse: false
      }
    }
  end

  @doc """
  Writes text to the current cursor position.
  """
  def write(emulator, text) do
    text
    |> String.graphemes()
    |> Enum.reduce(emulator, &write_char(&2, &1))
  end

  @doc """
  Moves the cursor to the specified position.
  """
  def move_cursor(emulator, x, y) do
    %{emulator | cursor_x: x, cursor_y: y}
  end

  @doc """
  Clears the screen buffer.
  """
  def clear_screen(emulator) do
    %{emulator | 
      screen_buffer: create_empty_buffer(emulator.width, emulator.height),
      cursor_x: 0,
      cursor_y: 0
    }
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  def scroll_up(emulator, lines \\ 1) do
    new_scroll_buffer = Enum.take(emulator.screen_buffer, lines) ++ emulator.scroll_buffer
    new_screen_buffer = Enum.drop(emulator.screen_buffer, lines) ++ 
                        create_empty_buffer(emulator.width, lines)
    
    %{emulator |
      screen_buffer: new_screen_buffer,
      scroll_buffer: new_scroll_buffer,
      scroll_offset: emulator.scroll_offset + lines
    }
  end

  @doc """
  Returns the current screen contents as a string.
  """
  def to_string(emulator) do
    emulator.screen_buffer
    |> Enum.map(&Enum.join/1)
    |> Enum.join("\n")
  end

  # Private functions

  defp create_empty_buffer(width, height) do
    List.duplicate(" ", width)
    |> List.duplicate(height)
  end

  defp write_char(emulator, char) do
    if emulator.cursor_x >= emulator.width do
      emulator = %{emulator | cursor_x: 0, cursor_y: emulator.cursor_y + 1}
      write_char(emulator, char)
    else
      if emulator.cursor_y >= emulator.height do
        emulator = scroll_up(emulator)
        write_char(emulator, char)
      else
        new_buffer = List.update_at(
          emulator.screen_buffer,
          emulator.cursor_y,
          &List.replace_at(&1, emulator.cursor_x, char)
        )
        
        %{emulator |
          screen_buffer: new_buffer,
          cursor_x: emulator.cursor_x + 1
        }
      end
    end
  end
end 