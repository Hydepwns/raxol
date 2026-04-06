defmodule Raxol.MCP.StructuredScreenshotTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.StructuredScreenshot

  describe "from_view_tree/1" do
    test "returns empty list for nil" do
      assert StructuredScreenshot.from_view_tree(nil) == []
    end

    test "summarizes a single node" do
      node = %{type: :button, id: "submit", content: "Go", on_click: fn -> :noop end}
      [summary] = StructuredScreenshot.from_view_tree(node)

      assert summary.type == :button
      assert summary.id == "submit"
      assert summary.content == "Go"
      assert summary.children == []
    end

    test "summarizes nested children" do
      tree = %{
        type: :panel,
        id: "main",
        children: [
          %{type: :text, id: "label", content: "Hello"},
          %{type: :button, id: "btn", content: "Click"}
        ]
      }

      [summary] = StructuredScreenshot.from_view_tree(tree)
      assert summary.type == :panel
      assert length(summary.children) == 2
      assert Enum.map(summary.children, & &1.type) == [:text, :button]
    end

    test "handles list input" do
      nodes = [
        %{type: :text, id: "a"},
        %{type: :text, id: "b"}
      ]

      summaries = StructuredScreenshot.from_view_tree(nodes)
      assert length(summaries) == 2
    end

    test "handles non-string content gracefully" do
      node = %{type: :text, id: "x", content: 42}
      [summary] = StructuredScreenshot.from_view_tree(node)
      refute Map.has_key?(summary, :content)
    end

    test "defaults missing type to :unknown" do
      node = %{id: "orphan"}
      [summary] = StructuredScreenshot.from_view_tree(node)
      assert summary.type == :unknown
    end
  end

  describe "to_json/1" do
    test "serializes summaries to JSON string" do
      summaries = [%{type: :button, id: "btn", children: []}]
      json = StructuredScreenshot.to_json(summaries)
      assert is_binary(json)
      assert json =~ "button"
    end
  end
end
