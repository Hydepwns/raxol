defmodule Raxol.Swarm.Discovery do
  @moduledoc """
  Automatic node discovery via libcluster.

  Wraps `Cluster.Supervisor` with strategy presets for common deployment
  scenarios. When libcluster is not installed, falls back to manual
  `Node.connect/1`.

  ## Strategy Presets

      # LAN multicast (zero config)
      Discovery.start_link(strategy: :gossip)

      # Static node list
      Discovery.start_link(strategy: :epmd, hosts: [:"a@10.0.0.1", :"b@10.0.0.2"])

      # DNS polling (Fly.io, Kubernetes)
      Discovery.start_link(strategy: :dns, query: "raxol.internal", node_basename: "raxol")

      # Custom libcluster topology
      Discovery.start_link(topologies: [my_cluster: [strategy: Cluster.Strategy.Gossip]])

  ## Without libcluster

  When the `:libcluster` dependency is not available, start_link/1 returns
  `{:ok, pid}` of a minimal GenServer that does nothing. Nodes must be
  connected manually via `Node.connect/1`.
  """

  use GenServer

  require Logger

  @type preset :: :gossip | :epmd | :dns

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(Cluster.Supervisor)
  end

  @impl true
  def init(opts) do
    topologies = resolve_topologies(opts)

    if available?() and topologies != [] do
      case Cluster.Supervisor.start_link([
             topologies,
             [name: :"#{__MODULE__}.ClusterSupervisor"]
           ]) do
        {:ok, cluster_pid} ->
          Process.link(cluster_pid)

          Logger.info(
            "Swarm discovery: started with #{length(topologies)} topology(ies)"
          )

          {:ok, %{cluster_pid: cluster_pid, topologies: topologies}}

        {:error, reason} ->
          Logger.warning(
            "Swarm discovery: failed to start libcluster: #{inspect(reason)}"
          )

          {:ok, %{cluster_pid: nil, topologies: []}}
      end
    else
      if topologies != [] do
        Logger.info(
          "Swarm discovery: libcluster not available, manual node connection required"
        )
      end

      {:ok, %{cluster_pid: nil, topologies: []}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Topology resolution --

  defp resolve_topologies(opts) do
    case Keyword.get(opts, :topologies) do
      nil -> build_preset(opts)
      topologies when is_list(topologies) -> topologies
    end
  end

  defp build_preset(opts) do
    case Keyword.get(opts, :strategy) do
      nil -> []
      :gossip -> gossip_topology(opts)
      :epmd -> epmd_topology(opts)
      :dns -> dns_topology(opts)
    end
  end

  defp gossip_topology(opts) do
    config =
      opts
      |> Keyword.take([
        :port,
        :multicast_addr,
        :multicast_ttl,
        :multicast_interface
      ])
      |> then(fn config ->
        if config == [], do: [], else: [config: config]
      end)

    [raxol_gossip: [{:strategy, Cluster.Strategy.Gossip} | config]]
  end

  defp epmd_topology(opts) do
    hosts = Keyword.get(opts, :hosts, [])

    if hosts == [] do
      Logger.warning("Swarm discovery: :epmd strategy requires :hosts option")
      []
    else
      [raxol_epmd: [strategy: Cluster.Strategy.Epmd, config: [hosts: hosts]]]
    end
  end

  defp dns_topology(opts) do
    query = Keyword.get(opts, :query)
    node_basename = Keyword.get(opts, :node_basename, "raxol")
    poll_interval = Keyword.get(opts, :poll_interval, 5_000)

    if is_nil(query) do
      Logger.warning("Swarm discovery: :dns strategy requires :query option")
      []
    else
      [
        raxol_dns: [
          strategy: Cluster.Strategy.DNSPoll,
          config: [
            polling_interval: poll_interval,
            query: query,
            node_basename: node_basename
          ]
        ]
      ]
    end
  end
end
