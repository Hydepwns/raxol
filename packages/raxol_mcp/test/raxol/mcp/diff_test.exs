defmodule Raxol.MCP.DiffTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.Diff

  describe "diff/2" do
    test "empty maps produce no changes" do
      result = Diff.diff(%{}, %{})
      assert result == %{added: %{}, removed: [], changed: %{}}
      refute Diff.changed?(result)
    end

    test "detects added keys" do
      result = Diff.diff(%{}, %{a: 1, b: 2})
      assert result.added == %{a: 1, b: 2}
      assert result.removed == []
      assert result.changed == %{}
      assert Diff.changed?(result)
    end

    test "detects removed keys" do
      result = Diff.diff(%{a: 1, b: 2}, %{})
      assert result.added == %{}
      assert Enum.sort(result.removed) == [:a, :b]
      assert result.changed == %{}
      assert Diff.changed?(result)
    end

    test "detects changed values" do
      result = Diff.diff(%{a: 1, b: 2}, %{a: 1, b: 99})
      assert result.added == %{}
      assert result.removed == []
      assert result.changed == %{b: {2, 99}}
      assert Diff.changed?(result)
    end

    test "handles mixed add/remove/change" do
      old = %{keep: :same, change: :old, remove: :gone}
      new = %{keep: :same, change: :new, add: :fresh}

      result = Diff.diff(old, new)
      assert result.added == %{add: :fresh}
      assert result.removed == [:remove]
      assert result.changed == %{change: {:old, :new}}
    end

    test "identical maps produce no changes" do
      map = %{a: 1, b: [2, 3], c: %{nested: true}}
      result = Diff.diff(map, map)
      refute Diff.changed?(result)
    end
  end
end
