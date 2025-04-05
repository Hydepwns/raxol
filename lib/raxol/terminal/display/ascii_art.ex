defmodule Raxol.Terminal.Display.AsciiArt do
  @moduledoc """
  ASCII art rendering system for the Raxol terminal emulator.
  
  This module provides functionality for:
  - Rendering ASCII art templates
  - Creating custom ASCII art
  - Animating ASCII art
  - Integrating with the terminal display system
  """

  @doc """
  Returns the ASCII art logo for the Raxol project.
  """
  def logo do
    """
       ██████╗  █████╗ ██╗  ██╗ ██████╗ ██╗     
       ██╔══██╗██╔══██╗██║ ██╔╝██╔═══██╗██║     
       ██████╔╝███████║█████╔╝ ██║   ██║██║     
       ██╔══██╗██╔══██║██╔═██╗ ██║   ██║██║     
       ██║  ██║██║  ██║██║  ██╗╚██████╔╝███████╗
       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    =====================================================
    """
  end

  @doc """
  Returns an ASCII art success indicator.
  """
  def success do
    """
     ╭───────────────────────────────╮
     │  ✓  Operation successful!     │
     ╰───────────────────────────────╯
    """
  end

  @doc """
  Returns an ASCII art error indicator.
  """
  def error do
    """
     ╭───────────────────────────────╮
     │  ✗  Operation failed!         │
     ╰───────────────────────────────╯
    """
  end

  @doc """
  Returns an ASCII art warning indicator.
  """
  def warning do
    """
     ╭───────────────────────────────╮
     │  ⚠  Warning!                  │
     ╰───────────────────────────────╯
    """
  end

  @doc """
  Returns a stylized header with the given text.
  """
  def header(text) do
    padding = div(80 - String.length(text), 2)
    left_padding = String.duplicate("═", padding)
    right_padding = String.duplicate("═", 80 - padding - String.length(text))

    """
    ╔════════════════════════════════════════════════════════════════════════════════╗
    ║#{left_padding}#{text}#{right_padding}║
    ╚════════════════════════════════════════════════════════════════════════════════╝
    """
  end

  @doc """
  Returns an ASCII art help screen.
  """
  def help do
    """
     ╭───────────────────────────────────────────────────────────────────╮
     │                   TERMINAL COMMAND REFERENCE                       │
     ├───────────────────────────────────────────────────────────────────┤
     │  help       - Display this help screen                            │
     │  clear      - Clear the terminal screen                           │
     │  echo       - Display a line of text                              │
     │  date       - Display the current date and time                   │
     │  theme      - Change the terminal theme                           │
     │  history    - Show command history                                │
     │  info       - Display system information                          │
     │  preferences - Customize terminal appearance                      │
     ╰───────────────────────────────────────────────────────────────────╯
    """
  end

  @doc """
  Returns an ASCII art theme preview.
  """
  def theme_preview do
    """
     ╭───────────────────────────────────────────────────────────────────╮
     │                   AVAILABLE THEME OPTIONS                          │
     ├───────────────────────────────────────────────────────────────────┤
     │  light      - Light background with dark text                     │
     │  dark       - Dark background with light text                     │
     │  dim        - Dark background with softer text colors             │
     │  high-contrast - High contrast colors for accessibility           │
     ╰───────────────────────────────────────────────────────────────────╯
    """
  end

  @doc """
  Returns an ASCII art progress bar with the given percentage.
  """
  def progress_bar(percentage) when is_integer(percentage) and percentage >= 0 and percentage <= 100 do
    width = 50
    filled = div(width * percentage, 100)
    empty = width - filled
    
    filled_bar = String.duplicate("█", filled)
    empty_bar = String.duplicate("░", empty)
    
    """
    ╭──────────────────────────────────────────────────╮
    │  [#{String.pad_leading(filled_bar <> empty_bar, width)}] #{String.pad_leading(Integer.to_string(percentage), 3)}% │
    ╰──────────────────────────────────────────────────╯
    """
  end

  @doc """
  Returns an ASCII art box with the given text.
  """
  def box(text) do
    lines = String.split(text, "\n")
    max_length = Enum.max(Enum.map(lines, &String.length/1))
    
    top_bottom = "╭" <> String.duplicate("─", max_length + 2) <> "╮"
    middle = Enum.map(lines, fn line ->
      padding = String.duplicate(" ", max_length - String.length(line))
      "│ #{line}#{padding} │"
    end)
    bottom = "╰" <> String.duplicate("─", max_length + 2) <> "╯"
    
    [top_bottom] ++ middle ++ [bottom]
    |> Enum.join("\n")
  end

  @doc """
  Returns an ASCII art table with the given headers and rows.
  """
  def table(headers, rows) do
    # Calculate column widths
    all_rows = [headers | rows]
    col_widths = headers
    |> Enum.with_index()
    |> Enum.map(fn {_, i} ->
      all_rows
      |> Enum.map(fn row -> String.length(Enum.at(row, i)) end)
      |> Enum.max()
    end)
    
    # Create header row
    header_row = headers
    |> Enum.with_index()
    |> Enum.map(fn {header, i} ->
      String.pad_trailing(header, col_widths[i])
    end)
    |> Enum.join(" │ ")
    
    # Create separator
    separator = col_widths
    |> Enum.map(fn width -> String.duplicate("─", width) end)
    |> Enum.join("─┼─")
    
    # Create data rows
    data_rows = rows
    |> Enum.map(fn row ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {cell, i} ->
        String.pad_trailing(cell, col_widths[i])
      end)
      |> Enum.join(" │ ")
    end)
    
    # Combine all parts
    [header_row, separator] ++ data_rows
    |> Enum.join("\n")
  end

  @doc """
  Returns an ASCII art spinner animation frame for the given step.
  """
  def spinner(step) when is_integer(step) do
    frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    frame = Enum.at(frames, rem(step, length(frames)))
    "#{frame} Processing..."
  end

  @doc """
  Returns an ASCII art loading animation for the given text.
  """
  def loading(text, step) when is_integer(step) do
    dots = String.duplicate(".", rem(step, 4))
    "#{text}#{dots}"
  end
end 