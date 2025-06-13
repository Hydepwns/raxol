defmodule Raxol.Terminal.Sync.Protocol do
  @moduledoc """
  Defines the synchronization protocol for terminal components.
  Handles message formats, versioning, and conflict resolution strategies.
  """

  # Types
  @type sync_message :: %{
    type: :sync | :ack | :conflict | :resolve,
    component_id: String.t(),
    component_type: :split | :window | :tab,
    state: term(),
    metadata: %{
      version: non_neg_integer(),
      timestamp: non_neg_integer(),
      source: String.t(),
      consistency: :strong | :eventual | :causal
    }
  }

  @type sync_result :: :ok | {:error, :conflict | :version_mismatch | :invalid_state}

  # Message Types
  @sync_type :sync
  @ack_type :ack
  @conflict_type :conflict
  @resolve_type :resolve

  # Protocol Functions
  def create_sync_message(component_id, component_type, state, opts \\ []) do
    %{
      type: @sync_type,
      component_id: component_id,
      component_type: component_type,
      state: state,
      metadata: %{
        version: System.monotonic_time(),
        timestamp: System.system_time(),
        source: Map.get(opts, :source, "unknown"),
        consistency: Map.get(opts, :consistency, get_default_consistency(component_type))
      }
    }
  end

  def create_ack_message(component_id, component_type, version) do
    %{
      type: @ack_type,
      component_id: component_id,
      component_type: component_type,
      metadata: %{
        version: version,
        timestamp: System.system_time()
      }
    }
  end

  def create_conflict_message(component_id, component_type, current_state, incoming_state) do
    %{
      type: @conflict_type,
      component_id: component_id,
      component_type: component_type,
      states: %{
        current: current_state,
        incoming: incoming_state
      },
      metadata: %{
        timestamp: System.system_time()
      }
    }
  end

  def create_resolve_message(component_id, component_type, resolved_state, version) do
    %{
      type: @resolve_type,
      component_id: component_id,
      component_type: component_type,
      state: resolved_state,
      metadata: %{
        version: version,
        timestamp: System.system_time()
      }
    }
  end

  # Protocol Handlers
  def handle_sync_message(message, current_state) do
    case validate_message(message) do
      :ok ->
        handle_valid_sync(message, current_state)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_ack_message(message, current_state) do
    case validate_message(message) do
      :ok ->
        handle_valid_ack(message, current_state)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_conflict_message(message, current_state) do
    case validate_message(message) do
      :ok ->
        handle_valid_conflict(message, current_state)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_resolve_message(message, current_state) do
    case validate_message(message) do
      :ok ->
        handle_valid_resolve(message, current_state)
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions
  defp validate_message(message) do
    cond do
      !is_map(message) -> {:error, :invalid_message}
      !Map.has_key?(message, :type) -> {:error, :missing_type}
      !Map.has_key?(message, :component_id) -> {:error, :missing_component_id}
      !Map.has_key?(message, :component_type) -> {:error, :missing_component_type}
      !Map.has_key?(message, :metadata) -> {:error, :missing_metadata}
      true -> :ok
    end
  end

  defp handle_valid_sync(message, current_state) do
    case resolve_conflict(message, current_state) do
      :accept ->
        {:ok, message.state, message.metadata.version}
      :reject ->
        {:error, :version_mismatch}
      :conflict ->
        {:error, :conflict}
    end
  end

  defp handle_valid_ack(message, current_state) do
    if message.metadata.version == current_state.metadata.version do
      :ok
    else
      {:error, :version_mismatch}
    end
  end

  defp handle_valid_conflict(message, _current_state) do
    case resolve_conflict(message.states.current, message.states.incoming) do
      :accept ->
        {:ok, message.states.incoming}
      :reject ->
        {:ok, message.states.current}
      :conflict ->
        {:error, :unresolved_conflict}
    end
  end

  defp handle_valid_resolve(message, current_state) do
    if message.metadata.version > current_state.metadata.version do
      {:ok, message.state}
    else
      {:error, :version_mismatch}
    end
  end

  defp resolve_conflict(message, current_state) do
    case {message.metadata.consistency, current_state.metadata.consistency} do
      {:strong, :strong} ->
        if message.metadata.version > current_state.metadata.version do
          :accept
        else
          :reject
        end
      {:strong, _} ->
        :accept
      {_, :strong} ->
        :reject
      _ ->
        if message.metadata.version > current_state.metadata.version do
          :accept
        else
          :conflict
        end
    end
  end

  defp get_default_consistency(:split), do: :strong
  defp get_default_consistency(:window), do: :strong
  defp get_default_consistency(:tab), do: :eventual
  defp get_default_consistency(_), do: :eventual
end
