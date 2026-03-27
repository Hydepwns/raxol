defmodule Raxol.Swarm.Strategy.Tailscale do
  @moduledoc """
  libcluster strategy that discovers BEAM nodes via Tailscale.

  Polls `tailscale status --json` to find online peers, optionally
  filters by Tailscale tags, and connects them as BEAM nodes.

  ## Options

  * `node_basename` - Short name for BEAM nodes (required; e.g. "raxol")
  * `poll_interval` - How often to poll in milliseconds (default: 5_000)
  * `tag_filter` - Only connect to peers with this tag (optional; e.g. "tag:raxol")
  * `use_dns_names` - Use MagicDNS names instead of IPs (default: false)
  * `tailscale_cli` - Path to tailscale binary (default: "tailscale")

  ## Usage

      config :libcluster,
        topologies: [
          tailscale: [
            strategy: Raxol.Swarm.Strategy.Tailscale,
            config: [
              node_basename: "raxol",
              tag_filter: "tag:raxol",
              poll_interval: 5_000
            ]
          ]
        ]

  Or via Discovery preset:

      Raxol.Swarm.Discovery.start_link(
        strategy: :tailscale,
        node_basename: "raxol",
        tag_filter: "tag:raxol"
      )

  ## How it works

  1. Runs `tailscale status --json`
  2. Extracts online peers from the response
  3. Filters by tag if `tag_filter` is set
  4. Constructs BEAM node names as `<node_basename>@<tailscale_ip>`
     (or `<node_basename>@<dns_name>` when `use_dns_names: true`)
  5. Connects/disconnects via libcluster's `Cluster.Strategy` API

  Requires `tailscale` CLI to be installed and the node to be logged
  into a tailnet.
  """

  use GenServer

  alias Cluster.Strategy
  alias Cluster.Strategy.State

  @default_poll_interval 5_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]) do
    init([%State{state | meta: MapSet.new()}])
  end

  def init([%State{} = state]) do
    {:ok, do_poll(state)}
  end

  @impl true
  def handle_info(:timeout, state), do: handle_info(:poll, state)
  def handle_info(:poll, state), do: {:noreply, do_poll(state)}
  def handle_info(_, state), do: {:noreply, state}

  defp do_poll(
         %State{
           topology: topology,
           connect: connect,
           disconnect: disconnect,
           list_nodes: list_nodes
         } = state
       ) do
    new_nodelist = state |> get_nodes() |> MapSet.new()
    removed = MapSet.difference(state.meta, new_nodelist)

    new_nodelist =
      case Strategy.disconnect_nodes(
             topology,
             disconnect,
             list_nodes,
             MapSet.to_list(removed)
           ) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.put(acc, n)
          end)
      end

    new_nodelist =
      case Strategy.connect_nodes(
             topology,
             connect,
             list_nodes,
             MapSet.to_list(new_nodelist)
           ) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.delete(acc, n)
          end)
      end

    Process.send_after(self(), :poll, poll_interval(state))

    %{state | meta: new_nodelist}
  end

  defp poll_interval(%{config: config}) do
    Keyword.get(config, :poll_interval, @default_poll_interval)
  end

  defp get_nodes(%State{config: config, topology: topology}) do
    node_basename = Keyword.get(config, :node_basename, "raxol")
    tag_filter = Keyword.get(config, :tag_filter)
    use_dns = Keyword.get(config, :use_dns_names, false)
    cli = Keyword.get(config, :tailscale_cli, "tailscale")
    me = node()

    case fetch_status(cli) do
      {:ok, status} ->
        status
        |> extract_peers()
        |> filter_online()
        |> filter_by_tag(tag_filter)
        |> Enum.map(&peer_to_node(&1, node_basename, use_dns))
        |> Enum.reject(fn n -> n == me end)

      {:error, reason} ->
        Cluster.Logger.warn(
          topology,
          "tailscale status failed: #{inspect(reason)}"
        )

        []
    end
  end

  @doc false
  def fetch_status(cli) do
    case System.cmd(cli, ["status", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, :json_parse_failed}
        end

      {output, code} ->
        {:error, {:exit_code, code, output}}
    end
  rescue
    e in [ErlangError] -> {:error, {:cmd_failed, Exception.message(e)}}
  end

  @doc false
  def extract_peers(%{"Peer" => peers}) when is_map(peers),
    do: Map.values(peers)

  def extract_peers(_), do: []

  @doc false
  def filter_online(peers) do
    Enum.filter(peers, fn peer -> peer["Online"] == true end)
  end

  @doc false
  def filter_by_tag(peers, nil), do: peers

  def filter_by_tag(peers, tag) do
    Enum.filter(peers, fn peer ->
      tags = peer["Tags"] || []
      tag in tags
    end)
  end

  @doc false
  def peer_to_node(peer, node_basename, use_dns) do
    host =
      if use_dns do
        peer["DNSName"]
        |> to_string()
        |> String.trim_trailing(".")
      else
        peer
        |> get_in(["TailscaleIPs", Access.at(0)])
        |> to_string()
      end

    :"#{node_basename}@#{host}"
  end
end
