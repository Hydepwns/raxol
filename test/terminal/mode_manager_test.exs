defmodule Raxol.Terminal.ModeManagerTest do
  Application.ensure_all_started(:mox) # Explicitly start Mox
  use ExUnit.Case, async: false
  require Mox
  use Mox

  setup :verify_on_exit!

  test "it should start the mode manager" do
    assert :ok = Raxol.Terminal.ModeManager.start_link([])
  end
end
