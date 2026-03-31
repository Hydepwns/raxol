defmodule Raxol.Terminal.Env do
  @moduledoc false

  @doc """
  Returns `true` when terminal hardware should be skipped (test / CI).

  Checks at runtime so the result is correct even when the package is
  compiled as a path dependency (which always compiles as `:prod`).
  """
  @spec test?() :: boolean()
  def test? do
    System.get_env("SKIP_TERMBOX2_TESTS") == "true" or
      System.get_env("MIX_ENV") == "test"
  end
end
