defmodule Raxol.Debug.InspectorTest do
  use ExUnit.Case, async: true

  alias Raxol.Debug.Inspector

  describe "flatten/2" do
    test "flattens a flat map into lines" do
      model = %{a: 1, b: "hello", c: true}
      lines = Inspector.flatten(model)

      assert length(lines) == 3
      assert Enum.all?(lines, &(&1.depth == 0))
      assert Enum.all?(lines, &(&1.expandable == false))
    end

    test "marks nested maps as expandable" do
      model = %{outer: %{inner: 42}}
      lines = Inspector.flatten(model)

      outer_line = Enum.find(lines, &(&1.key == :outer))
      assert outer_line.expandable == true
      assert outer_line.expanded == false
      assert outer_line.value_preview =~ "1 key"
    end

    test "expands nested maps when path is in expanded set" do
      model = %{outer: %{inner: 42}}
      expanded = MapSet.new([[:outer]])
      lines = Inspector.flatten(model, expanded)

      outer_line = Enum.find(lines, &(&1.key == :outer))
      assert outer_line.expanded == true

      inner_line = Enum.find(lines, &(&1.key == :inner))
      assert inner_line != nil
      assert inner_line.depth == 1
      assert inner_line.value_preview == "42"
    end

    test "handles empty maps" do
      lines = Inspector.flatten(%{})
      assert lines == []
    end

    test "handles deeply nested structures" do
      model = %{a: %{b: %{c: %{d: 1}}}}
      expanded = MapSet.new([[:a], [:a, :b], [:a, :b, :c]])
      lines = Inspector.flatten(model, expanded)

      depths = Enum.map(lines, & &1.depth)
      assert depths == [0, 1, 2, 3]
    end

    test "previews lists with item count" do
      model = %{items: [1, 2, 3]}
      lines = Inspector.flatten(model)

      line = Enum.find(lines, &(&1.key == :items))
      assert line.value_preview =~ "3 items"
    end

    test "sorts keys alphabetically" do
      model = %{z: 1, a: 2, m: 3}
      lines = Inspector.flatten(model)

      keys = Enum.map(lines, & &1.key)
      assert keys == [:a, :m, :z]
    end
  end

  describe "toggle/2" do
    test "adds path when not present" do
      paths = MapSet.new()
      result = Inspector.toggle(paths, [:a, :b])
      assert MapSet.member?(result, [:a, :b])
    end

    test "removes path when present" do
      paths = MapSet.new([[:a, :b]])
      result = Inspector.toggle(paths, [:a, :b])
      refute MapSet.member?(result, [:a, :b])
    end
  end

  describe "expand_all/2" do
    test "expands all paths to given depth" do
      model = %{a: %{b: %{c: %{d: 1}}}}
      paths = Inspector.expand_all(model, 2)

      assert MapSet.member?(paths, [:a])
      assert MapSet.member?(paths, [:a, :b])
      refute MapSet.member?(paths, [:a, :b, :c])
    end

    test "handles empty model" do
      paths = Inspector.expand_all(%{})
      assert MapSet.size(paths) == 0
    end
  end
end
