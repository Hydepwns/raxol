defmodule Raxol.Terminal.TerminalRegistry do
  @moduledoc """
  Registry for managing terminal instances.

  This module provides a centralized registry for all active terminal processes,
  enabling lookup, registration, and management of terminal instances across
  the system.
  """

  use GenServer
  require Logger

  alias Raxol.Architecture.EventSourcing.EventStore
  alias Raxol.Events.{TerminalCreatedEvent, TerminalClosedEvent}

  defstruct [
    :terminals,
    :user_terminals,
    :terminal_metadata,
    :monitors,
    :config
  ]

  @type terminal_id :: String.t()
  @type user_id :: String.t()
  @type terminal_process :: pid()

  ## Client API

  @doc """
  Starts the terminal registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a terminal process with the registry.
  """
  def register(registry \\ __MODULE__, terminal_id, process, metadata \\ %{}) do
    GenServer.call(registry, {:register, terminal_id, process, metadata})
  end

  @doc """
  Unregisters a terminal from the registry.
  """
  def unregister(registry \\ __MODULE__, terminal_id) do
    GenServer.call(registry, {:unregister, terminal_id})
  end

  @doc """
  Looks up a terminal process by ID.
  """
  def lookup(registry \\ __MODULE__, terminal_id) do
    GenServer.call(registry, {:lookup, terminal_id})
  end

  @doc """
  Checks if a terminal exists in the registry.
  """
  def exists?(registry \\ __MODULE__, terminal_id) do
    GenServer.call(registry, {:exists, terminal_id})
  end

  @doc """
  Lists all terminals for a specific user.
  """
  def list_user_terminals(registry \\ __MODULE__, user_id) do
    GenServer.call(registry, {:list_user_terminals, user_id})
  end

  @doc """
  Lists all active terminals.
  """
  def list_all_terminals(registry \\ __MODULE__) do
    GenServer.call(registry, :list_all_terminals)
  end

  @doc """
  Gets metadata for a specific terminal.
  """
  def get_metadata(registry \\ __MODULE__, terminal_id) do
    GenServer.call(registry, {:get_metadata, terminal_id})
  end

  @doc """
  Updates metadata for a terminal.
  """
  def update_metadata(registry \\ __MODULE__, terminal_id, metadata) do
    GenServer.call(registry, {:update_metadata, terminal_id, metadata})
  end

  @doc """
  Gets registry statistics.
  """
  def get_statistics(registry \\ __MODULE__) do
    GenServer.call(registry, :get_statistics)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(opts) do
    config = Keyword.get(opts, :config, %{})

    state = %__MODULE__{
      terminals: %{},
      user_terminals: %{},
      terminal_metadata: %{},
      monitors: %{},
      config: config
    }

    # Subscribe to terminal events (skip in test mode to avoid circular dependencies)
    unless Mix.env() == :test do
      EventStore.subscribe(self(),
        event_types: [TerminalCreatedEvent, TerminalClosedEvent]
      )
    end

    Logger.info("Terminal registry initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register, terminal_id, process, metadata}, _from, state) do
    case Map.get(state.terminals, terminal_id) do
      nil ->
        # Monitor the process
        monitor_ref = Process.monitor(process)

        # Update state
        new_terminals = Map.put(state.terminals, terminal_id, process)

        new_monitors =
          Map.put(state.monitors, process, {terminal_id, monitor_ref})

        new_metadata =
          Map.put(state.terminal_metadata, terminal_id, %{
            registered_at: System.system_time(:millisecond),
            process: process,
            metadata: metadata
          })

        # Update user terminals index
        user_id = Map.get(metadata, :user_id)

        new_user_terminals =
          if user_id do
            user_list = Map.get(state.user_terminals, user_id, [])
            Map.put(state.user_terminals, user_id, [terminal_id | user_list])
          else
            state.user_terminals
          end

        new_state = %{
          state
          | terminals: new_terminals,
            monitors: new_monitors,
            terminal_metadata: new_metadata,
            user_terminals: new_user_terminals
        }

        Logger.info(
          "Registered terminal #{terminal_id} with process #{inspect(process)}"
        )

        {:reply, :ok, new_state}

      _existing_process ->
        Logger.warning("Terminal #{terminal_id} already registered")
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl GenServer
  def handle_call({:unregister, terminal_id}, _from, state) do
    case Map.get(state.terminals, terminal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      process ->
        new_state = do_unregister_terminal(terminal_id, process, state)
        Logger.info("Unregistered terminal #{terminal_id}")
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:lookup, terminal_id}, _from, state) do
    case Map.get(state.terminals, terminal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      process -> {:reply, {:ok, process}, state}
    end
  end

  @impl GenServer
  def handle_call({:exists, terminal_id}, _from, state) do
    exists = Map.has_key?(state.terminals, terminal_id)
    {:reply, exists, state}
  end

  @impl GenServer
  def handle_call({:list_user_terminals, user_id}, _from, state) do
    terminal_ids = Map.get(state.user_terminals, user_id, [])

    terminals =
      Enum.map(terminal_ids, fn terminal_id ->
        %{
          terminal_id: terminal_id,
          process: Map.get(state.terminals, terminal_id),
          metadata:
            get_in(state.terminal_metadata, [terminal_id, :metadata]) || %{}
        }
      end)

    {:reply, terminals, state}
  end

  @impl GenServer
  def handle_call(:list_all_terminals, _from, state) do
    terminals =
      Enum.map(state.terminals, fn {terminal_id, process} ->
        %{
          terminal_id: terminal_id,
          process: process,
          metadata:
            get_in(state.terminal_metadata, [terminal_id, :metadata]) || %{}
        }
      end)

    {:reply, terminals, state}
  end

  @impl GenServer
  def handle_call({:get_metadata, terminal_id}, _from, state) do
    case get_in(state.terminal_metadata, [terminal_id]) do
      nil -> {:reply, {:error, :not_found}, state}
      metadata_info -> {:reply, {:ok, metadata_info}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_metadata, terminal_id, new_metadata}, _from, state) do
    case get_in(state.terminal_metadata, [terminal_id]) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing_info ->
        updated_info = %{
          existing_info
          | metadata: Map.merge(existing_info.metadata, new_metadata),
            updated_at: System.system_time(:millisecond)
        }

        new_terminal_metadata =
          Map.put(state.terminal_metadata, terminal_id, updated_info)

        new_state = %{state | terminal_metadata: new_terminal_metadata}

        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    stats = %{
      total_terminals: map_size(state.terminals),
      active_users: map_size(state.user_terminals),
      monitored_processes: map_size(state.monitors),
      memory_usage: get_memory_usage(state)
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Map.get(state.monitors, pid) do
      nil ->
        {:noreply, state}

      {terminal_id, _monitor_ref} ->
        Logger.warning(
          "Terminal process #{inspect(pid)} (#{terminal_id}) died: #{inspect(reason)}"
        )

        new_state = do_unregister_terminal(terminal_id, pid, state)
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:event_appended, _stream_name, event}, state) do
    case event.data do
      %TerminalCreatedEvent{} = created_event ->
        handle_terminal_created_event(created_event, state)

      %TerminalClosedEvent{} = closed_event ->
        handle_terminal_closed_event(closed_event, state)

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp do_unregister_terminal(terminal_id, process, state) do
    # Remove from monitors
    case Map.get(state.monitors, process) do
      {^terminal_id, monitor_ref} ->
        Process.demonitor(monitor_ref, [:flush])

      _ ->
        :ok
    end

    # Get user_id from metadata for cleanup
    user_id =
      get_in(state.terminal_metadata, [terminal_id, :metadata, :user_id])

    # Remove from all indexes
    new_terminals = Map.delete(state.terminals, terminal_id)
    new_monitors = Map.delete(state.monitors, process)
    new_terminal_metadata = Map.delete(state.terminal_metadata, terminal_id)

    new_user_terminals =
      if user_id do
        case Map.get(state.user_terminals, user_id) do
          nil ->
            state.user_terminals

          terminal_list ->
            updated_list = List.delete(terminal_list, terminal_id)

            if Enum.empty?(updated_list) do
              Map.delete(state.user_terminals, user_id)
            else
              Map.put(state.user_terminals, user_id, updated_list)
            end
        end
      else
        state.user_terminals
      end

    %{
      state
      | terminals: new_terminals,
        monitors: new_monitors,
        terminal_metadata: new_terminal_metadata,
        user_terminals: new_user_terminals
    }
  end

  defp handle_terminal_created_event(event, state) do
    # This event is fired when a terminal is created through the command system
    # We might want to update registry metadata or perform additional bookkeeping
    Logger.debug("Terminal created event received for #{event.terminal_id}")
    {:noreply, state}
  end

  defp handle_terminal_closed_event(event, state) do
    # This event is fired when a terminal is closed through the command system
    # The registry might still have the entry if the process hasn't died yet
    Logger.debug("Terminal closed event received for #{event.terminal_id}")

    case Map.get(state.terminals, event.terminal_id) do
      nil ->
        # Already cleaned up
        {:noreply, state}

      _process ->
        # Mark as closing in metadata but don't remove yet
        # The process monitor will handle the actual cleanup
        case get_in(state.terminal_metadata, [event.terminal_id]) do
          nil ->
            {:noreply, state}

          metadata_info ->
            updated_metadata = Map.put(metadata_info.metadata, :closing, true)
            updated_info = %{metadata_info | metadata: updated_metadata}

            new_terminal_metadata =
              Map.put(state.terminal_metadata, event.terminal_id, updated_info)

            new_state = %{state | terminal_metadata: new_terminal_metadata}

            {:noreply, new_state}
        end
    end
  end

  defp get_memory_usage(state) do
    %{
      terminals: :erlang.external_size(state.terminals),
      user_terminals: :erlang.external_size(state.user_terminals),
      terminal_metadata: :erlang.external_size(state.terminal_metadata),
      monitors: :erlang.external_size(state.monitors)
    }
  end
end
