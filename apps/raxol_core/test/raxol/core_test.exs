defmodule Raxol.CoreTest do
  use ExUnit.Case
  doctest Raxol.Core

  test "greets the world" do
    assert Raxol.Core.hello() == :world
  end
end
