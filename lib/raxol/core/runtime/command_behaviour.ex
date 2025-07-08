defmodule Raxol.Core.Runtime.CommandBehaviour do
  @moduledoc """
  Behaviour for command execution modules.

  This allows the dispatcher to accept different command execution implementations,
  enabling better testing through dependency injection.
  """

  @callback execute(Raxol.Core.Runtime.Command.t(), map()) ::
              :ok | {:error, term()}
end
