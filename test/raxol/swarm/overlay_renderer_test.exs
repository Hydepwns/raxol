defmodule Raxol.Swarm.OverlayRendererTest do
  use ExUnit.Case, async: true

  alias Raxol.Swarm.OverlayRenderer

  describe "render_overlay/2" do
    test "renders entities as positioned cells" do
      now = 1000
      overlay = %{
        entities: %{
          ship_1: %{
            id: :ship_1,
            status: :active,
            position: {0.5, 0.5, 0.0},
            last_updated: now
          }
        },
        waypoints: []
      }

      cells = OverlayRenderer.render_overlay(overlay, now: now, region: {0, 0, 80, 24})
      assert length(cells) > 0
      # All cells should be {x, y, char, fg, bg, attrs} tuples
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end

    test "renders stale entities with yellow" do
      now = 10_000
      overlay = %{
        entities: %{
          ship_1: %{
            id: :ship_1,
            status: :active,
            position: {0.5, 0.5, 0.0},
            last_updated: now - 6_000
          }
        },
        waypoints: []
      }

      cells = OverlayRenderer.render_overlay(overlay, now: now, region: {0, 0, 80, 24})
      assert Enum.any?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :yellow end)
    end

    test "renders offline entities with red" do
      now = 100_000
      overlay = %{
        entities: %{
          ship_1: %{
            id: :ship_1,
            status: :active,
            position: {0.5, 0.5, 0.0},
            last_updated: now - 31_000
          }
        },
        waypoints: []
      }

      cells = OverlayRenderer.render_overlay(overlay, now: now, region: {0, 0, 80, 24})
      assert Enum.any?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :red end)
    end

    test "renders waypoints in cyan" do
      now = 1000
      overlay = %{
        entities: %{},
        waypoints: [
          %{id: "wp1", label: "Alpha", position: {0.5, 0.5, 0.0}}
        ]
      }

      cells = OverlayRenderer.render_overlay(overlay, now: now, region: {0, 0, 80, 24})
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :cyan end)
    end

    test "excludes out-of-bounds entities" do
      now = 1000
      overlay = %{
        entities: %{
          ship_1: %{
            id: :ship_1,
            status: :active,
            position: {2.0, 2.0, 0.0},
            last_updated: now
          }
        },
        waypoints: []
      }

      cells = OverlayRenderer.render_overlay(overlay, now: now, region: {0, 0, 10, 10})
      # Position 2.0 * 9 = 18, which is > 10 -- should be excluded
      assert cells == []
    end
  end

  describe "render_wingmate_summary/3" do
    test "renders node statuses" do
      now = 1000
      nodes = [
        %{node: :wing1@host, role: :wingmate, avg_rtt_ms: 12.0, last_seen: now, status: :healthy},
        %{node: :wing2@host, role: :observer, avg_rtt_ms: 50.0, last_seen: now - 6_000, status: :suspect}
      ]

      cells = OverlayRenderer.render_wingmate_summary({0, 0, 60, 5}, nodes, now: now)
      assert length(cells) > 0
      # Second node should have yellow (stale)
      line2_cells = Enum.filter(cells, fn {_x, y, _c, _fg, _bg, _a} -> y == 1 end)
      assert Enum.any?(line2_cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :yellow end)
    end
  end

  describe "render_comms_status/3" do
    test "renders link quality bars" do
      links = %{
        wing1: %{quality: :excellent, rtt_ms: 5.0},
        wing2: %{quality: :poor, rtt_ms: 800.0}
      }

      cells = OverlayRenderer.render_comms_status({0, 0, 40, 5}, links)
      assert length(cells) > 0
      # Should have both green and red cells
      colors = cells |> Enum.map(fn {_x, _y, _c, fg, _bg, _a} -> fg end) |> Enum.uniq()
      assert :green in colors
      assert :red in colors
    end
  end
end
