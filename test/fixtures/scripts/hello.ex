defmodule Raxol.Terminal.Script.Hello do
  @moduledoc '''
  A simple hello world script for testing the Raxol terminal emulator.
  '''

  def hello(name \\ "World") do
    "Hello, #{name}!"
  end

  def run(args \\ []) do
    name = List.first(args) || "World"
    hello(name)
  end
end
