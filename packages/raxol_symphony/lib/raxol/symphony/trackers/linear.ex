defmodule Raxol.Symphony.Trackers.Linear do
  @moduledoc """
  Linear tracker adapter.

  Stub: full GraphQL implementation lands in Phase 6. All callbacks currently
  return `{:error, :not_implemented}` so the dispatcher works end-to-end with
  the Memory tracker before Linear is wired up.
  """

  @behaviour Raxol.Symphony.Tracker

  @impl true
  def fetch_candidate_issues(_config), do: {:error, :not_implemented}

  @impl true
  def fetch_issues_by_states(_config, _states), do: {:error, :not_implemented}

  @impl true
  def fetch_issue_states_by_ids(_config, _ids), do: {:error, :not_implemented}
end
