defmodule Raxol.Debug.DiffFormatterTest do
  use ExUnit.Case, async: true

  alias Raxol.Debug.{DiffFormatter, Snapshot}

  describe "format_changes/1" do
    test "formats changed values" do
      changes = [{:changed, [:count], 41, 42}]
      [line] = DiffFormatter.format_changes(changes)

      assert line.type == :changed
      assert line.path_str == "count"
      assert line.detail =~ "41"
      assert line.detail =~ "42"
    end

    test "formats added values" do
      changes = [{:added, [:name], "hello"}]
      [line] = DiffFormatter.format_changes(changes)

      assert line.type == :added
      assert line.path_str == "name"
      assert line.detail =~ "hello"
    end

    test "formats removed values" do
      changes = [{:removed, [:old], "gone"}]
      [line] = DiffFormatter.format_changes(changes)

      assert line.type == :removed
      assert line.path_str == "old"
      assert line.detail =~ "gone"
    end

    test "formats nested paths with dots" do
      changes = [{:changed, [:a, :b, :c], 1, 2}]
      [line] = DiffFormatter.format_changes(changes)
      assert line.path_str == "a.b.c"
    end

    test "returns empty list for non-list input" do
      assert DiffFormatter.format_changes(nil) == []
    end
  end

  describe "format_snapshot_diff/1" do
    test "diffs model_before and model_after" do
      snap = Snapshot.new(0, :test, %{a: 1}, %{a: 2})
      lines = DiffFormatter.format_snapshot_diff(snap)

      assert length(lines) == 1
      assert hd(lines).type == :changed
      assert hd(lines).path_str == "a"
    end

    test "handles no changes" do
      snap = Snapshot.new(0, :test, %{a: 1}, %{a: 1})
      lines = DiffFormatter.format_snapshot_diff(snap)
      assert lines == []
    end
  end

  describe "render_line/1" do
    test "renders added with + prefix" do
      line = %{type: :added, path_str: "x", detail: "42"}
      {prefix, text} = DiffFormatter.render_line(line)
      assert prefix == "+ "
      assert text =~ "x"
    end

    test "renders removed with - prefix" do
      line = %{type: :removed, path_str: "x", detail: "42"}
      {prefix, _text} = DiffFormatter.render_line(line)
      assert prefix == "- "
    end

    test "renders changed with ~ prefix" do
      line = %{type: :changed, path_str: "x", detail: "1 -> 2"}
      {prefix, _text} = DiffFormatter.render_line(line)
      assert prefix == "~ "
    end
  end

  describe "format_path/1" do
    test "joins atoms with dots" do
      assert DiffFormatter.format_path([:a, :b, :c]) == "a.b.c"
    end

    test "handles empty path" do
      assert DiffFormatter.format_path([]) == "(root)"
    end

    test "handles mixed key types" do
      assert DiffFormatter.format_path([:a, "b", 42]) == "a.b.42"
    end
  end
end
