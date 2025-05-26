defmodule Raxol.Core.Runtime.Debug do
  @moduledoc """
  Simple logging wrapper for the runtime.
  """

  require Raxol.Core.Runtime.Log

  def debug(message), do: Raxol.Core.Runtime.Log.debug(message)
  def info(message), do: Raxol.Core.Runtime.Log.info(message)
  def warn(message), do: Raxol.Core.Runtime.Log.warn_with_stacktrace(message, nil, nil, %{module: __MODULE__})
  def error(message), do: Raxol.Core.Runtime.Log.error_with_stacktrace(message, nil, nil, %{module: __MODULE__})
end
