defmodule Raxol.Swarm.CommsManager do
  @moduledoc """
  Bandwidth-aware synchronization manager.

  Monitors link quality per node and adapts sync frequency. Routes
  messages through priority queues, dropping low-priority traffic
  on degraded links. Critical messages are always sent immediately.
  """

  use GenServer

  require Logger

  @type link_quality :: :excellent | :good | :degraded | :poor | :disconnected
  @type priority :: :critical | :high | :normal | :low

  @type link_info :: %{
          quality: link_quality(),
          rtt_ms: float(),
          last_ping: integer(),
          messages_sent: non_neg_integer(),
          messages_dropped: non_neg_integer()
        }

  @type t :: %__MODULE__{
          links: %{node() => link_info()},
          queues: %{node() => :queue.queue()},
          flush_interval_ms: pos_integer(),
          flush_ref: reference() | nil,
          node_monitor: GenServer.server()
        }

  defstruct links: %{},
            queues: %{},
            flush_interval_ms: 500,
            flush_ref: nil,
            node_monitor: Raxol.Swarm.NodeMonitor

  # RTT thresholds for link quality classification
  @excellent_threshold_ms 10
  @good_threshold_ms 50
  @degraded_threshold_ms 200
  @poor_threshold_ms 1_000

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Send a message to a remote node with the given priority."
  @spec send_msg(GenServer.server(), node(), term(), priority()) ::
          :ok | {:error, :disconnected}
  def send_msg(server \\ __MODULE__, node, message, priority \\ :normal) do
    GenServer.call(server, {:send, node, message, priority})
  end

  @doc "Returns the current link quality for a node."
  @spec get_link_quality(GenServer.server(), node()) :: link_quality()
  def get_link_quality(server \\ __MODULE__, node) do
    GenServer.call(server, {:get_link_quality, node})
  end

  @doc "Returns all links and their quality."
  @spec get_all_links(GenServer.server()) :: %{node() => link_quality()}
  def get_all_links(server \\ __MODULE__) do
    GenServer.call(server, :get_all_links)
  end

  @doc "Update link quality based on health data from NodeMonitor."
  @spec update_link(GenServer.server(), node(), float()) :: :ok
  def update_link(server \\ __MODULE__, node, rtt_ms) do
    GenServer.cast(server, {:update_link, node, rtt_ms})
  end

  @doc "Mark a node as disconnected."
  @spec mark_disconnected(GenServer.server(), node()) :: :ok
  def mark_disconnected(server \\ __MODULE__, node) do
    GenServer.cast(server, {:mark_disconnected, node})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    flush_interval = Keyword.get(opts, :flush_interval_ms, 500)
    node_monitor = Keyword.get(opts, :node_monitor, Raxol.Swarm.NodeMonitor)

    state = %__MODULE__{
      flush_interval_ms: flush_interval,
      node_monitor: node_monitor
    }

    {:ok, schedule_flush(state)}
  end

  @impl true
  def handle_call({:send, node, message, priority}, _from, state) do
    link = Map.get(state.links, node, default_link())

    case link.quality do
      :disconnected ->
        {:reply, {:error, :disconnected}, state}

      quality ->
        if should_send?(quality, priority) do
          state = enqueue(state, node, {priority, message})
          {:reply, :ok, state}
        else
          state = record_drop(state, node)
          {:reply, :ok, state}
        end
    end
  end

  @impl true
  def handle_call({:get_link_quality, node}, _from, state) do
    quality =
      case Map.get(state.links, node) do
        nil -> :disconnected
        link -> link.quality
      end

    {:reply, quality, state}
  end

  @impl true
  def handle_call(:get_all_links, _from, state) do
    links = Map.new(state.links, fn {node, link} -> {node, link.quality} end)
    {:reply, links, state}
  end

  @impl true
  def handle_cast({:update_link, node, rtt_ms}, %__MODULE__{} = state) do
    now = System.monotonic_time(:millisecond)
    quality = classify_rtt(rtt_ms)

    link =
      Map.get(state.links, node, default_link())
      |> Map.merge(%{quality: quality, rtt_ms: rtt_ms, last_ping: now})

    {:noreply, %__MODULE__{state | links: Map.put(state.links, node, link)}}
  end

  @impl true
  def handle_cast({:mark_disconnected, node}, %__MODULE__{} = state) do
    link =
      Map.get(state.links, node, default_link())
      |> Map.put(:quality, :disconnected)

    {:noreply, %__MODULE__{state | links: Map.put(state.links, node, link)}}
  end

  @impl true
  def handle_info(:flush, %__MODULE__{} = state) do
    state = flush_queues(state)
    {:noreply, schedule_flush(state)}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Private --

  defp default_link do
    %{
      quality: :good,
      rtt_ms: 0.0,
      last_ping: System.monotonic_time(:millisecond),
      messages_sent: 0,
      messages_dropped: 0
    }
  end

  defp classify_rtt(rtt_ms) when rtt_ms < @excellent_threshold_ms,
    do: :excellent

  defp classify_rtt(rtt_ms) when rtt_ms < @good_threshold_ms, do: :good
  defp classify_rtt(rtt_ms) when rtt_ms < @degraded_threshold_ms, do: :degraded
  defp classify_rtt(rtt_ms) when rtt_ms < @poor_threshold_ms, do: :poor
  defp classify_rtt(_rtt_ms), do: :disconnected

  defp should_send?(_quality, :critical), do: true
  defp should_send?(_quality, :high), do: true
  defp should_send?(:excellent, _priority), do: true
  defp should_send?(:good, _priority), do: true
  defp should_send?(:degraded, :normal), do: true
  defp should_send?(:degraded, :low), do: false
  defp should_send?(:poor, :normal), do: false
  defp should_send?(:poor, :low), do: false
  defp should_send?(_, _), do: false

  defp enqueue(%__MODULE__{} = state, node, item) do
    queue = Map.get(state.queues, node, :queue.new())
    queue = :queue.in(item, queue)
    %__MODULE__{state | queues: Map.put(state.queues, node, queue)}
  end

  defp record_drop(%__MODULE__{} = state, node) do
    link = Map.get(state.links, node, default_link())
    link = %{link | messages_dropped: link.messages_dropped + 1}
    %__MODULE__{state | links: Map.put(state.links, node, link)}
  end

  defp flush_queues(%__MODULE__{} = state) do
    Enum.reduce(state.queues, state, fn {node, queue}, acc ->
      flush_node_queue(acc, node, queue)
    end)
  end

  defp flush_node_queue(%__MODULE__{} = state, node, queue) do
    case :queue.out(queue) do
      {:empty, _} ->
        %__MODULE__{state | queues: Map.put(state.queues, node, :queue.new())}

      {{:value, {_priority, message}}, rest} ->
        send_to_node(node, message)
        link = Map.get(state.links, node, default_link())
        link = %{link | messages_sent: link.messages_sent + 1}
        state = %__MODULE__{state | links: Map.put(state.links, node, link)}
        flush_node_queue(state, node, rest)
    end
  end

  defp send_to_node(node, message) do
    send({:swarm_comms, node}, {:swarm_msg, message})
  end

  defp schedule_flush(%__MODULE__{} = state) do
    _ = if state.flush_ref, do: Process.cancel_timer(state.flush_ref)
    ref = Process.send_after(self(), :flush, state.flush_interval_ms)
    %__MODULE__{state | flush_ref: ref}
  end
end
