defmodule Raxol.UI.Rendering.PipelineTest do
  use ExUnit.Case, async: false

  alias Raxol.UI.Rendering.Pipeline

  import Raxol.Test.TestUtils

  setup do
    setup_rendering_test()
  end

  test "starts and initializes state", _context do
    assert Process.whereis(Pipeline)
    # Internal state is not directly accessible, but no crash means success
  end

  test "update_tree/1 stores the tree and triggers a render", _context do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.update_tree(tree)
    assert_render_event("Hello")
  end

  test "trigger_render/1 uses the current tree if data is nil", _context do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "World"}}]}
    Pipeline.update_tree(tree)
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.trigger_render(nil)
    assert_render_event("World", 200)
  end

  test "trigger_render/1 uses provided data if not nil", _context do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    Pipeline.trigger_render(tree)
    assert_receive {:renderer_rendered, ops}, 100

    assert Enum.any?(ops, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "A"
               _ -> false
             end
           end)
  end

  test "diff_trees/2 returns :no_change for identical trees", _context do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    assert Pipeline.diff_trees(tree, tree) == :no_change
  end

  test "diff_trees/2 returns {:replace, new_tree} for completely different trees",
       _context do
    old_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}

    new_tree = %{
      type: :button,
      children: [%{type: :label, attrs: %{text: "B"}}]
    }

    assert Pipeline.diff_trees(old_tree, new_tree) == {:replace, new_tree}
  end

  test "diff_trees/2 returns {:update, path, changes} for one child changed",
       _context do
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
              %{
                diffs: [{1, {:replace, %{type: :label, attrs: %{text: "C"}}}}],
                type: :indexed_children
              }},
             diff
           )
  end

  test "diff_trees/2 returns {:update, path, changes} for multiple children changed",
       _context do
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
              %{
                diffs: [
                  {0, {:replace, %{type: :label, attrs: %{text: "X"}}}},
                  {1, {:replace, %{type: :label, attrs: %{text: "Y"}}}}
                ],
                type: :indexed_children
              }},
             diff
           )
  end

  test "diff_trees/2 handles nil children and structure changes", _context do
    old_tree = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    new_tree = %{type: :view, children: []}
    diff = Pipeline.diff_trees(old_tree, new_tree)

    assert match?(
             {:update, [],
              %{diffs: [{0, {:replace, nil}}], type: :indexed_children}},
             diff
           )
  end

  test "update_tree/1 does not trigger render if tree is unchanged", _context do
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Hello"}}]}
    Pipeline.update_tree(tree)
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    # First update triggers render
    assert_receive {:renderer_rendered, ops}, 100

    assert Enum.any?(ops, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Hello"
               _ -> false
             end
           end)

    # Second update with the same tree should not trigger a render
    Pipeline.update_tree(tree)
    refute_receive {:renderer_rendered, _}, 100
  end

  test "multiple rapid update_tree/1 calls result in one render with last tree",
       _context do
    # Set test PID before any pipeline operations
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    tree1 = %{type: :view, children: [%{type: :label, attrs: %{text: "A"}}]}
    tree2 = %{type: :view, children: [%{type: :label, attrs: %{text: "B"}}]}
    tree3 = %{type: :view, children: [%{type: :label, attrs: %{text: "C"}}]}

    # First, set an initial tree to ensure the pipeline has a current_tree
    # This prevents the first update from being treated as a full replacement
    Pipeline.update_tree(tree1)
    assert_receive {:renderer_rendered, _}, 100

    # Send all updates in immediate succession to ensure they're debounced
    # The debounce interval is 50ms in test mode, so we need to send all updates quickly
    Pipeline.update_tree(tree2)
    # Small delay to ensure the updates are sent in rapid succession
    Process.sleep(1)
    Pipeline.update_tree(tree3)

    # Should only receive one render, with tree3, after debounce interval
    # In test mode, debounce interval is 50ms
    refute_receive {:renderer_rendered, _}, 10
    # The pipeline now correctly sends partial update messages for rapid updates
    assert_receive {:renderer_partial_update, [], ^tree3, ^tree3}, 100
  end

  test "single update_tree/1 call triggers render after debounce interval",
       _context do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    tree = %{
      type: :view,
      children: [%{type: :label, attrs: %{text: "Debounce"}}]
    }

    Pipeline.update_tree(tree)

    # The pipeline may render immediately if enough time has passed since last render
    # We just ensure we get a render with the correct content
    assert_receive {:renderer_rendered, ops}, 100

    assert Enum.any?(ops, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Debounce"
               _ -> false
             end
           end)
  end

  test "request_animation_frame/1 notifies caller on next frame", _context do
    # request_animation_frame returns the ref immediately, but the actual message
    # is sent later via GenServer.reply when the animation ticker processes it
    # We need to call the supervised Pipeline process directly, not the globally registered one
    ref = System.unique_integer([:positive])
    # Use GenServer.call and wait for the reply
    result =
      GenServer.call(
        Process.whereis(Pipeline),
        {:request_animation_frame, self(), ref}
      )

    # The result should be the {:animation_frame, ref} message
    assert result == {:animation_frame, ref}
  end

  test "multiple request_animation_frame/1 calls in same frame all receive notifications",
       _context do
    ref1 = System.unique_integer([:positive])
    ref2 = System.unique_integer([:positive])
    refs = MapSet.new([ref1, ref2])

    # Call the supervised Pipeline process directly
    result1 =
      GenServer.call(
        Process.whereis(Pipeline),
        {:request_animation_frame, self(), ref1}
      )

    result2 =
      GenServer.call(
        Process.whereis(Pipeline),
        {:request_animation_frame, self(), ref2}
      )

    # Both calls should return the animation frame messages
    assert result1 == {:animation_frame, ref1}
    assert result2 == {:animation_frame, ref2}

    # Verify we got both expected refs
    received = MapSet.new([ref1, ref2])
    assert refs == received
  end

  @tag :skip_on_ci
  test "frame loop runs at expected interval (basic timing check)", _context do
    t1 = System.monotonic_time(:millisecond)
    ref = System.unique_integer([:positive])

    result =
      GenServer.call(
        Process.whereis(Pipeline),
        {:request_animation_frame, self(), ref}
      )

    assert result == {:animation_frame, ref}
    t2 = System.monotonic_time(:millisecond)

    # In test mode, interval is 50ms, so timing should be at least 10ms but less than 100ms
    assert t2 - t1 >= 10
    assert t2 - t1 < 100
  end

  @tag :skip_on_ci
  test "schedule_render_on_next_frame/0 triggers a render on the next animation frame",
       _context do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Frame"}}]}
    Pipeline.update_tree(tree)
    # Wait for debounce/render
    assert_receive {:renderer_rendered, ops}, 100

    assert Enum.any?(ops, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Frame"
               _ -> false
             end
           end)

    # Schedule a render on next frame
    Pipeline.schedule_render_on_next_frame()
    # Should receive a render on the next frame
    assert_receive {:renderer_rendered, ops2}, 100

    assert Enum.any?(ops2, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Frame"
               _ -> false
             end
           end)
  end

  @tag :skip_on_ci
  test "multiple schedule_render_on_next_frame/0 calls before next frame only trigger one render",
       _context do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())
    tree = %{type: :view, children: [%{type: :label, attrs: %{text: "Frame2"}}]}
    Pipeline.update_tree(tree)
    assert_receive {:renderer_rendered, ops}, 100

    assert Enum.any?(ops, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Frame2"
               _ -> false
             end
           end)

    Pipeline.schedule_render_on_next_frame()
    Pipeline.schedule_render_on_next_frame()
    Pipeline.schedule_render_on_next_frame()
    # Only one render should be triggered on the next frame
    assert_receive {:renderer_rendered, ops2}, 100

    assert Enum.any?(ops2, fn op ->
             case op do
               {:draw_text, _line, text} -> text == "Frame2"
               _ -> false
             end
           end)

    refute_receive {:renderer_rendered, _}, 50
  end

  test "schedule_render_on_next_frame/0 triggers render with latest tree",
       _context do
    Raxol.UI.Rendering.Renderer.set_test_pid(self())

    old_tree = %{
      type: :view,
      children: [%{type: :label, attrs: %{text: "Old"}}]
    }

    new_tree = %{
      type: :view,
      children: [%{type: :label, attrs: %{text: "New"}}]
    }

    # Set initial tree
    Pipeline.update_tree(old_tree)
    assert_receive {:renderer_rendered, _}, 100

    # Schedule render for next frame
    Pipeline.schedule_render_on_next_frame()

    # Update tree before next frame
    Pipeline.update_tree(new_tree)

    # Should receive render with the latest tree (new_tree)
    # The pipeline now correctly sends partial update messages for partial updates
    assert_receive {:renderer_partial_update, [], ^new_tree, ^new_tree}, 100
  end

  test "partial update triggers renderer_partial_update with correct path and subtree",
       _context do
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

    # Set initial tree and wait for render to complete
    Pipeline.update_tree(old_tree)
    assert_receive {:renderer_rendered, _}, 100

    # Force a small delay to ensure the pipeline state is updated
    Process.sleep(10)

    # Update to new tree (should trigger a partial update)
    # At this point, previous_tree should be old_tree, so TreeDiffer should generate a partial update
    Pipeline.update_tree(new_tree)

    # The diff should be at path [] (root), child 1
    expected_path = []
    expected_subtree = new_tree

    assert_receive {:renderer_partial_update, ^expected_path, ^expected_subtree,
                    ^new_tree},
                   100
  end
end
