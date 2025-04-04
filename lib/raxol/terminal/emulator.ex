defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Terminal emulator module that handles screen buffer operations and state management.
  
  This module provides the core functionality for terminal emulation, including:
  - Screen buffer management
  - Cursor movement and positioning
  - Text input handling
  - Scrolling functionality
  - ANSI escape code processing
  - Virtual scrolling for performance
  - Memory management
  - Line editing
  - Scrolling region
  - Cursor state
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
    :attributes,
    :virtual_scroll_size,
    :memory_limit,
    :last_cleanup,
    :cursor_visible,
    :cursor_saved,
    :scroll_region_top,
    :scroll_region_bottom
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
    attributes: map,
    virtual_scroll_size: non_neg_integer,
    memory_limit: non_neg_integer,
    last_cleanup: integer(),
    cursor_visible: boolean(),
    cursor_saved: {integer(), integer()} | nil,
    scroll_region_top: integer() | nil,
    scroll_region_bottom: integer() | nil
  }

  @default_memory_limit 50 * 1024 * 1024  # 50MB
  @default_virtual_scroll_size 1000
  @cleanup_interval 60 * 1000  # 1 minute

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
        foreground_256: nil,
        background_256: nil,
        foreground_true: nil,
        background_true: nil,
        bold: false,
        underline: false,
        blink: false,
        reverse: false
      },
      virtual_scroll_size: @default_virtual_scroll_size,
      memory_limit: @default_memory_limit,
      last_cleanup: System.system_time(:millisecond),
      cursor_visible: true,
      cursor_saved: nil,
      scroll_region_top: nil,
      scroll_region_bottom: nil
    }
  end

  @doc """
  Writes text to the current cursor position with memory management.
  """
  def write(emulator, text) do
    emulator = check_memory_usage(emulator)
    
    text
    |> String.graphemes()
    |> Enum.reduce(emulator, &write_char(&2, &1))
  end

  @doc """
  Moves the cursor to the specified position.
  """
  def move_cursor(emulator, x, y) do
    # Ensure cursor stays within bounds
    x = max(0, min(x, emulator.width - 1))
    y = max(0, min(y, emulator.height - 1))
    
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

  @doc """
  Gets the visible portion of the terminal content using virtual scrolling.
  """
  def get_visible_content(emulator) do
    start_idx = max(0, emulator.scroll_offset)
    end_idx = min(
      length(emulator.scroll_buffer),
      start_idx + emulator.virtual_scroll_size
    )
    
    emulator.scroll_buffer
    |> Enum.slice(start_idx, end_idx - start_idx)
    |> Enum.map(&Enum.join(&1))
    |> Enum.join("\n")
  end

  @doc """
  Scrolls the terminal content by the specified number of lines.
  """
  def scroll(emulator, lines) do
    new_offset = max(0, emulator.scroll_offset + lines)
    %{emulator | scroll_offset: new_offset}
  end

  @doc """
  Inserts the specified number of lines at the current cursor position.
  """
  def insert_line(emulator, n \\ 1) do
    {top, bottom} = get_scroll_region(emulator)
    
    # Create empty lines
    empty_lines = Enum.map(1..n, fn _ -> 
      List.duplicate(" ", emulator.width)
    end)
    
    # Insert lines at cursor position
    new_buffer = List.replace_at(
      emulator.screen_buffer,
      emulator.cursor_y,
      empty_lines ++ Enum.at(emulator.screen_buffer, emulator.cursor_y)
    )
    
    # Remove lines from bottom if needed
    new_buffer = if length(new_buffer) > emulator.height do
      Enum.take(new_buffer, emulator.height)
    else
      new_buffer
    end
    
    %{emulator | screen_buffer: new_buffer}
  end

  @doc """
  Deletes the specified number of lines at the current cursor position.
  """
  def delete_line(emulator, n \\ 1) do
    {top, bottom} = get_scroll_region(emulator)
    
    # Remove lines at cursor position
    new_buffer = List.replace_at(
      emulator.screen_buffer,
      emulator.cursor_y,
      Enum.drop(Enum.at(emulator.screen_buffer, emulator.cursor_y), n)
    )
    
    # Add empty lines at bottom
    new_buffer = new_buffer ++ create_empty_buffer(emulator.width, n)
    
    %{emulator | screen_buffer: new_buffer}
  end

  @doc """
  Sets the scrolling region.
  """
  def set_scroll_region(emulator, top, bottom) do
    %{emulator |
      scroll_region_top: max(0, min(top, emulator.height - 1)),
      scroll_region_bottom: max(0, min(bottom, emulator.height - 1))
    }
  end

  @doc """
  Saves the current cursor position.
  """
  def save_cursor(emulator) do
    %{emulator | cursor_saved: {emulator.cursor_x, emulator.cursor_y}}
  end

  @doc """
  Restores the previously saved cursor position.
  """
  def restore_cursor(emulator) do
    case emulator.cursor_saved do
      {x, y} -> move_cursor(emulator, x, y)
      nil -> emulator
    end
  end

  @doc """
  Shows the cursor.
  """
  def show_cursor(emulator) do
    %{emulator | cursor_visible: true}
  end

  @doc """
  Hides the cursor.
  """
  def hide_cursor(emulator) do
    %{emulator | cursor_visible: false}
  end

  @doc """
  Erases the current line according to the specified mode.
  """
  def erase_line(emulator, mode) do
    current_line = Enum.at(emulator.screen_buffer, emulator.cursor_y)
    
    new_line = case mode do
      0 -> # Clear from cursor to end
        List.replace_at(
          current_line,
          emulator.cursor_x,
          String.duplicate(" ", length(current_line) - emulator.cursor_x)
        )
      
      1 -> # Clear from beginning to cursor
        List.replace_at(
          current_line,
          0,
          String.duplicate(" ", emulator.cursor_x)
        )
      
      2 -> # Clear entire line
        List.duplicate(" ", length(current_line))
      
      _ -> current_line
    end
    
    new_buffer = List.replace_at(
      emulator.screen_buffer,
      emulator.cursor_y,
      new_line
    )
    
    %{emulator | screen_buffer: new_buffer}
  end

  # Private functions

  defp write_char(emulator, char) do
    {new_buffer, new_cursor_x, new_cursor_y} = 
      write_char_to_buffer(emulator.screen_buffer, char, emulator.cursor_x, emulator.cursor_y)
    
    # Update scroll buffer if needed
    scroll_buffer = update_scroll_buffer(emulator.scroll_buffer, new_buffer)
    
    %{emulator |
      screen_buffer: new_buffer,
      cursor_x: new_cursor_x,
      cursor_y: new_cursor_y,
      scroll_buffer: scroll_buffer
    }
  end

  defp write_char_to_buffer(buffer, char, x, y) do
    # Handle line wrapping
    if x >= length(hd(buffer)) do
      write_char_to_buffer(buffer, char, 0, y + 1)
    else
      # Write character at current position
      new_row = List.update_at(Enum.at(buffer, y), x, fn _ -> char end)
      new_buffer = List.update_at(buffer, y, fn _ -> new_row end)
      
      {new_buffer, x + 1, y}
    end
  end

  defp update_scroll_buffer(scroll_buffer, screen_buffer) do
    # Add new lines to scroll buffer
    new_lines = screen_buffer
    |> Enum.map(&Enum.join(&1))
    |> Enum.reject(&(&1 == String.duplicate(" ", length(&1))))
    
    scroll_buffer ++ new_lines
  end

  defp check_memory_usage(emulator) do
    current_time = System.system_time(:millisecond)
    
    # Check if cleanup is needed
    if current_time - emulator.last_cleanup > @cleanup_interval do
      cleanup_memory(emulator)
    else
      emulator
    end
  end

  defp cleanup_memory(emulator) do
    # Calculate memory usage
    memory_usage = :erlang.memory(:total)
    
    if memory_usage > emulator.memory_limit do
      # Remove old lines from scroll buffer
      new_scroll_buffer = emulator.scroll_buffer
      |> Enum.take(-emulator.virtual_scroll_size)
      
      %{emulator |
        scroll_buffer: new_scroll_buffer,
        last_cleanup: System.system_time(:millisecond)
      }
    else
      emulator
    end
  end

  defp create_empty_buffer(width, height) do
    empty_line = List.duplicate(" ", width)
    List.duplicate(empty_line, height)
  end

  defp get_scroll_region(emulator) do
    top = emulator.scroll_region_top || 0
    bottom = emulator.scroll_region_bottom || (emulator.height - 1)
    {top, bottom}
  end
end 