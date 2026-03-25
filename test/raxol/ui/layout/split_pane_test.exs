defmodule Raxol.UI.Layout.SplitPaneTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Layout.SplitPane
  alias Raxol.UI.Layout.SplitPane.Resize

  @space %{x: 0, y: 0, width: 80, height: 24}

  describe "new/1" do
    test "creates split pane with defaults" do
      element = SplitPane.new(children: [text_el("a"), text_el("b")])

      assert element.type == :split_pane
      assert element.attrs.direction == :horizontal
      assert element.attrs.ratio == {1, 1}
      assert element.attrs.min_size == 5
      assert length(element.children) == 2
    end

    test "accepts custom direction and ratio" do
      element = SplitPane.new(direction: :vertical, ratio: {1, 2})
      assert element.attrs.direction == :vertical
      assert element.attrs.ratio == {1, 2}
    end
  end

  describe "process/3 horizontal" do
    test "equal split distributes width correctly minus divider" do
      split = SplitPane.new(
        direction: :horizontal,
        ratio: {1, 1},
        children: [text_el("left"), text_el("right")]
      )

      result = SplitPane.process(split, @space, [])

      # With 80 width, 1 divider = 79 usable, each pane gets ~39-40
      text_elements = Enum.filter(result, &(&1.type == :text))
      dividers = Enum.filter(text_elements, &(Map.get(&1.attrs, :component_type) == :split_divider))
      content = Enum.reject(text_elements, &(Map.get(&1.attrs, :component_type) == :split_divider))

      assert length(dividers) == 1
      assert length(content) == 2
    end

    test "unequal ratio {1, 2} gives 1/3 and 2/3" do
      _split = SplitPane.new(
        direction: :horizontal,
        ratio: {1, 2},
        children: [text_el("left"), text_el("right")]
      )

      # 80 - 1 divider = 79 usable
      # 1/3 of 79 = 26, 2/3 = 53 (adjusted for rounding)
      sizes = SplitPane.distribute_space(:horizontal, [1, 2], @space, 5)
      assert Enum.sum(sizes) == 79
      assert hd(sizes) < List.last(sizes)
    end
  end

  describe "process/3 vertical" do
    test "equal vertical split distributes height correctly" do
      split = SplitPane.new(
        direction: :vertical,
        ratio: {1, 1},
        children: [text_el("top"), text_el("bottom")]
      )

      result = SplitPane.process(split, @space, [])
      text_elements = Enum.filter(result, &(&1.type == :text))
      dividers = Enum.filter(text_elements, &(Map.get(&1.attrs, :component_type) == :split_divider))

      assert length(dividers) == 1
      # Divider should be a horizontal line
      [divider] = dividers
      assert divider.attrs.direction == :vertical
    end
  end

  describe "distribute_space/4" do
    test "3-way split {1, 2, 1} works" do
      sizes = SplitPane.distribute_space(:horizontal, [1, 2, 1], @space, 5)
      # 80 - 2 dividers = 78 usable
      assert Enum.sum(sizes) == 78
      assert Enum.at(sizes, 1) > Enum.at(sizes, 0)
      assert Enum.at(sizes, 0) == Enum.at(sizes, 2) || abs(Enum.at(sizes, 0) - Enum.at(sizes, 2)) <= 1
    end

    test "min size constraints clamp small panes" do
      small_space = %{x: 0, y: 0, width: 20, height: 24}
      sizes = SplitPane.distribute_space(:horizontal, [1, 10], small_space, 5)

      # First pane should be at least 5
      assert hd(sizes) >= 5
      assert Enum.sum(sizes) == 19  # 20 - 1 divider
    end
  end

  describe "divider rendering" do
    test "divider elements at correct positions" do
      split = SplitPane.new(
        direction: :horizontal,
        ratio: {1, 1},
        children: [text_el("a"), text_el("b")]
      )

      result = SplitPane.process(split, @space, [])
      dividers = Enum.filter(result, fn el ->
        el.type == :text and Map.get(el.attrs, :component_type) == :split_divider
      end)

      assert length(dividers) == 1
      [divider] = dividers
      assert divider.attrs.pane_index == 0
      # Divider x should be at the boundary between panes
      sizes = SplitPane.distribute_space(:horizontal, [1, 1], @space, 5)
      assert divider.x == hd(sizes)
    end

    test "divider attrs carry component_type and pane_index" do
      split = SplitPane.new(
        direction: :horizontal,
        ratio: {1, 1, 1},
        children: [text_el("a"), text_el("b"), text_el("c")],
        id: "test_split"
      )

      result = SplitPane.process(split, @space, [])
      dividers =
        result
        |> Enum.filter(fn el ->
          el.type == :text and Map.get(el.attrs, :component_type) == :split_divider
        end)
        |> Enum.sort_by(& &1.attrs.pane_index)

      assert length(dividers) == 2
      assert Enum.at(dividers, 0).attrs.pane_index == 0
      assert Enum.at(dividers, 1).attrs.pane_index == 1
      assert Enum.at(dividers, 0).attrs.split_id == "test_split"
    end
  end

  describe "measure_split_pane/2" do
    test "returns available space dimensions" do
      element = SplitPane.new(children: [text_el("a")])
      result = SplitPane.measure_split_pane(element, @space)
      assert result == %{width: 80, height: 24}
    end
  end

  describe "from_preset/2" do
    test "sidebar preset generates correct structure" do
      children = [text_el("sidebar"), text_el("main")]
      element = SplitPane.from_preset(:sidebar, children)

      assert element.type == :split_pane
      assert element.attrs.direction == :horizontal
      assert element.attrs.ratio == {1, 3}
      assert length(element.children) == 2
    end

    test "dashboard preset generates nested structure" do
      children = [text_el("sidebar"), text_el("content"), text_el("status")]
      element = SplitPane.from_preset(:dashboard, children)

      assert element.type == :split_pane
      assert element.attrs.direction == :horizontal
      # Inner right pane should be a nested split_pane
      inner = Enum.at(element.children, 1)
      assert inner.type == :split_pane
      assert inner.attrs.direction == :vertical
    end

    test "triple preset" do
      children = [text_el("a"), text_el("b"), text_el("c")]
      element = SplitPane.from_preset(:triple, children)

      assert element.attrs.ratio == {1, 1, 1}
      assert length(element.children) == 3
    end

    test "stacked preset" do
      children = [text_el("top"), text_el("bottom")]
      element = SplitPane.from_preset(:stacked, children)

      assert element.attrs.direction == :vertical
      assert element.attrs.ratio == {1, 1}
    end
  end

  describe "edge cases" do
    test "single child produces no divider" do
      split = SplitPane.new(
        direction: :horizontal,
        children: [text_el("only")]
      )

      result = SplitPane.process(split, @space, [])
      dividers = Enum.filter(result, fn el ->
        el.type == :text and Map.get(el.attrs, :component_type) == :split_divider
      end)

      assert dividers == []
    end

    test "zero available space" do
      zero_space = %{x: 0, y: 0, width: 0, height: 0}
      split = SplitPane.new(children: [text_el("a"), text_el("b")])

      result = SplitPane.process(split, zero_space, [])
      assert is_list(result)
    end

    test "no children returns accumulator unchanged" do
      split = SplitPane.new(children: [])
      acc = [%{type: :text, x: 0, y: 0, text: "existing"}]

      result = SplitPane.process(split, @space, acc)
      assert result == acc
    end
  end

  describe "Resize.check_divider_hit/3" do
    test "detects hit on horizontal divider" do
      dividers = [{39, 0, 1, 24, 0}]
      assert Resize.check_divider_hit({39, 10}, dividers, :horizontal) == {:hit, 0}
      assert Resize.check_divider_hit({20, 10}, dividers, :horizontal) == :miss
    end

    test "detects hit on vertical divider" do
      dividers = [{0, 11, 80, 1, 0}]
      assert Resize.check_divider_hit({40, 11}, dividers, :vertical) == {:hit, 0}
      assert Resize.check_divider_hit({40, 5}, dividers, :vertical) == :miss
    end
  end

  describe "Resize.handle_keyboard_resize/4" do
    test "ctrl+right grows first pane in horizontal split" do
      key = %{ctrl: true, key: :arrow_right}
      assert {:ok, new_ratio} = Resize.handle_keyboard_resize(key, :horizontal, {1, 1})
      {a, b} = new_ratio
      assert a / (a + b) > 0.5
    end

    test "ctrl+left shrinks first pane in horizontal split" do
      key = %{ctrl: true, key: :arrow_left}
      assert {:ok, new_ratio} = Resize.handle_keyboard_resize(key, :horizontal, {1, 1})
      {a, b} = new_ratio
      assert a / (a + b) < 0.5
    end

    test "ctrl+down grows first pane in vertical split" do
      key = %{ctrl: true, key: :arrow_down}
      assert {:ok, _new_ratio} = Resize.handle_keyboard_resize(key, :vertical, {1, 1})
    end

    test "ignores unrelated key events" do
      key = %{ctrl: false, key: :arrow_right}
      assert Resize.handle_keyboard_resize(key, :horizontal, {1, 1}) == :ignore
    end
  end

  describe "Resize.divider_positions/3" do
    test "returns correct positions for horizontal split" do
      positions = Resize.divider_positions(:horizontal, {1, 1}, @space)
      assert length(positions) == 1
      [{x, y, w, h, idx}] = positions
      assert y == 0
      assert w == 1
      assert h == 24
      assert idx == 0
      assert x > 0 and x < 80
    end

    test "returns empty for single pane" do
      assert Resize.divider_positions(:horizontal, {1}, @space) == []
    end
  end

  # Helper to create simple text elements for testing
  defp text_el(content) do
    %{type: :text, attrs: %{content: content}, children: []}
  end
end
