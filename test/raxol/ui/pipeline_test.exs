defmodule Raxol.UI.Rendering.PipelineTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Rendering.Pipeline

  setup do
    # Start the Renderer GenServer globally for test notifications
    start_supervised!(
      {Raxol.UI.Rendering.Renderer, name: Raxol.UI.Rendering.Renderer}
    )

    # Start the Pipeline GenServer fresh for each test
    {:ok, pid} = start_supervised({Pipeline, name: Pipeline})
    %{pid: pid}
  end

  test "starts and initializes state" do
    assert Process.whereis(Pipeline)
    # Internal state is not directly accessible, but no crash means success
  end

  test "update_tree/1 stores the tree and triggers a render" do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    # Use Renderer.set_test_pid/1 to receive render notifications
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.update_tree(tree)
    assert_receive {:renderer_rendered, ^tree}, 100
  end

  test "trigger_render/1 uses the current tree if data is nil" do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "World"}}]}
    Pipeline.update_tree(tree)
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.trigger_render(nil)
    assert_receive {:renderer_rendered, ^tree}, 100
  end

  test "trigger_render/1 uses provided data if not nil" do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    other = %{type: :view, children: [%{type: :label, attrs: %{text: "B"}}]}
    Pipeline.update_tree(tree)
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.trigger_render(other)
    assert_receive {:renderer_rendered, ^other}, 100
  end

  test "diff_trees/2 returns :no_change for identical trees" do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    assert Pipeline.diff_trees(tree, tree) == :no_change
  end

  test "diff_trees/2 returns {:replace, new_tree} for completely different trees" do
    old_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}

    new_tree = %{
      type: :button,
      children: [%{type: :label, attrs: %{text: "B"}}]
    }

    assert Pipeline.diff_trees(old_tree, new_tree) == {:replace, new_tree}
  end

  test "diff_trees/2 returns {:update, path, changes} for one child changed" do
    old_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "A"}},
        %{type: :label, attrs: %{text: "B"}}
      ]
    }

    new_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "A"}},
        %{type: :label, attrs: %{text: "C"}}
      ]
    }

    diff = Pipeline.diff_trees(old_tree, new_tree)

    assert match?(
             {:update, [],
              [{1, {:replace, %{type: :label, attrs: %{text: "C"}}}}]},
             diff
           )
  end

  test "diff_trees/2 returns {:update, path, changes} for multiple children changed" do
    old_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "A"}},
        %{type: :label, attrs: %{text: "B"}}
      ]
    }

    new_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "X"}},
        %{type: :label, attrs: %{text: "Y"}}
      ]
    }

    diff = Pipeline.diff_trees(old_tree, new_tree)

    assert match?(
             {:update, [],
              [
                {0, {:replace, %{type: :label, attrs: %{text: "X"}}}},
                {1, {:replace, %{type: :label, attrs: %{text: "Y"}}}}
              ]},
             diff
           )
  end

  test "diff_trees/2 handles nil children and structure changes" do
    old_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    new_tree = %{type: :view, children: []}
    diff = Pipeline.diff_trees(old_tree, new_tree)
    assert match?({:update, [], [{0, {:replace, nil}}]}, diff)
  end

  test "update_tree/1 does not trigger render if tree is unchanged" do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    Pipeline.update_tree(tree)
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    # First update triggers render
    assert_receive {:renderer_rendered, ^tree}, 100

    # Second update with the same tree should not trigger a render
    Pipeline.update_tree(tree)
    refute_receive {:renderer_rendered, ^tree}, 100
  end

  test "multiple rapid update_tree/1 calls result in one render with last tree" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree1 = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    tree2 = %{type: :view, children: [%{type: :label, attrs: %{text: "B"}}]}
    tree3 = %{type: :view, children: [%{type: :label, attrs: %{text: "C"}}]}

    Pipeline.update_tree(tree1)
    Pipeline.update_tree(tree2)
    Pipeline.update_tree(tree3)

    # Should only receive one render, with tree3, after debounce interval
    refute_receive {:renderer_rendered, _}, 10
    assert_receive {:renderer_rendered, ^tree3}, 100
    refute_receive {:renderer_rendered, _}, 50
  end

  test "single update_tree/1 call triggers render after debounce interval" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    tree = %{
      type: :view,
      children: [%{type: :label, attrs: %{text: "Debounce"}}]
    }

    Pipeline.update_tree(tree)
    refute_receive {:renderer_rendered, _}, 10
    assert_receive {:renderer_rendered, ^tree}, 100
  end

  test "request_animation_frame/1 notifies caller on next frame" do
    ref = Pipeline.request_animation_frame(self())
    assert_receive {:animation_frame, ^ref}, 100
  end

  test "multiple request_animation_frame/1 calls in same frame all receive notifications" do
    ref1 = Pipeline.request_animation_frame(self())
    ref2 = Pipeline.request_animation_frame(self())
    refs = MapSet.new([ref1, ref2])

    received =
      Stream.repeatedly(fn ->
        receive do
          {:animation_frame, r} -> r
        after
          100 -> :timeout
        end
      end)
      |> Enum.take(2)
      |> Enum.reject(&(&1 == :timeout))
      |> MapSet.new()

    assert refs == received
  end

  test "frame loop runs at expected interval (basic timing check)" do
    t1 = System.monotonic_time(:millisecond)
    ref = Pipeline.request_animation_frame(self())
    assert_receive {:animation_frame, ^ref}, 100
    t2 = System.monotonic_time(:millisecond)
    assert t2 - t1 >= 10
    assert t2 - t1 < 100
  end

  test "schedule_render_on_next_frame/0 triggers a render on the next animation frame" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Frame"}}]}
    Pipeline.update_tree(tree)
    # Wait for debounce/render
    assert_receive {:renderer_rendered, ^tree}, 100
    # Schedule a render on next frame
    Pipeline.schedule_render_on_next_frame()
    # Should receive a render on the next frame
    assert_receive {:renderer_rendered, ^tree}, 100
  end

  test "multiple schedule_render_on_next_frame/0 calls before next frame only trigger one render" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Frame2"}}]}
    Pipeline.update_tree(tree)
    assert_receive {:renderer_rendered, ^tree}, 100
    Pipeline.schedule_render_on_next_frame()
    Pipeline.schedule_render_on_next_frame()
    Pipeline.schedule_render_on_next_frame()
    # Only one render should be triggered on the next frame
    assert_receive {:renderer_rendered, ^tree}, 100
    refute_receive {:renderer_rendered, ^tree}, 50
  end

  test "schedule_render_on_next_frame/0 triggers render with latest tree" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree1 = %{type: :view, children: [%{type: :label, attrs: %{text: "Old"}}]}
    tree2 = %{type: :view, children: [%{type: :label, attrs: %{text: "New"}}]}
    Pipeline.update_tree(tree1)
    assert_receive {:renderer_rendered, ^tree1}, 100
    Pipeline.schedule_render_on_next_frame()
    # Update the tree before the next frame
    Pipeline.update_tree(tree2)
    # Wait for debounce/render
    assert_receive {:renderer_rendered, ^tree2}, 100
    # Schedule another render on next frame
    Pipeline.schedule_render_on_next_frame()
    assert_receive {:renderer_rendered, ^tree2}, 100
  end

  test "partial update triggers renderer_partial_update with correct path and subtree" do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    old_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "A"}},
        %{type: :label, attrs: %{text: "B"}}
      ]
    }

    new_tree = %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "A"}},
        %{type: :label, attrs: %{text: "C"}}
      ]
    }

    # Set initial tree
    Pipeline.update_tree(old_tree)
    assert_receive {:renderer_rendered, ^old_tree}, 100
    # Update to new tree (should trigger a partial update)
    Pipeline.update_tree(new_tree)
    # The diff should be at path [] (root), child 1
    expected_path = []
    expected_subtree = new_tree

    assert_receive {:renderer_partial_update, ^expected_path, ^expected_subtree,
                    ^new_tree},
                   100
  end
end
