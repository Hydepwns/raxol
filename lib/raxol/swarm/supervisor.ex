defmodule Raxol.Swarm.Supervisor do
  @moduledoc """
  Supervisor for the distributed swarm subsystem.

  Start order matters:
  1. NodeMonitor -- provides health data
  2. CommsManager -- uses health data
  3. Topology -- uses comms
  4. TacticalOverlay -- uses all three

  Strategy: one_for_one. Each module can crash and restart independently.
  NodeMonitor re-discovers nodes on restart. CommsManager re-probes links.
  Topology re-elects. TacticalOverlay re-syncs via anti-entropy.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    node_monitor_opts = Keyword.get(opts, :node_monitor, [])
    comms_opts = Keyword.get(opts, :comms_manager, [])
    topology_opts = Keyword.get(opts, :topology, [])
    overlay_opts = Keyword.get(opts, :tactical_overlay, [])

    children = [
      {Raxol.Swarm.NodeMonitor, node_monitor_opts},
      {Raxol.Swarm.CommsManager, comms_opts},
      {Raxol.Swarm.Topology, topology_opts},
      {Raxol.Swarm.TacticalOverlay, overlay_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
