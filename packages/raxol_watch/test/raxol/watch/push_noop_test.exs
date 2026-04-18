defmodule Raxol.Watch.Push.NoopTest do
  use ExUnit.Case

  alias Raxol.Watch.Push.Noop

  setup do
    start_supervised!(Noop)
    Noop.clear()
    :ok
  end

  describe "push/2" do
    test "records the push" do
      assert :ok = Noop.push("token_1", %{title: "Alert", body: "Test"})
      assert [{"token_1", %{title: "Alert"}}] = Noop.get_pushes()
    end

    test "records multiple pushes newest first" do
      Noop.push("tok_a", %{body: "first"})
      Noop.push("tok_b", %{body: "second"})

      pushes = Noop.get_pushes()
      assert length(pushes) == 2
      assert {"tok_b", %{body: "second"}} = hd(pushes)
    end
  end

  describe "get_pushes/0" do
    test "returns empty list initially" do
      assert Noop.get_pushes() == []
    end
  end

  describe "clear/0" do
    test "empties the push history" do
      Noop.push("tok", %{body: "test"})
      Noop.clear()
      assert Noop.get_pushes() == []
    end
  end
end
