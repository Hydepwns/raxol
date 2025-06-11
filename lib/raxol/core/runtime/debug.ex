defmodule Raxol.Core.Runtime.Debug do
  @moduledoc """
  Simple logging wrapper for the runtime.
  """

  @behaviour Raxol.Core.Runtime.Debug

  require Raxol.Core.Runtime.Log

  @impl true
  def debug(message), do: Raxol.Core.Runtime.Log.debug(message)

  @impl true
  def info(message), do: Raxol.Core.Runtime.Log.info(message)

  @impl true
  def warn(message),
    do: Raxol.Core.Runtime.Log.warning(message, %{module: __MODULE__})

  @impl true
  def error(message),
    do: Raxol.Core.Runtime.Log.error(message, %{module: __MODULE__})
end
