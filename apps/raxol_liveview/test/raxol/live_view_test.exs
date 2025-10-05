defmodule Raxol.LiveViewTest do
  use ExUnit.Case
  doctest Raxol.LiveView

  test "greets the world" do
    assert Raxol.LiveView.hello() == :world
  end
end
