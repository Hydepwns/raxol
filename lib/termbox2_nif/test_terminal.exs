defmodule TerminalTest do
  @moduledoc """
  Tests for the termbox2_nif module, verifying terminal UI functionality and error handling.
  """

  def run do
    IO.puts("Testing termbox2_nif in real TTY...")

    # Print module info
    IO.puts("Module info: #{inspect(:code.which(:termbox2_nif))}")
    IO.puts("Priv dir: #{inspect(:code.priv_dir(:termbox2_nif))}")

    # Initialize termbox
    IO.puts("Initializing termbox...")
    result = :termbox2_nif.tb_init()
    IO.puts("Init result: #{inspect(result)}")

    if result == 0 do
      # Get terminal dimensions
      width = :termbox2_nif.tb_width()
      height = :termbox2_nif.tb_height()
      IO.puts("Terminal dimensions: #{width}x#{height}")

      # Clear screen
      :termbox2_nif.tb_clear()

      # Draw a simple pattern
      for y <- 0..(height - 1) do
        for x <- 0..(width - 1) do
          ch = if rem(x + y, 2) == 0, do: ?#, else: ?.
          :termbox2_nif.tb_set_cell(x, y, ch, 0xFFFFFF, 0x000000)
        end
      end

      # Present the changes
      :termbox2_nif.tb_present()

      # Wait a bit to see the pattern
      :timer.sleep(2000)

      # Shutdown termbox
      :termbox2_nif.tb_shutdown()
    end
  end
end

TerminalTest.run()
