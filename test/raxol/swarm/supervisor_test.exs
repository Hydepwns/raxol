defmodule Raxol.Swarm.SupervisorTest do
  use ExUnit.Case, async: false

  alias Raxol.Swarm

  describe "start_link/1" do
    test "starts all children" do
      name = :"swarm_sup_#{System.unique_integer([:positive])}"

      # Use unique names to avoid conflicts with other tests
      nm_name = :"nm_#{System.unique_integer([:positive])}"
      cm_name = :"cm_#{System.unique_integer([:positive])}"
      tp_name = :"tp_#{System.unique_integer([:positive])}"
      to_name = :"to_#{System.unique_integer([:positive])}"

      {:ok, sup} =
        Swarm.Supervisor.start_link(
          name: name,
          node_monitor: [name: nm_name, ping_interval_ms: 60_000],
          comms_manager: [name: cm_name, flush_interval_ms: 60_000],
          topology: [name: tp_name, node_id: :test@host],
          tactical_overlay: [
            name: to_name,
            node_id: :test@host,
            sync_interval_ms: 60_000,
            anti_entropy_interval_ms: 60_000
          ]
        )

      assert Process.alive?(sup)

      children = Supervisor.which_children(name)
      assert length(children) == 4

      child_modules = Enum.map(children, fn {mod, _pid, _type, _mods} -> mod end)
      assert Raxol.Swarm.NodeMonitor in child_modules
      assert Raxol.Swarm.CommsManager in child_modules
      assert Raxol.Swarm.Topology in child_modules
      assert Raxol.Swarm.TacticalOverlay in child_modules
    end
  end
end
