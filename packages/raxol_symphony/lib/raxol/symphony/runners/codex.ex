defmodule Raxol.Symphony.Runners.Codex do
  @moduledoc """
  Codex app-server runner.

  Stub: full implementation in Phase 13. Will Port-spawn `codex app-server`
  inside the workspace and translate its stdio JSON-RPC messages into runner
  events.
  """

  @behaviour Raxol.Symphony.Runner

  @impl true
  def run(_issue, _config, _opts), do: {:error, :not_implemented}
end
