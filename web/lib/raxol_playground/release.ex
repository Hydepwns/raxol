defmodule RaxolPlayground.Release do
  @moduledoc """
  Used for executing tasks in production releases.
  """

  @app :raxol_playground

  def migrate do
    # No database migrations needed for this app
    # This is just a placeholder for the release command
    IO.puts("No migrations to run for Raxol Playground")
    :ok
  end

  def rollback(version) do
    # No database to rollback
    IO.puts("No rollback available for Raxol Playground")
    :ok
  end
end