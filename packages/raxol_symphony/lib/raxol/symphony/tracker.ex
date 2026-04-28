defmodule Raxol.Symphony.Tracker do
  @moduledoc """
  Tracker adapter behaviour and dispatcher.

  Implements SPEC s11.1 (REQUIRED Operations):

  1. `fetch_candidate_issues/1` -- issues in configured active states.
  2. `fetch_issues_by_states/2` -- issues in given states (used for startup
     terminal cleanup).
  3. `fetch_issue_states_by_ids/2` -- current state for given IDs (used for
     active-run reconciliation).

  Dispatching: callers invoke functions on this module; it routes to the
  configured implementation based on `config.tracker.kind`.

  Error categories (SPEC s11.4):

  - `:unsupported_tracker_kind`
  - `:missing_tracker_api_key`
  - `:missing_tracker_project_slug`
  - `{:linear_api_request, term}`
  - `{:linear_api_status, integer}`
  - `{:linear_graphql_errors, list}`
  - `:linear_unknown_payload`
  - `:linear_missing_end_cursor`
  """

  alias Raxol.Symphony.{Config, Issue}

  @type fetch_result :: {:ok, [Issue.t()]} | {:error, term()}

  @callback fetch_candidate_issues(Config.t()) :: fetch_result()
  @callback fetch_issues_by_states(Config.t(), [binary()]) :: fetch_result()
  @callback fetch_issue_states_by_ids(Config.t(), [binary()]) :: fetch_result()

  @doc """
  Fetches candidate issues (in `active_states`) for dispatch.
  """
  @spec fetch_candidate_issues(Config.t()) :: fetch_result()
  def fetch_candidate_issues(%Config{} = config) do
    with {:ok, impl} <- impl_for(config) do
      impl.fetch_candidate_issues(config)
    end
  end

  @doc """
  Fetches issues currently in any of `state_names`. Used for startup terminal
  workspace cleanup (SPEC s8.6).
  """
  @spec fetch_issues_by_states(Config.t(), [binary()]) :: fetch_result()
  def fetch_issues_by_states(%Config{} = config, state_names) when is_list(state_names) do
    with {:ok, impl} <- impl_for(config) do
      impl.fetch_issues_by_states(config, state_names)
    end
  end

  @doc """
  Refreshes current state for a list of issue IDs. Used for active-run
  reconciliation (SPEC s8.5).
  """
  @spec fetch_issue_states_by_ids(Config.t(), [binary()]) :: fetch_result()
  def fetch_issue_states_by_ids(%Config{} = config, issue_ids) when is_list(issue_ids) do
    with {:ok, impl} <- impl_for(config) do
      impl.fetch_issue_states_by_ids(config, issue_ids)
    end
  end

  # -- Internals --------------------------------------------------------------

  defp impl_for(%Config{tracker: %{kind: "memory"}}),
    do: {:ok, Raxol.Symphony.Trackers.Memory}

  defp impl_for(%Config{tracker: %{kind: "linear"}}),
    do: {:ok, Raxol.Symphony.Trackers.Linear}

  defp impl_for(%Config{tracker: %{kind: "github"}}),
    do: {:ok, Raxol.Symphony.Trackers.GitHub}

  defp impl_for(%Config{tracker: %{kind: kind}}),
    do: {:error, {:unsupported_tracker_kind, kind}}
end
