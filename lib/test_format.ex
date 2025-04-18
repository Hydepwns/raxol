defmodule   Raxol.TestFormat do
  @moduledoc """
  This is a test module for demonstrating the pre-commit formatting hook.
  """

    def     test_function(  a,    b  ) do
        a   +  b
    end

  def another_test(x) when is_integer(x)  do
    x    *      2
  end
end
