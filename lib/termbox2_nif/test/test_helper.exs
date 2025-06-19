ExUnit.start()

defmodule Termbox2NifTest do
  use ExUnit.Case

  test "NIF loads successfully" do
    IO.puts("Testing Termbox2Nif loading...")
    result = :termbox2_nif.tb_init()
    IO.puts("tb_init result: #{inspect(result)}")
    assert is_integer(result)
  end
end
