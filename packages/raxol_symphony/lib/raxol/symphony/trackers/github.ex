defmodule Raxol.Symphony.Trackers.GitHub do
  @moduledoc """
  GitHub Issues tracker adapter.

  Stub: full implementation lands in Phase 6. Will use repo issues with
  state-name labels (`state/todo`, `state/in-progress`, `state/human-review`,
  etc.) since GitHub's native open/closed states are not granular enough for
  Symphony workflows.
  """

  @behaviour Raxol.Symphony.Tracker

  @impl true
  def fetch_candidate_issues(_config), do: {:error, :not_implemented}

  @impl true
  def fetch_issues_by_states(_config, _states), do: {:error, :not_implemented}

  @impl true
  def fetch_issue_states_by_ids(_config, _ids), do: {:error, :not_implemented}
end
