defmodule Raxol.Swarm.Supervisor do
  @moduledoc """
  Supervisor for the distributed swarm subsystem.

  Start order matters:
  1. Discovery -- auto-connects nodes via libcluster (optional)
  2. NodeMonitor -- provides health data
  3. CommsManager -- uses health data
  4. Topology -- subscribes to NodeMonitor, runs elections
  5. TacticalOverlay -- subscribes to NodeMonitor, syncs CRDTs to peers

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
    discovery_opts = Keyword.get(opts, :discovery, [])
    node_monitor_opts = Keyword.get(opts, :node_monitor, [])
    comms_opts = Keyword.get(opts, :comms_manager, [])
    topology_opts = Keyword.get(opts, :topology, [])
    overlay_opts = Keyword.get(opts, :tactical_overlay, [])

    children =
      maybe_discovery(discovery_opts) ++
        [
          {Raxol.Swarm.NodeMonitor, node_monitor_opts},
          {Raxol.Swarm.CommsManager, comms_opts},
          {Raxol.Swarm.Topology, topology_opts},
          {Raxol.Swarm.TacticalOverlay, overlay_opts}
        ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_discovery([]), do: []
  defp maybe_discovery(opts), do: [{Raxol.Swarm.Discovery, opts}]
end
