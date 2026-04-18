defmodule Raxol.UI.Layout.PreparerHintsTest do
  use ExUnit.Case, async: true

  alias Raxol.Animation.Hint
  alias Raxol.UI.Layout.Preparer

  describe "animation hints propagation" do
    test "text element carries hints through prepare" do
      hint = %Hint{property: :opacity, to: 1.0}
      element = %{type: :text, content: "hello", animation_hints: [hint]}

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == [hint]
    end

    test "label element carries hints through prepare" do
      hint = %Hint{property: :color, to: :cyan}
      element = %{type: :label, content: "label", animation_hints: [hint]}

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == [hint]
    end

    test "button element carries hints through prepare" do
      hint = %Hint{property: :bg, to: :blue}
      element = %{type: :button, text: "Click", animation_hints: [hint]}

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == [hint]
    end

    test "container element carries hints and propagates to children" do
      child_hint = %Hint{property: :opacity, to: 1.0}
      parent_hint = %Hint{property: :bg, to: :red}

      element = %{
        type: :box,
        children: [
          %{type: :text, content: "child", animation_hints: [child_hint]}
        ],
        animation_hints: [parent_hint]
      }

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == [parent_hint]
      assert [child] = prepared.children
      assert child.animation_hints == [child_hint]
    end

    test "element without hints defaults to empty list" do
      element = %{type: :text, content: "plain"}

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == []
    end

    test "generic element carries hints" do
      hint = %Hint{property: :width, to: 100}
      element = %{type: :custom_widget, width: 50, animation_hints: [hint]}

      prepared = Preparer.prepare(element)

      assert prepared.animation_hints == [hint]
    end

    test "incremental prepare preserves hints on unchanged content" do
      hint = %Hint{property: :opacity, to: 1.0}
      element = %{type: :text, content: "same", animation_hints: [hint]}

      old_prepared = Preparer.prepare(element)
      new_prepared = Preparer.prepare_incremental(element, old_prepared)

      assert new_prepared.animation_hints == [hint]
    end
  end
end
