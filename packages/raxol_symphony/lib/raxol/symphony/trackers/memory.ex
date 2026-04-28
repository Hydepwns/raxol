defmodule Raxol.Symphony.Trackers.Memory do
  @moduledoc """
  In-memory tracker for tests and local development.

  Implements `Raxol.Symphony.Tracker` against an `Agent` process that holds
  issues keyed by ID. Tests can seed issues with `put_issue/2`, transition
  states with `transition/3`, and remove issues with `remove_issue/2`.

  Multiple tracker instances can coexist by passing distinct `:name` values
  to `start_link/1`. The default registered name is the module itself.
  """

  @behaviour Raxol.Symphony.Tracker

  alias Raxol.Symphony.{Config, Issue}

  # -- Lifecycle --------------------------------------------------------------

  @doc false
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Starts a Memory tracker instance.

  Options:

  - `:name` -- registered name for the Agent (default `__MODULE__`).
  - `:issues` -- initial issues, either as a list of `Issue.t()` or a map
    keyed by ID.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    initial = normalize_initial(Keyword.get(opts, :issues, %{}))

    Agent.start_link(fn -> initial end, name: name)
  end

  @doc """
  Adds or replaces an issue in the tracker.
  """
  @spec put_issue(GenServer.server(), Issue.t()) :: :ok
  def put_issue(server \\ __MODULE__, %Issue{id: id} = issue) do
    Agent.update(server, &Map.put(&1, id, issue))
  end

  @doc """
  Adds many issues at once. Existing IDs are replaced.
  """
  @spec put_issues(GenServer.server(), [Issue.t()]) :: :ok
  def put_issues(server \\ __MODULE__, issues) when is_list(issues) do
    Agent.update(server, fn store ->
      Enum.reduce(issues, store, fn %Issue{id: id} = issue, acc ->
        Map.put(acc, id, issue)
      end)
    end)
  end

  @doc """
  Transitions an issue's state. No-op if the issue is missing.
  """
  @spec transition(GenServer.server(), binary(), binary()) :: :ok
  def transition(server \\ __MODULE__, id, new_state) do
    Agent.update(server, fn store ->
      case Map.get(store, id) do
        %Issue{} = issue -> Map.put(store, id, %Issue{issue | state: new_state})
        nil -> store
      end
    end)
  end

  @doc """
  Removes an issue.
  """
  @spec remove_issue(GenServer.server(), binary()) :: :ok
  def remove_issue(server \\ __MODULE__, id) do
    Agent.update(server, &Map.delete(&1, id))
  end

  @doc """
  Returns all issues currently in the store.
  """
  @spec all(GenServer.server()) :: [Issue.t()]
  def all(server \\ __MODULE__) do
    Agent.get(server, &Map.values/1)
  end

  # -- Tracker callbacks ------------------------------------------------------

  @impl Raxol.Symphony.Tracker
  def fetch_candidate_issues(%Config{tracker: %{active_states: states}} = config) do
    server = server_name(config)
    {:ok, fetch_by_states_impl(server, states)}
  end

  @impl Raxol.Symphony.Tracker
  def fetch_issues_by_states(%Config{} = config, state_names) when is_list(state_names) do
    server = server_name(config)
    {:ok, fetch_by_states_impl(server, state_names)}
  end

  @impl Raxol.Symphony.Tracker
  def fetch_issue_states_by_ids(%Config{} = config, ids) when is_list(ids) do
    server = server_name(config)
    issues = Agent.get(server, &lookup_ids(&1, ids))
    {:ok, issues}
  end

  defp lookup_ids(store, ids) do
    ids
    |> Enum.map(&Map.get(store, &1))
    |> Enum.reject(&is_nil/1)
  end

  # -- Internals --------------------------------------------------------------

  defp normalize_initial(%{} = map), do: map

  defp normalize_initial(list) when is_list(list) do
    Enum.into(list, %{}, fn %Issue{id: id} = issue -> {id, issue} end)
  end

  defp fetch_by_states_impl(server, state_names) do
    needles = MapSet.new(state_names, &String.downcase/1)

    Agent.get(server, fn store ->
      store
      |> Map.values()
      |> Enum.filter(fn issue ->
        MapSet.member?(needles, String.downcase(issue.state))
      end)
    end)
  end

  # The Memory tracker can be customised per-config by passing a registered
  # name through the runner extension. For now we always use the module-level
  # default name (overridden in tests by starting the Agent under that name).
  defp server_name(_config), do: __MODULE__
end
