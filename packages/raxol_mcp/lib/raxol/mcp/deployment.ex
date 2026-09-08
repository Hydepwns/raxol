defmodule Raxol.MCP.Deployment do
  @moduledoc """
  Fail-closed environment gate for MCP authorization.

  Mirrors the posture the payments stack uses (`require_policy`): outside a
  dev/test build, a network-exposed MCP transport must not serve tools without an
  authorizer configured. stdio is exempt (it inherits the OS process boundary);
  this guards SSE.
  """

  @doc """
  True in any non-dev/test build.

  Read at RUNTIME, deliberately not captured at compile time. This module
  compiles as a dependency, and a path dependency compiles under :prod whatever
  the umbrella's environment is, so a compile-time capture answers for how
  raxol_mcp itself was built rather than for the application it protects. The two
  disagreed in exactly the case that matters: the same predicate was `false`
  under this package's own `mix test` and `true` inside a dev session of an
  application depending on it, so a dev session read as production.

  `Mix` being unusable is the signal for a release; a dev or test session has a
  RUNNING Mix and answers for that session. Called at transport boot rather
  than per request, so reaching the loader here costs nothing.

  Note this is no longer a compile-time constant, which the previous shape
  hoisted to a module attribute to avoid: inlined, `@mix_env not in [:dev, :test]`
  compared two atoms the type checker knew were disjoint and warned on every
  build. `Mix.env/0` is opaque to it, so the comparison is now an ordinary one.

  ## Loadable is not the same as started

  `Code.ensure_loaded?(Mix)` alone was wrong: it asks whether the MODULE is
  reachable, while `Mix.env/0` reads `:ets.lookup(Mix.State, :env)` and so
  needs the `:mix` APPLICATION to be running. Any node that has Elixir's
  standard lib on its code path but has not started `:mix` -- `elixir -e`, an
  escript, a release that ships `:mix` without starting it -- satisfies the
  guard and then raises `ArgumentError: the table identifier does not refer to
  an existing ETS table`. That is on `Raxol.Application.start/2`'s `:mcp` path,
  so the failure mode was a boot crash in exactly the deployment shape the
  `else` branch was written to answer for.

  Unusable Mix now resolves to `true` rather than raising, which is also the
  fail-closed direction: an environment this predicate cannot identify is
  treated as production.
  """
  @spec production?() :: boolean()
  def production? do
    case mix_env() do
      {:ok, env} -> env not in [:dev, :test]
      :unavailable -> true
    end
  end

  @spec mix_env() :: {:ok, atom()} | :unavailable
  defp mix_env do
    if Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) do
      {:ok, Mix.env()}
    else
      :unavailable
    end
  rescue
    # Mix is loaded but `:mix` is not running, so `Mix.State`'s ETS table does
    # not exist. Not an environment we can identify: treat it as production.
    ArgumentError -> :unavailable
  end

  @doc """
  Whether a network transport must refuse to expose tools without an authorizer.

  Defaults to `production?/0`; override with
  `config :raxol_mcp, require_authorization: boolean`.

  > #### This got looser in dev, deliberately {: .warning}
  >
  > `production?/0` used to be captured at compile time, which read `:prod` for
  > a path dependency whatever the umbrella's environment was. That made this
  > `true` inside a raxol DEV session, so SSE refused to boot there without an
  > authorizer. Reading the environment at runtime corrects the misreading and,
  > as a consequence, stops the gate biting in dev and test.
  >
  > That is the intended posture -- a dev session is not production and should
  > not be gated as one -- but it is a relaxation as well as a correction. A
  > dev or staging deployment that wants the production posture has to ask for
  > it: `config :raxol_mcp, require_authorization: true`.
  """
  @spec require_authorization?() :: boolean()
  def require_authorization? do
    Application.get_env(:raxol_mcp, :require_authorization, production?())
  end

  @doc """
  Fail-closed boot check. Raises when authorization is required in this
  environment but the fronted server has no authorizer configured; a no-op
  otherwise. `context` names the caller for the error message.
  """
  @spec enforce_authorization!(boolean(), String.t()) :: :ok
  def enforce_authorization!(authorizer_configured?, context \\ "MCP transport")

  def enforce_authorization!(true, _context), do: :ok

  def enforce_authorization!(false, context) do
    if require_authorization?() do
      raise ArgumentError,
            "#{context} refuses to boot: authorization is required in this environment " <>
              "but no authorizer is configured on the MCP server. Configure an :authorizer " <>
              "on Raxol.MCP.Server, or override with " <>
              "`config :raxol_mcp, require_authorization: false`."
    else
      :ok
    end
  end

  @doc """
  Fail-closed boot check for the READ seam. Raises when authorization is
  required in this environment but the fronted server has no
  `:read_authorizer`; a no-op otherwise. `context` names the caller.

  Separate from `enforce_authorization!/2` because the two seams are separately
  configured and a network deployment needs both. The tool gate is satisfied by
  naming `:mcp_authorizer` or `:mcp_allowed_tools`, neither of which says
  anything about reads -- and `resources/read` serves live model state,
  `completion/complete` enumerates live session ids. Satisfying the tool gate
  alone used to be enough to expose them.
  """
  @spec enforce_read_authorization!(boolean(), String.t()) :: :ok
  def enforce_read_authorization!(read_authorizer_configured?, context \\ "MCP transport")

  def enforce_read_authorization!(true, _context), do: :ok

  def enforce_read_authorization!(false, context) do
    if require_authorization?() do
      raise ArgumentError,
            "#{context} refuses to boot: authorization is required in this environment " <>
              "but no :read_authorizer is configured on the MCP server, so " <>
              "resources/read would serve live model state to any client that " <>
              "connects. Configure `config :raxol, :mcp_read_authorizer` (or " <>
              "`:mcp_allowed_read_methods`), pass :read_authorizer to " <>
              "Raxol.MCP.Server.start_link/1, or override with " <>
              "`config :raxol_mcp, require_authorization: false`."
    else
      :ok
    end
  end
end
