defmodule Raxol.MCP.ContextTreeTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.{ContextTree, Registry}

  setup do
    {:ok, registry} = Registry.start_link(name: :"ctx_reg_#{System.unique_integer()}")
    %{registry: registry}
  end

  defp context(registry, opts \\ []) do
    %{
      registry: registry,
      session_id: Keyword.get(opts, :session_id, "test_session"),
      view_tree: Keyword.get(opts, :view_tree),
      model: Keyword.get(opts, :model)
    }
  end

  describe "build/2" do
    test "builds session source with id and timestamp", %{registry: r} do
      tree = ContextTree.build([:session], context(r))
      assert tree.session.id == "test_session"
      assert is_binary(tree.session.timestamp)
    end

    test "builds tools source from registry", %{registry: r} do
      :ok =
        Registry.register_tools(r, [
          %{name: "t1", description: "d", inputSchema: %{}, callback: fn _ -> {:ok, nil} end}
        ])

      tree = ContextTree.build([:tools], context(r))
      assert is_list(tree.tools)
      assert hd(tree.tools).name == "t1"
    end

    test "builds model source from registered resources", %{registry: r} do
      :ok =
        Registry.register_resources(r, [
          %{
            uri: "raxol://session/test_session/model/counter",
            name: "Counter",
            description: "Counter value",
            callback: fn -> {:ok, 42} end
          }
        ])

      tree = ContextTree.build([:model], context(r))
      assert tree.model == %{"counter" => 42}
    end

    test "builds widgets source from view tree", %{registry: r} do
      view_tree = %{
        type: :panel,
        id: "main",
        children: [%{type: :button, id: "btn", content: "Click"}]
      }

      tree = ContextTree.build([:widgets], context(r, view_tree: view_tree))
      assert tree.widgets.type == :panel
      assert hd(tree.widgets.children).type == :button
    end

    test "widgets source returns empty map when no view tree", %{registry: r} do
      tree = ContextTree.build([:widgets], context(r))
      assert tree.widgets == []
    end

    test "strips callbacks from widget tree", %{registry: r} do
      view_tree = %{
        type: :button,
        id: "btn",
        on_click: fn -> :noop end,
        callback: fn -> :noop end
      }

      tree = ContextTree.build([:widgets], context(r, view_tree: view_tree))
      refute Map.has_key?(tree.widgets, :on_click)
      refute Map.has_key?(tree.widgets, :callback)
    end
  end

  describe "build_all/1" do
    test "includes all sources", %{registry: r} do
      tree = ContextTree.build_all(context(r))
      assert Map.has_key?(tree, :model)
      assert Map.has_key?(tree, :widgets)
      assert Map.has_key?(tree, :tools)
      assert Map.has_key?(tree, :session)
    end
  end

  describe "filter_for_role/2" do
    test "full role returns everything", %{registry: r} do
      tree = ContextTree.build_all(context(r))
      assert ContextTree.filter_for_role(tree, :full) == tree
    end

    test "observer excludes tools", %{registry: r} do
      tree = ContextTree.build_all(context(r))
      filtered = ContextTree.filter_for_role(tree, :observer)
      assert Map.has_key?(filtered, :model)
      assert Map.has_key?(filtered, :widgets)
      assert Map.has_key?(filtered, :session)
      refute Map.has_key?(filtered, :tools)
    end

    test "operator includes tools but nothing extra", %{registry: r} do
      tree = ContextTree.build_all(context(r))
      filtered = ContextTree.filter_for_role(tree, :operator)
      assert Map.has_key?(filtered, :tools)
      assert Map.has_key?(filtered, :model)
    end
  end
end
