defmodule RaxolWeb.ConnCase do
  # Add import for Plug.Conn functions used in helpers
  import Plug.Conn

  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RaxolWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import RaxolWeb.ConnCase

      alias RaxolWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint RaxolWeb.Endpoint
    end
  end

  setup tags do
    # Use DataCase for database setup
    :ok = Raxol.DataCase.setup(tags)

    # Ensure Endpoint is started for LiveView tests
    start_endpoint(tags)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Starts the endpoint server for tests requiring it.
  """
  def start_endpoint(_) do
    # Start applications necessary for the endpoint
    Application.ensure_all_started(:phoenix)
    Application.ensure_all_started(:plug_cowboy)
    # If your endpoint relies on other applications, start them here

    # Start the endpoint itself
    RaxolWeb.Endpoint.start_link()
    :ok
  end

  @doc """
  Setup helper functions for tests that interact with the DB
  """
  def setup_sandbox(tags) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)

    if !tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, {:shared, self()})
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end

  @doc """
  Logs the given user into the connection for testing.
  Mimics the behaviour of RaxolWeb.UserAuth.log_in_user/2.
  """
  def log_in_user(conn, user) do
    session_token = "placeholder_id_#{user.id}"

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> put_session(:user_token, session_token)
  end
end
