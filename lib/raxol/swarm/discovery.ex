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

      # Tailscale mesh (automatic peer discovery via tailnet)
      Discovery.start_link(strategy: :tailscale, node_basename: "raxol")
      Discovery.start_link(strategy: :tailscale, node_basename: "raxol", tag_filter: "tag:raxol")

      # Custom libcluster topology
      Discovery.start_link(topologies: [my_cluster: [strategy: Cluster.Strategy.Gossip]])

  ## Without libcluster

  When the `:libcluster` dependency is not available, start_link/1 returns
  `{:ok, pid}` of a minimal GenServer that does nothing. Nodes must be
  connected manually via `Node.connect/1`.
  """

  use GenServer

  @compile {:no_warn_undefined, Cluster.Supervisor}

  require Logger

  @type preset :: :gossip | :epmd | :dns | :tailscale

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
          Process.monitor(cluster_pid)

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
  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %{cluster_pid: pid} = state
      ) do
    Logger.warning(
      "Swarm discovery: cluster supervisor exited: #{inspect(reason)}"
    )

    {:noreply, %{state | cluster_pid: nil}}
  end

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
      :tailscale -> tailscale_topology(opts)
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

  defp tailscale_topology(opts) do
    node_basename = Keyword.get(opts, :node_basename, "raxol")
    poll_interval = Keyword.get(opts, :poll_interval, 5_000)

    config =
      [node_basename: node_basename, poll_interval: poll_interval]
      |> maybe_add(opts, :tag_filter)
      |> maybe_add(opts, :use_dns_names)
      |> maybe_add(opts, :tailscale_cli)

    [
      raxol_tailscale: [
        strategy: Raxol.Swarm.Strategy.Tailscale,
        config: config
      ]
    ]
  end

  defp maybe_add(config, opts, key) do
    case Keyword.get(opts, key) do
      nil -> config
      value -> Keyword.put(config, key, value)
    end
  end
end
