defmodule TerminalCompatibility do
  def verify do
    IO.puts("Verifying terminal compatibility...")

    # Check terminal type
    term = System.get_env("TERM")
    IO.puts("Terminal type: #{term}")

    # Check color support
    colors = System.get_env("COLORTERM")
    IO.puts("Color support: #{colors}")

    # Check terminal size
    {width, height} = :io.columns()
    IO.puts("Terminal size: #{width}x#{height}")

    # Check UTF-8 support
    IO.puts("UTF-8 support: #{System.get_env("LANG")}")

    # Check graphics support
    IO.puts("Graphics support: #{System.get_env("TERM_PROGRAM")}")

    # Test basic ANSI sequences
    IO.puts("\nTesting ANSI sequences:")
    IO.puts("\x1b[1mBold\x1b[0m")
    IO.puts("\x1b[31mRed\x1b[0m")
    IO.puts("\x1b[32mGreen\x1b[0m")
    IO.puts("\x1b[33mYellow\x1b[0m")
    IO.puts("\x1b[34mBlue\x1b[0m")
    IO.puts("\x1b[35mMagenta\x1b[0m")
    IO.puts("\x1b[36mCyan\x1b[0m")

    # Test cursor movement
    IO.puts("\nTesting cursor movement:")
    IO.puts("\x1b[2J") # Clear screen
    IO.puts("\x1b[H")  # Move to home position
    IO.puts("Cursor movement test")

    # Test screen modes
    IO.puts("\nTesting screen modes:")
    IO.puts("\x1b[?1049h") # Save cursor and enter alternate screen buffer
    IO.puts("Alternate screen buffer test")
    IO.puts("\x1b[?1049l") # Restore cursor and exit alternate screen buffer

    # Test mouse support
    IO.puts("\nTesting mouse support:")
    IO.puts("\x1b[?1000h") # Enable mouse tracking
    IO.puts("Mouse tracking enabled")
    IO.puts("\x1b[?1000l") # Disable mouse tracking

    # Test bracketed paste mode
    IO.puts("\nTesting bracketed paste mode:")
    IO.puts("\x1b[?2004h") # Enable bracketed paste mode
    IO.puts("Bracketed paste mode enabled")
    IO.puts("\x1b[?2004l") # Disable bracketed paste mode

    IO.puts("\nTerminal compatibility verification complete.")
  end
end

TerminalCompatibility.verify()
