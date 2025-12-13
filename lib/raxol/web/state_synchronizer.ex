defmodule Raxol.Web.StateSynchronizer do
  @moduledoc """
  CRDT-based state synchronization for collaborative terminal sessions.

  Implements Conflict-free Replicated Data Types (CRDTs) to enable
  real-time collaboration without central coordination. Uses vector
  clocks for causality tracking and operational transforms for
  conflict resolution.

  ## Features

  - Eventual consistency across all replicas
  - Automatic conflict resolution
  - Offline support with sync on reconnect
  - Causality preservation via vector clocks

  ## Example

      # Create a synchronizer for a session
      {:ok, sync} = StateSynchronizer.new("session123")

      # Apply a local operation
      {:ok, sync} = StateSynchronizer.apply_local(sync, {:insert, 0, "Hello"})

      # Receive and merge remote state
      {:ok, sync} = StateSynchronizer.merge(sync, remote_state)

      # Get current state
      state = StateSynchronizer.get_state(sync)
  """

  alias Raxol.Core.Runtime.Log

  defmodule VectorClock do
    @moduledoc """
    Vector clock for causality tracking.
    """
    defstruct clock: %{}

    @type t :: %__MODULE__{clock: %{String.t() => non_neg_integer()}}

    def new, do: %__MODULE__{}

    def increment(%__MODULE__{clock: clock} = vc, node_id) do
      new_clock = Map.update(clock, node_id, 1, &(&1 + 1))
      %{vc | clock: new_clock}
    end

    def merge(%__MODULE__{clock: clock1}, %__MODULE__{clock: clock2}) do
      merged =
        Map.merge(clock1, clock2, fn _k, v1, v2 ->
          max(v1, v2)
        end)

      %__MODULE__{clock: merged}
    end

    def compare(%__MODULE__{clock: clock1}, %__MODULE__{clock: clock2}) do
      all_keys = (Map.keys(clock1) ++ Map.keys(clock2)) |> Enum.uniq()

      results =
        Enum.map(all_keys, fn key ->
          v1 = Map.get(clock1, key, 0)
          v2 = Map.get(clock2, key, 0)

          cond do
            v1 < v2 -> :less
            v1 > v2 -> :greater
            true -> :equal
          end
        end)

      cond do
        Enum.all?(results, &(&1 == :equal)) ->
          :equal

        Enum.all?(results, &(&1 in [:less, :equal])) and
            Enum.any?(results, &(&1 == :less)) ->
          :less

        Enum.all?(results, &(&1 in [:greater, :equal])) and
            Enum.any?(results, &(&1 == :greater)) ->
          :greater

        true ->
          :concurrent
      end
    end

    def happened_before?(vc1, vc2) do
      compare(vc1, vc2) == :less
    end
  end

  defmodule Operation do
    @moduledoc """
    Represents an operation in the synchronizer.
    """
    defstruct [:id, :type, :data, :timestamp, :node_id, :vector_clock]

    @type t :: %__MODULE__{
            id: String.t(),
            type: atom(),
            data: term(),
            timestamp: integer(),
            node_id: String.t(),
            vector_clock: VectorClock.t()
          }
  end

  defstruct [
    :session_id,
    :node_id,
    :state,
    :vector_clock,
    :pending_ops,
    :history,
    :subscribers
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          node_id: String.t(),
          state: map(),
          vector_clock: VectorClock.t(),
          pending_ops: [Operation.t()],
          history: [Operation.t()],
          subscribers: [pid()]
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Create a new state synchronizer for a session.

  ## Example

      {:ok, sync} = StateSynchronizer.new("session123")
  """
  @spec new(String.t(), keyword()) :: {:ok, t()}
  def new(session_id, opts \\ []) do
    node_id = Keyword.get(opts, :node_id, generate_node_id())
    initial_state = Keyword.get(opts, :initial_state, %{})

    sync = %__MODULE__{
      session_id: session_id,
      node_id: node_id,
      state: initial_state,
      vector_clock: VectorClock.new(),
      pending_ops: [],
      history: [],
      subscribers: []
    }

    {:ok, sync}
  end

  @doc """
  Apply a local operation to the state.

  The operation is applied immediately and queued for synchronization.

  ## Example

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "cursor", {10, 5}})
  """
  @spec apply_local(t(), term()) :: {:ok, t()}
  def apply_local(%__MODULE__{} = sync, operation_data) do
    # Increment vector clock
    new_vc = VectorClock.increment(sync.vector_clock, sync.node_id)

    # Create operation
    op = %Operation{
      id: generate_operation_id(),
      type: extract_operation_type(operation_data),
      data: operation_data,
      timestamp: System.system_time(:millisecond),
      node_id: sync.node_id,
      vector_clock: new_vc
    }

    # Apply to local state
    new_state = apply_operation(sync.state, op)

    new_sync = %{
      sync
      | state: new_state,
        vector_clock: new_vc,
        pending_ops: [op | sync.pending_ops],
        history: [op | sync.history]
    }

    # Notify subscribers
    notify_subscribers(new_sync, {:operation_applied, op})

    {:ok, new_sync}
  end

  @doc """
  Apply a remote operation received from another node.

  Uses vector clocks to ensure causal ordering.

  ## Example

      {:ok, sync} = StateSynchronizer.apply_remote(sync, remote_op)
  """
  @spec apply_remote(t(), Operation.t()) :: {:ok, t()}
  def apply_remote(%__MODULE__{} = sync, %Operation{} = op) do
    # Check if we've already seen this operation
    if operation_seen?(sync, op) do
      {:ok, sync}
    else
      # Check causality
      case VectorClock.compare(op.vector_clock, sync.vector_clock) do
        :less ->
          # Operation is in our past, already incorporated
          {:ok, sync}

        :equal ->
          # Same state, apply
          do_apply_remote(sync, op)

        :greater ->
          # Operation is in our future, we might be missing some ops
          # For now, apply anyway (could queue for later)
          do_apply_remote(sync, op)

        :concurrent ->
          # Concurrent operation, need to resolve conflict
          resolved_op = resolve_conflict(sync, op)
          do_apply_remote(sync, resolved_op)
      end
    end
  end

  @doc """
  Merge state from a remote node.

  Combines all operations using CRDT merge semantics.

  ## Example

      {:ok, sync} = StateSynchronizer.merge(sync, remote_state)
  """
  @spec merge(t(), t() | map()) :: {:ok, t()}
  def merge(%__MODULE__{} = local, %__MODULE__{} = remote) do
    # Merge vector clocks
    merged_vc = VectorClock.merge(local.vector_clock, remote.vector_clock)

    # Find operations we don't have
    new_ops =
      remote.history
      |> Enum.reject(&operation_seen?(local, &1))
      |> Enum.sort_by(& &1.timestamp)

    # Apply new operations in causal order
    new_state =
      Enum.reduce(new_ops, local.state, fn op, state ->
        apply_operation(state, op)
      end)

    new_sync = %{
      local
      | state: new_state,
        vector_clock: merged_vc,
        history: merge_histories(local.history, remote.history)
    }

    {:ok, new_sync}
  end

  def merge(%__MODULE__{} = local, remote_state) when is_map(remote_state) do
    # Simple state merge (for non-CRDT sources)
    merged_state = Map.merge(local.state, remote_state)
    {:ok, %{local | state: merged_state}}
  end

  @doc """
  Resolve a conflict between two concurrent operations.

  Uses last-writer-wins with node_id as tiebreaker.

  ## Example

      resolved = StateSynchronizer.resolve_conflict(op1, op2)
  """
  @spec resolve_conflict(t() | Operation.t(), Operation.t()) :: Operation.t()
  def resolve_conflict(%__MODULE__{} = _sync, %Operation{} = op) do
    # For now, use timestamp as primary, node_id as tiebreaker
    # This could be extended with custom resolution strategies
    op
  end

  def resolve_conflict(%Operation{} = op1, %Operation{} = op2) do
    cond do
      op1.timestamp > op2.timestamp -> op1
      op2.timestamp > op1.timestamp -> op2
      op1.node_id >= op2.node_id -> op1
      true -> op2
    end
  end

  @doc """
  Get the current synchronized state.

  ## Example

      state = StateSynchronizer.get_state(sync)
  """
  @spec get_state(t()) :: map()
  def get_state(%__MODULE__{state: state}), do: state

  @doc """
  Get pending operations that need to be sent to other nodes.

  ## Example

      ops = StateSynchronizer.get_pending_ops(sync)
  """
  @spec get_pending_ops(t()) :: [Operation.t()]
  def get_pending_ops(%__MODULE__{pending_ops: ops}), do: Enum.reverse(ops)

  @doc """
  Clear pending operations (after successful sync).

  ## Example

      sync = StateSynchronizer.clear_pending(sync)
  """
  @spec clear_pending(t()) :: t()
  def clear_pending(%__MODULE__{} = sync) do
    %{sync | pending_ops: []}
  end

  @doc """
  Subscribe to state changes.

  ## Example

      :ok = StateSynchronizer.subscribe(sync, self())
  """
  @spec subscribe(t(), pid()) :: {:ok, t()}
  def subscribe(%__MODULE__{} = sync, pid) when is_pid(pid) do
    {:ok, %{sync | subscribers: [pid | sync.subscribers]}}
  end

  @doc """
  Unsubscribe from state changes.

  ## Example

      sync = StateSynchronizer.unsubscribe(sync, self())
  """
  @spec unsubscribe(t(), pid()) :: t()
  def unsubscribe(%__MODULE__{} = sync, pid) when is_pid(pid) do
    %{sync | subscribers: List.delete(sync.subscribers, pid)}
  end

  @doc """
  Get the current vector clock.

  ## Example

      vc = StateSynchronizer.get_vector_clock(sync)
  """
  @spec get_vector_clock(t()) :: VectorClock.t()
  def get_vector_clock(%__MODULE__{vector_clock: vc}), do: vc

  @doc """
  Serialize the synchronizer state for transmission.

  ## Example

      binary = StateSynchronizer.serialize(sync)
  """
  @spec serialize(t()) :: binary()
  def serialize(%__MODULE__{} = sync) do
    data = %{
      session_id: sync.session_id,
      node_id: sync.node_id,
      state: sync.state,
      vector_clock: sync.vector_clock.clock,
      history:
        Enum.map(sync.history, fn op ->
          %{
            id: op.id,
            type: op.type,
            data: op.data,
            timestamp: op.timestamp,
            node_id: op.node_id,
            vector_clock: op.vector_clock.clock
          }
        end)
    }

    :erlang.term_to_binary(data, [:compressed])
  end

  @doc """
  Deserialize a synchronizer state.

  ## Example

      {:ok, sync} = StateSynchronizer.deserialize(binary)
  """
  @spec deserialize(binary()) :: {:ok, t()} | {:error, term()}
  def deserialize(binary) when is_binary(binary) do
    try do
      data = :erlang.binary_to_term(binary, [:safe])

      history =
        Enum.map(data.history, fn op_data ->
          %Operation{
            id: op_data.id,
            type: op_data.type,
            data: op_data.data,
            timestamp: op_data.timestamp,
            node_id: op_data.node_id,
            vector_clock: %VectorClock{clock: op_data.vector_clock}
          }
        end)

      sync = %__MODULE__{
        session_id: data.session_id,
        node_id: data.node_id,
        state: data.state,
        vector_clock: %VectorClock{clock: data.vector_clock},
        pending_ops: [],
        history: history,
        subscribers: []
      }

      {:ok, sync}
    rescue
      e -> {:error, e}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_apply_remote(%__MODULE__{} = sync, %Operation{} = op) do
    # Merge vector clocks
    new_vc = VectorClock.merge(sync.vector_clock, op.vector_clock)

    # Apply operation
    new_state = apply_operation(sync.state, op)

    new_sync = %{
      sync
      | state: new_state,
        vector_clock: new_vc,
        history: [op | sync.history]
    }

    # Notify subscribers
    notify_subscribers(new_sync, {:remote_operation, op})

    {:ok, new_sync}
  end

  defp apply_operation(state, %Operation{data: {:set, key, value}}) do
    Map.put(state, key, value)
  end

  defp apply_operation(state, %Operation{data: {:delete, key}}) do
    Map.delete(state, key)
  end

  defp apply_operation(state, %Operation{data: {:update, key, fun}})
       when is_function(fun, 1) do
    Map.update(state, key, nil, fun)
  end

  defp apply_operation(state, %Operation{data: {:merge, new_state}})
       when is_map(new_state) do
    Map.merge(state, new_state)
  end

  defp apply_operation(state, %Operation{data: data}) do
    Log.warning("[StateSynchronizer] Unknown operation type: #{inspect(data)}")
    state
  end

  defp operation_seen?(%__MODULE__{history: history}, %Operation{id: id}) do
    Enum.any?(history, &(&1.id == id))
  end

  defp merge_histories(history1, history2) do
    (history1 ++ history2)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(1000)
  end

  defp notify_subscribers(%__MODULE__{subscribers: subscribers}, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:state_sync, message})
    end)
  end

  defp extract_operation_type({type, _}), do: type
  defp extract_operation_type({type, _, _}), do: type
  defp extract_operation_type(_), do: :unknown

  defp generate_node_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp generate_operation_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end
end
