defmodule Raxol.PluginTest do
  use ExUnit.Case
  doctest Raxol.Plugin

  test "greets the world" do
    assert Raxol.Plugin.hello() == :world
  end
end
