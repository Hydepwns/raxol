defmodule Raxol.Core.Runtime.Debug do
  @moduledoc """
  Simple logging wrapper for the runtime.
  """

  require Logger

  def debug(message), do: Logger.debug(message)
  def info(message), do: Logger.info(message)
  def warn(message), do: Logger.warning(message) # Use warning/1
  def error(message), do: Logger.error(message)
end
