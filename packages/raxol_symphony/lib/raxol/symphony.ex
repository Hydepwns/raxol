defmodule Raxol.Symphony do
  @moduledoc """
  Entrypoint for the Symphony orchestrator.

  Symphony polls an issue tracker, claims candidate issues, isolates each in a
  per-issue workspace, and runs a coding-agent session inside that workspace
  until the work reaches a workflow-defined handoff state.

  This module exposes the public start function. The actual orchestration runs
  under `Raxol.Symphony.Supervisor`.

  ## Quick start

      {:ok, _pid} = Raxol.Symphony.start_link(workflow_path: "WORKFLOW.md")

  ## SPEC reference

  See [`SPEC.md`](https://github.com/openai/symphony/blob/main/SPEC.md) for the
  language-neutral specification this implementation conforms to.
  """

  @doc """
  Starts the Symphony supervision tree.

  Options:

  - `:workflow_path` (required) -- absolute or working-directory-relative path
    to a `WORKFLOW.md`.
  - `:name` -- registered name for the supervisor (default
    `Raxol.Symphony.Supervisor`).
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Raxol.Symphony.Supervisor.start_link(opts)
  end
end
