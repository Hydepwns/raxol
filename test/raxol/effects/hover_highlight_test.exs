defmodule Raxol.Effects.HoverHighlightTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.HoverHighlight

  describe "new/1" do
    test "creates with default config" do
      h = HoverHighlight.new()
      assert h.config.color == :cyan
      assert h.config.style == :border
      assert h.config.intensity == 0.6
      assert h.config.fade_ms == 200
      assert h.config.enabled == true
      assert h.target == nil
      assert h.active == false
    end

    test "merges custom config" do
      h = HoverHighlight.new(%{color: :yellow, intensity: 0.8})
      assert h.config.color == :yellow
      assert h.config.intensity == 0.8
      assert h.config.style == :border
    end
  end

  describe "set_target/3" do
    test "activates on valid bounds" do
      h = HoverHighlight.new()
      bounds = %{x: 5, y: 2, width: 20, height: 3}
      h = HoverHighlight.set_target(h, bounds, "my_widget")

      assert h.active == true
      assert h.target == bounds
      assert h.widget_id == "my_widget"
      assert h.fade_start == nil
    end

    test "nil bounds starts fade-out" do
      h =
        HoverHighlight.new()
        |> HoverHighlight.set_target(%{x: 0, y: 0, width: 10, height: 1}, "w")
        |> HoverHighlight.set_target(nil, nil)

      assert h.active == false
      assert h.fade_start != nil
    end

    test "nil bounds on inactive highlight is no-op" do
      h = HoverHighlight.new()
      h = HoverHighlight.set_target(h, nil, nil)
      assert h.active == false
      assert h.fade_start == nil
    end

    test "disabled highlight ignores set_target" do
      h = HoverHighlight.new(%{enabled: false})
      h = HoverHighlight.set_target(h, %{x: 0, y: 0, width: 5, height: 1}, "w")
      assert h.active == false
      assert h.target == nil
    end
  end

  describe "visible?/1" do
    test "not visible when no target" do
      refute HoverHighlight.visible?(HoverHighlight.new())
    end

    test "visible when active" do
      h =
        HoverHighlight.new()
        |> HoverHighlight.set_target(%{x: 0, y: 0, width: 5, height: 1}, "w")

      assert HoverHighlight.visible?(h)
    end

    test "not visible when disabled" do
      h =
        HoverHighlight.new(%{enabled: false})
        |> Map.put(:target, %{x: 0, y: 0, width: 5, height: 1})
        |> Map.put(:active, true)

      refute HoverHighlight.visible?(h)
    end

    test "visible during fade" do
      h =
        HoverHighlight.new()
        |> HoverHighlight.set_target(%{x: 0, y: 0, width: 5, height: 1}, "w")
        |> HoverHighlight.set_target(nil, nil)

      # Just started fading, should still be visible
      assert HoverHighlight.visible?(h)
    end
  end

  describe "clear/1" do
    test "resets all state" do
      h =
        HoverHighlight.new()
        |> HoverHighlight.set_target(%{x: 0, y: 0, width: 5, height: 1}, "w")
        |> HoverHighlight.clear()

      assert h.target == nil
      assert h.widget_id == nil
      assert h.active == false
      assert h.fade_start == nil
    end
  end

  describe "set_enabled/2" do
    test "can disable effect" do
      h = HoverHighlight.new() |> HoverHighlight.set_enabled(false)
      assert h.config.enabled == false
    end

    test "can re-enable effect" do
      h =
        HoverHighlight.new(%{enabled: false})
        |> HoverHighlight.set_enabled(true)

      assert h.config.enabled == true
    end
  end

  describe "update_config/2" do
    test "merges new config values" do
      h =
        HoverHighlight.new()
        |> HoverHighlight.update_config(%{color: :magenta, fade_ms: 500})

      assert h.config.color == :magenta
      assert h.config.fade_ms == 500
      assert h.config.style == :border
    end
  end
end
