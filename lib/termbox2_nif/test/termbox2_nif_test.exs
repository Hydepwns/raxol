defmodule Termbox2NifTest do
  use ExUnit.Case
  @moduletag :docker

  test "termbox2_nif loads and initializes" do
    # Check if we're in a real TTY
    case System.cmd("tty", []) do
      {tty, 0} ->
        tty = String.trim(tty)

        if String.starts_with?(tty, "/dev/") do
          IO.puts("Running in real TTY: #{tty}")

          # Print module info
          IO.puts("Module info: #{inspect(:code.which(:termbox2_nif))}")
          IO.puts("Priv dir: #{inspect(:code.priv_dir(:termbox2_nif))}")

          # Initialize termbox
          IO.puts("Initializing termbox...")
          result = :termbox2_nif.tb_init()
          IO.puts("Init result: #{inspect(result)}")
          assert result == 0

          # Get terminal dimensions
          width = :termbox2_nif.tb_width()
          height = :termbox2_nif.tb_height()
          IO.puts("Terminal dimensions: #{width}x#{height}")
          assert is_integer(width)
          assert is_integer(height)
          assert width > 0
          assert height > 0

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
          :timer.sleep(1000)

          # Shutdown termbox
          :termbox2_nif.tb_shutdown()
        else
          IO.puts("Not running in a real TTY: #{tty}")
          :skip
        end

      _ ->
        IO.puts("Failed to determine TTY")
        :skip
    end
  end
end
