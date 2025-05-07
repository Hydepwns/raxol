defmodule SimpleMoxTest do
  Application.ensure_all_started(:mox)
  use ExUnit.Case, async: false
  require Mox
  use Mox

  test "simple mox check" do
    assert true
  end
end
