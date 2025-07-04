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

  @type sync_result ::
          :ok | {:error, :conflict | :version_mismatch | :invalid_state}

  # Message Types
  @sync_type :sync
  @ack_type :ack
  @conflict_type :conflict
  @resolve_type :resolve

  # Protocol Functions
  def create_sync_message(component_id, component_type, state, opts \\ []) do
    # Convert keyword list to map if needed
    opts_map = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    %{
      type: @sync_type,
      component_id: component_id,
      component_type: component_type,
      state: state,
      metadata: %{
        version: Map.get(opts_map, :version, System.monotonic_time()),
        timestamp: System.system_time(),
        source: Map.get(opts_map, :source, "unknown"),
        consistency:
          Map.get(
            opts_map,
            :consistency,
            get_default_consistency(component_type)
          )
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

  def create_conflict_message(
        component_id,
        component_type,
        current_state,
        incoming_state
      ) do
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

  def create_resolve_message(
        component_id,
        component_type,
        resolved_state,
        version
      ) do
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
      !is_map(message) ->
        {:error, :invalid_message}

      !Map.has_key?(message, :type) ->
        {:error, :missing_type}

      !Map.has_key?(message, :component_id) ->
        {:error, :missing_component_id}

      !Map.has_key?(message, :component_type) ->
        {:error, :missing_component_type}

      !Map.has_key?(message, :metadata) ->
        {:error, :missing_metadata}

      true ->
        :ok
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

  defp handle_valid_conflict(message, current_state) do
    # Compare incoming state with current state
    case resolve_conflict(message.states.incoming, current_state) do
      :accept ->
        {:ok, message.states.incoming}

      :reject ->
        {:ok, current_state}

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
    # Extract metadata from both states, handling different formats
    message_metadata = extract_metadata(message)
    current_metadata = extract_metadata(current_state)

    case {message_metadata.consistency, current_metadata.consistency} do
      {:strong, :strong} ->
        if message_metadata.version > current_metadata.version do
          :accept
        else
          :reject
        end

      {:strong, _} ->
        :accept

      {_, :strong} ->
        :reject

      _ ->
        # Both eventual consistency
        if message_metadata.version > current_metadata.version do
          :accept
        else
          if message_metadata.version == current_metadata.version do
            :conflict
          else
            :reject
          end
        end
    end
  end

  defp extract_metadata(state) do
    cond do
      # If state has metadata field, use it, but ensure :consistency is present
      Map.has_key?(state, :metadata) ->
        meta = state.metadata

        %{
          version: Map.get(meta, :version, 0),
          consistency: Map.get(meta, :consistency, :eventual)
        }

      # If state has version field directly, create metadata
      Map.has_key?(state, :version) ->
        %{
          version: state.version,
          consistency: Map.get(state, :consistency, :eventual)
        }

      # Default metadata
      true ->
        %{
          version: 0,
          consistency: :eventual
        }
    end
  end

  defp get_default_consistency(:split), do: :strong
  defp get_default_consistency(:window), do: :strong
  defp get_default_consistency(:tab), do: :eventual
  defp get_default_consistency(_), do: :eventual
end
