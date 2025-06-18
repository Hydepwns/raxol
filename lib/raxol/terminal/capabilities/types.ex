defmodule Raxol.Terminal.Capabilities.Types do
  @moduledoc """
  Defines types and structures for terminal capabilities management.
  """

  @type capability :: atom()
  @type capability_value :: term()
  @type capability_map :: %{capability() => capability_value()}
  @type capability_query :: {capability(), capability_value()}
  @type capability_response :: {:ok, capability_value()} | {:error, term()}

  @type t :: %__MODULE__{
          supported: capability_map(),
          enabled: capability_map(),
          cached: capability_map()
        }

  defstruct supported: %{},
            enabled: %{},
            cached: %{}
end
