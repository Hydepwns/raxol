defmodule Raxol.Terminal.Commands.TrivialTest do
  use ExUnit.Case, async: false

  test "trivial test" do
    assert 1 == 1
  end

  test "check process_input return value" do
    emulator = Raxol.Terminal.Emulator.new(80, 24)
    result = Raxol.Terminal.Emulator.process_input(emulator, "\e[4h")
    assert is_tuple(result)
    {emulator_result, output} = result
    assert is_struct(emulator_result)
    assert is_binary(output)
  end
end
