defmodule Raxol.MCP.Test.Session do
  @moduledoc """
  Struct representing a test session for MCP testing.

  Holds references to the session ID, registry, and configuration.
  All mutable state lives in the Headless GenServer and Registry ETS tables.
  """

  @type t :: %__MODULE__{
          id: atom(),
          registry: GenServer.server(),
          registry_pid: pid(),
          module: module() | String.t(),
          settle_ms: non_neg_integer()
        }

  defstruct [:id, :registry, :registry_pid, :module, settle_ms: 100]
end
