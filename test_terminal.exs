defmodule TerminalTest do
  def run do
    IO.puts("Testing termbox2_nif in real TTY...")

    # Check if we're in a real TTY
    case System.cmd("tty", []) do
      {tty, 0} ->
        tty = String.trim(tty)
        if String.starts_with?(tty, "/dev/") do
          IO.puts("Running in real TTY: #{tty}")
          test_termbox()
        else
          IO.puts("Not running in a real TTY: #{tty}")
        end
      _ ->
        IO.puts("Failed to determine TTY")
    end
  end

  defp test_termbox do
    # Initialize termbox
    IO.puts("Initializing termbox...")
    case :termbox2_nif.tb_init() do
      0 ->
        IO.puts("Termbox initialized successfully")

        # Get terminal dimensions
        width = :termbox2_nif.tb_width()
        height = :termbox2_nif.tb_height()
        IO.puts("Terminal dimensions: #{width}x#{height}")

        # Clear screen
        :termbox2_nif.tb_clear()

        # Draw a simple pattern
        for y <- 0..(height-1) do
          for x <- 0..(width-1) do
            ch = if rem(x + y, 2) == 0, do: ?#, else: ?.
            :termbox2_nif.tb_set_cell(x, y, ch, 0xFFFFFF, 0x000000)
          end
        end

        # Present the changes
        :termbox2_nif.tb_present()

        # Wait for a key press
        IO.puts("\nPress any key to exit...")
        :timer.sleep(2000)

        # Shutdown termbox
        :termbox2_nif.tb_shutdown()
        IO.puts("Termbox shutdown complete")

      error ->
        IO.puts("Failed to initialize termbox: #{inspect(error)}")
    end
  end
end

TerminalTest.run()
