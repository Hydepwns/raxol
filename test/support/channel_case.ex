defmodule RaxolWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  imports other functionality to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      use Phoenix.ChannelTest

      # The default endpoint for testing
      @endpoint RaxolWeb.Endpoint

      alias Raxol.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup tags do
    # Ensure Endpoint is started for channel tests
    # PubSub should be started by the application tree now
    # start_supervised!({Phoenix.PubSub, name: Raxol.PubSub}) # Removed
    start_supervised!(RaxolWeb.Endpoint)

    # Setup Ecto sandbox
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)

    if !tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, {:shared, self()})
    end

    :ok
  end
end
