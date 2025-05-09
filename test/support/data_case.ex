defmodule Raxol.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application\'s data layer.

  It assumes the Ecto Sandbox owner process is already running
  (likely started implicitly via Repo config `pool: Ecto.Adapters.SQL.Sandbox`)
  and handles checking out connections and setting the mode.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Raxol.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      # import Raxol.DataCase # No specific helper functions needed here yet
    end
  end

  setup tags do
    # Checkout a sandbox connection for this test process
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)

    unless tags[:async] do
      # If running synchronously, allow sharing the connection.
      # Async tests require explicit checkouts and handle their connections separately.
      Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, {:shared, self()})
    end

    :ok
  end
end
