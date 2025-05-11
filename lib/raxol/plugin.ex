defmodule Raxol.Plugin do
  @moduledoc """
  Defines the behavior for Raxol plugins.
  Plugins can extend the terminal's functionality by implementing this behavior.
  """

  @callback commands() :: list({String.t(), function(), map()})
  @callback init(map()) :: {:ok, map()} | {:error, term()}
  @callback handle_event(term(), map()) :: {:ok, map()} | {:error, term()}
  @callback cleanup(map()) :: :ok | {:error, term()}
end
