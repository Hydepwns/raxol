defmodule RaxolWeb.ChannelCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's channel layer.

  Such tests rely on `Phoenix.ChannelTest` and also
  imports other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RaxolWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import RaxolWeb.ChannelCase

      # The default endpoint for testing
      @endpoint RaxolWeb.Endpoint
    end
  end

  setup tags do
    # Use DataCase for database setup
    :ok = Raxol.DataCase.setup(tags)

    # Start the endpoint server for tests requiring it
    start_endpoint(tags)

    :ok
  end

  @doc """
  Starts the endpoint server for tests requiring it.
  """
  def start_endpoint(_) do
    # Start applications necessary for the endpoint
    Application.ensure_all_started(:phoenix)
    Application.ensure_all_started(:plug_cowboy)

    # Ensure Raxol.PubSub is started before the endpoint
    # This is required because the endpoint is configured to use Raxol.PubSub
    if !Process.whereis(Raxol.PubSub) do
      {:ok, _pid} =
        Supervisor.start_link([{Phoenix.PubSub, name: Raxol.PubSub}],
          strategy: :one_for_one
        )
    end

    # Start the endpoint itself
    RaxolWeb.Endpoint.start_link()
    :ok
  end
end
