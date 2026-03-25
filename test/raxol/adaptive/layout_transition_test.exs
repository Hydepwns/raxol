defmodule Raxol.Adaptive.LayoutTransitionTest do
  use ExUnit.Case, async: true

  alias Raxol.Adaptive.LayoutTransition

  @from %{
    panes: [
      %{id: :a, position: {0, 0}, size: {40, 24}, z_order: 0},
      %{id: :b, position: {40, 0}, size: {40, 24}, z_order: 1}
    ],
    focus: :a,
    hidden: []
  }

  @to %{
    panes: [
      %{id: :a, position: {0, 0}, size: {60, 24}, z_order: 0},
      %{id: :b, position: {60, 0}, size: {20, 24}, z_order: 1}
    ],
    focus: :b,
    hidden: [:c]
  }

  describe "start/3" do
    test "creates a transition with progress 0" do
      t = LayoutTransition.start(@from, @to)
      assert t.progress == 0.0
      assert t.from == @from
      assert t.to == @to
      assert t.duration_ms == 300
    end

    test "accepts custom duration and easing" do
      t = LayoutTransition.start(@from, @to, duration_ms: 500, easing: :linear)
      assert t.duration_ms == 500
      assert t.easing == :linear
    end
  end

  describe "tick/2" do
    test "returns in_progress at midpoint" do
      t = LayoutTransition.start(@from, @to, easing: :linear)
      {:in_progress, layout, updated} = LayoutTransition.tick(t, 150)

      assert updated.progress == 0.5
      pane_a = Enum.find(layout.panes, fn p -> p.id == :a end)
      # At t=0.5 with linear: size should be (50, 24)
      {w, _h} = pane_a.size
      assert_in_delta w, 50.0, 0.1
    end

    test "returns done when elapsed >= duration" do
      t = LayoutTransition.start(@from, @to, easing: :linear)
      {:done, layout} = LayoutTransition.tick(t, 300)

      assert layout == @to
    end

    test "returns done when elapsed > duration" do
      t = LayoutTransition.start(@from, @to, easing: :linear)
      {:done, layout} = LayoutTransition.tick(t, 500)

      assert layout == @to
    end

    test "focus snaps at midpoint" do
      t = LayoutTransition.start(@from, @to, easing: :linear)

      {:in_progress, early, _} = LayoutTransition.tick(t, 100)
      assert early.focus == :a

      {:in_progress, late, _} = LayoutTransition.tick(t, 200)
      assert late.focus == :b
    end

    test "hidden snaps at midpoint" do
      t = LayoutTransition.start(@from, @to, easing: :linear)

      {:in_progress, early, _} = LayoutTransition.tick(t, 100)
      assert early.hidden == []

      {:in_progress, late, _} = LayoutTransition.tick(t, 200)
      assert late.hidden == [:c]
    end
  end

  describe "cancel/1" do
    test "returns interpolated layout at current progress" do
      t = LayoutTransition.start(@from, @to, easing: :linear)
      {:in_progress, _layout, updated} = LayoutTransition.tick(t, 150)

      cancelled = LayoutTransition.cancel(updated)
      pane_a = Enum.find(cancelled.panes, fn p -> p.id == :a end)
      {w, _h} = pane_a.size
      assert_in_delta w, 50.0, 0.1
    end
  end

  describe "interpolate_layout/3" do
    test "t=0 returns from layout" do
      layout = LayoutTransition.interpolate_layout(@from, @to, 0.0)
      pane_a = Enum.find(layout.panes, fn p -> p.id == :a end)
      assert pane_a.size == {40, 24}
    end

    test "t=1 returns to layout" do
      layout = LayoutTransition.interpolate_layout(@from, @to, 1.0)
      pane_a = Enum.find(layout.panes, fn p -> p.id == :a end)
      assert pane_a.size == {60, 24}
    end

    test "handles panes only in from" do
      from = %{panes: [%{id: :x, position: {0, 0}, size: {10, 10}, z_order: 0}], focus: :x, hidden: []}
      to = %{panes: [], focus: nil, hidden: []}

      layout = LayoutTransition.interpolate_layout(from, to, 0.5)
      assert length(layout.panes) == 1
    end

    test "handles panes only in to" do
      from = %{panes: [], focus: nil, hidden: []}
      to = %{panes: [%{id: :y, position: {0, 0}, size: {10, 10}, z_order: 0}], focus: :y, hidden: []}

      layout = LayoutTransition.interpolate_layout(from, to, 0.5)
      assert length(layout.panes) == 1
    end
  end

  describe "easing" do
    test "ease_in_out starts and ends slow" do
      t = LayoutTransition.start(@from, @to, easing: :ease_in_out)

      # At 10% elapsed, progress should be less than 10% (starts slow)
      {:in_progress, early, _} = LayoutTransition.tick(t, 30)
      pane_a = Enum.find(early.panes, fn p -> p.id == :a end)
      {w, _} = pane_a.size
      # With ease_in_out at t=0.1: eased = 2*0.1^2 = 0.02
      # Size should be closer to 40 than 42
      assert w < 42
    end

    test "ease_out decelerates" do
      t = LayoutTransition.start(@from, @to, easing: :ease_out)

      # At 50% elapsed, progress should be > 50% (front-loaded)
      {:in_progress, mid, _} = LayoutTransition.tick(t, 150)
      pane_a = Enum.find(mid.panes, fn p -> p.id == :a end)
      {w, _} = pane_a.size
      # ease_out at 0.5: 1 - (1-0.5)^2 = 0.75 -> size = 40 + 20*0.75 = 55
      assert w > 50
    end
  end
end
