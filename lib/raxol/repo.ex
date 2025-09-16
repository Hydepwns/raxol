defmodule Raxol.Repo do
  @moduledoc """
  Repository module for Raxol.
  Currently a stub as Raxol doesn't use Ecto database operations.
  """

  @doc """
  Checkout a database connection for testing.
  This is a stub implementation.
  """
  def checkout(_func) do
    {:ok, :no_op}
  end
end
