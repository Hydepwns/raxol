defmodule Raxol.Symphony.Orchestrator.Candidate do
  @moduledoc """
  Candidate selection rules.

  Implements SPEC s8.2 (Candidate Selection Rules):

  An issue is dispatch-eligible only when all are true:

  - Has `id`, `identifier`, `title`, and `state` (struct fields enforce this).
  - Its state is in `active_states` and not in `terminal_states`.
  - It is not already in `running` or `claimed`.
  - Global concurrency slots are available.
  - Per-state concurrency slots are available.
  - Blocker rule for `Todo`: when state is `Todo`, no blocker is non-terminal.

  Sort order (s8.2):

  1. `priority` ascending (1..4 preferred; nil/unknown last).
  2. `created_at` oldest first.
  3. `identifier` lexicographic tie-breaker.
  """

  alias Raxol.Symphony.{Config, Issue}

  @type running_map :: %{optional(binary()) => %{state: binary()}}

  @doc """
  Filters and sorts a list of issues into dispatch-ready order.

  - `issues` -- candidates fetched from the tracker.
  - `config` -- runtime config (provides active/terminal states, concurrency).
  - `running` -- map `issue_id -> %{state: state_name, ...}` of currently
    running entries, used for slot accounting.
  - `claimed` -- MapSet of currently-claimed issue IDs (running OR retrying).
  """
  @spec eligible(
          [Issue.t()],
          Config.t(),
          running_map(),
          MapSet.t(binary())
        ) :: [Issue.t()]
  def eligible(issues, %Config{} = config, running, claimed) do
    issues
    |> Enum.filter(&basic_eligibility(&1, config, running, claimed))
    |> sort()
    |> apply_concurrency_slots(config, running)
  end

  @doc """
  Sorts issues by dispatch priority (priority asc, created_at asc, identifier).
  """
  @spec sort([Issue.t()]) :: [Issue.t()]
  def sort(issues) do
    Enum.sort_by(issues, &sort_key/1)
  end

  @doc """
  Returns true when an issue passes basic eligibility (state, claim, blockers).
  Concurrency slots are applied separately by `apply_concurrency_slots/3`.
  """
  @spec basic_eligibility(Issue.t(), Config.t(), running_map(), MapSet.t(binary())) :: boolean()
  def basic_eligibility(%Issue{} = issue, %Config{} = config, running, claimed) do
    cond do
      Map.has_key?(running, issue.id) -> false
      MapSet.member?(claimed, issue.id) -> false
      not Issue.active?(issue, config.tracker.active_states) -> false
      Issue.terminal?(issue, config.tracker.terminal_states) -> false
      issue.state == "Todo" and todo_blocked?(issue, config) -> false
      true -> true
    end
  end

  @doc """
  Applies global + per-state concurrency caps to an already-sorted list.

  Returns issues that fit within remaining slots, in dispatch order.
  """
  @spec apply_concurrency_slots([Issue.t()], Config.t(), running_map()) :: [Issue.t()]
  def apply_concurrency_slots(issues, %Config{} = config, running) do
    state_counts = count_running_by_state(running)
    global_slots = max(config.agent.max_concurrent_agents - map_size(running), 0)
    initial = {[], state_counts, global_slots}

    {kept, _, _} = Enum.reduce(issues, initial, &take_if_slots_available(&1, &2, config))

    Enum.reverse(kept)
  end

  defp take_if_slots_available(_issue, {acc, counts, slots}, _config) when slots <= 0 do
    {acc, counts, slots}
  end

  defp take_if_slots_available(issue, {acc, counts, slots}, config) do
    if per_state_slots(issue, config, counts) <= 0 do
      {acc, counts, slots}
    else
      new_counts = Map.update(counts, normalize_state(issue.state), 1, &(&1 + 1))
      {[issue | acc], new_counts, slots - 1}
    end
  end

  # -- Internals --------------------------------------------------------------

  defp sort_key(%Issue{priority: priority, created_at: created_at, identifier: identifier}) do
    # Nil priority sorts last; nil created_at sorts last among same priority.
    {priority_rank(priority), created_at_rank(created_at), identifier}
  end

  defp priority_rank(nil), do: {1, nil}
  defp priority_rank(p) when is_integer(p), do: {0, p}
  defp priority_rank(_), do: {1, nil}

  defp created_at_rank(nil), do: {1, nil}
  defp created_at_rank(%DateTime{} = dt), do: {0, DateTime.to_unix(dt, :microsecond)}
  defp created_at_rank(_), do: {1, nil}

  defp todo_blocked?(%Issue{blocked_by: blockers}, %Config{tracker: %{terminal_states: terminal}}) do
    needles = MapSet.new(terminal, &String.downcase/1)

    Enum.any?(blockers, fn
      %{state: nil} -> true
      %{state: state} -> not MapSet.member?(needles, String.downcase(state))
      _ -> false
    end)
  end

  defp count_running_by_state(running) do
    Enum.reduce(running, %{}, fn {_id, entry}, acc ->
      state_key = entry |> Map.get(:state, "") |> normalize_state()
      Map.update(acc, state_key, 1, &(&1 + 1))
    end)
  end

  defp per_state_slots(issue, config, counts) do
    state_key = normalize_state(issue.state)
    state_max = Map.get(config.agent.max_concurrent_agents_by_state, state_key)
    current = Map.get(counts, state_key, 0)

    case state_max do
      nil -> config.agent.max_concurrent_agents - current
      n when is_integer(n) -> n - current
    end
  end

  defp normalize_state(s) when is_binary(s), do: String.downcase(s)
  defp normalize_state(_), do: ""
end
