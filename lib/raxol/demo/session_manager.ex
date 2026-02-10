defmodule Raxol.Demo.SessionManager do
  @moduledoc """
  GenServer managing demo terminal sessions.
  Enforces session limits and handles automatic cleanup.
  """

  use GenServer
  require Logger

  @default_max_sessions 1000
  @default_max_per_ip 10
  @default_timeout_ms 1_800_000
  @cleanup_interval_ms 60_000

  defstruct sessions: %{}, ip_counts: %{}

  @type session_id :: String.t()
  @type ip_address :: String.t()

  # Client API

  @doc """
  Starts the session manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new session for the given IP address.
  Returns {:ok, session_id} or {:error, reason}.
  """
  @spec create_session(ip_address()) :: {:ok, session_id()} | {:error, atom()}
  def create_session(ip_address) do
    GenServer.call(__MODULE__, {:create_session, ip_address})
  end

  @doc """
  Removes a session.
  """
  @spec remove_session(session_id()) :: :ok
  def remove_session(session_id) do
    GenServer.cast(__MODULE__, {:remove_session, session_id})
  end

  @doc """
  Refreshes session timeout (called on activity).
  """
  @spec touch_session(session_id()) :: :ok
  def touch_session(session_id) do
    GenServer.cast(__MODULE__, {:touch_session, session_id})
  end

  @doc """
  Returns current session count.
  """
  @spec session_count() :: non_neg_integer()
  def session_count do
    GenServer.call(__MODULE__, :session_count)
  end

  @doc """
  Returns session count for an IP.
  """
  @spec sessions_for_ip(ip_address()) :: non_neg_integer()
  def sessions_for_ip(ip_address) do
    GenServer.call(__MODULE__, {:sessions_for_ip, ip_address})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:create_session, ip_address}, _from, state) do
    max_sessions = config(:max_sessions, @default_max_sessions)
    max_per_ip = config(:max_sessions_per_ip, @default_max_per_ip)

    cond do
      map_size(state.sessions) >= max_sessions ->
        {:reply, {:error, :max_sessions_reached}, state}

      Map.get(state.ip_counts, ip_address, 0) >= max_per_ip ->
        {:reply, {:error, :max_sessions_per_ip_reached}, state}

      true ->
        session_id = generate_session_id()
        now = System.monotonic_time(:millisecond)

        session = %{
          id: session_id,
          ip_address: ip_address,
          created_at: now,
          last_activity: now
        }

        new_sessions = Map.put(state.sessions, session_id, session)
        new_ip_counts = Map.update(state.ip_counts, ip_address, 1, &(&1 + 1))

        Logger.debug("Demo session created: #{session_id} from #{ip_address}")

        {:reply, {:ok, session_id},
         %{state | sessions: new_sessions, ip_counts: new_ip_counts}}
    end
  end

  @impl true
  def handle_call(:session_count, _from, state) do
    {:reply, map_size(state.sessions), state}
  end

  @impl true
  def handle_call({:sessions_for_ip, ip_address}, _from, state) do
    {:reply, Map.get(state.ip_counts, ip_address, 0), state}
  end

  @impl true
  def handle_cast({:remove_session, session_id}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        new_sessions = Map.delete(state.sessions, session_id)

        new_ip_counts =
          Map.update(state.ip_counts, session.ip_address, 0, fn count ->
            max(0, count - 1)
          end)
          |> Map.reject(fn {_ip, count} -> count == 0 end)

        Logger.debug("Demo session removed: #{session_id}")
        {:noreply, %{state | sessions: new_sessions, ip_counts: new_ip_counts}}
    end
  end

  @impl true
  def handle_cast({:touch_session, session_id}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        now = System.monotonic_time(:millisecond)
        updated_session = %{session | last_activity: now}
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        {:noreply, %{state | sessions: new_sessions}}
    end
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    timeout_ms = config(:session_timeout_ms, @default_timeout_ms)
    now = System.monotonic_time(:millisecond)

    expired_sessions =
      state.sessions
      |> Enum.filter(fn {_id, session} ->
        now - session.last_activity > timeout_ms
      end)
      |> Enum.map(fn {id, _session} -> id end)

    new_state =
      Enum.reduce(expired_sessions, state, fn session_id, acc ->
        session = Map.get(acc.sessions, session_id)

        new_sessions = Map.delete(acc.sessions, session_id)

        new_ip_counts =
          if session do
            Map.update(acc.ip_counts, session.ip_address, 0, fn count ->
              max(0, count - 1)
            end)
            |> Map.reject(fn {_ip, count} -> count == 0 end)
          else
            acc.ip_counts
          end

        Logger.debug("Demo session expired: #{session_id}")
        %{acc | sessions: new_sessions, ip_counts: new_ip_counts}
      end)

    schedule_cleanup()
    {:noreply, new_state}
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
  end

  defp config(key, default) do
    Application.get_env(:raxol, :demo, [])
    |> Keyword.get(key, default)
  end
end
