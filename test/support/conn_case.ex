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
    :ok = Raxol.DataCase.setup(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Session.call(
        Plug.Session.init(
          store: :cookie,
          key: "_raxol_key",
          signing_salt: "raxol_salt",
          secret_key_base: String.duplicate("a", 64)
        )
      )
      |> fetch_session()

    {:ok, conn: conn}
  end

  @doc """
  Setup helper functions for tests that interact with the DB
  """
  def setup_sandbox(_tags) do
    # For MockDB, we don't need sandbox checkout
    # :ok = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)
    #
    # if !tags[:async] do
    #   Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, {:shared, self()})
    # end
    :ok
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
    # Skip database operations when database is disabled
    case Application.get_env(:raxol, :database_enabled, true) do
      true -> ensure_test_user_exists()
      false -> :ok
    end

    setup_user_session(conn, user)
  end

  defp ensure_test_user_exists do
    # Check if Accounts process is running
    case Process.whereis(Raxol.Accounts) do
      nil ->
        # If Accounts isn't running, skip user creation
        :ok

      _pid ->
        case Raxol.Accounts.get_user("user") do
          {:error, :not_found} -> create_test_user()
          {:error, _} -> create_test_user()
          {:ok, _user} -> :ok
        end
    end
  end

  defp create_test_user do
    case Raxol.Accounts.register_user(%{
           email: "test@example.com",
           password: "password123"
         }) do
      {:ok, _reg_user} -> update_user_id()
      {:error, %{email: "has already been taken"}} -> :ok
      error -> error
    end
  end

  defp update_user_id do
    Agent.update(Raxol.Accounts, fn users ->
      Map.new(users, &update_user_id_mapper/1)
    end)
  end

  defp update_user_id_mapper({"test@example.com", user}),
    do: {"test@example.com", Map.put(user, :id, "user")}

  defp update_user_id_mapper({email, user}), do: {email, user}

  defp setup_user_session(conn, user) do
    session_id = "session_user"
    session_token = "placeholder_id_user"

    # Ensure ETS table exists
    case :ets.info(:session_storage) do
      :undefined ->
        :ets.new(:session_storage, [:named_table, :set, :public])

      _ ->
        :ok
    end

    # For tests, we'll bypass the database session creation and just set up the session
    # This avoids the database schema mismatch issue
    mock_session = %Raxol.Web.Session.Session{
      id: session_id,
      user_id: "user",
      status: :active,
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now(),
      metadata: %{token: session_token},
      token: session_token
    }

    # Store directly in ETS to avoid database issues
    :ets.insert(:session_storage, {session_id, mock_session})

    # Verify the session was stored
    case :ets.lookup(:session_storage, session_id) do
      [{^session_id, stored_session}] ->
        IO.puts("Session stored successfully: #{inspect(stored_session.id)}")

      [] ->
        IO.puts("Failed to store session in ETS")
    end

    build_authenticated_conn(conn, session_token, session_id, user)
  end

  defp build_authenticated_conn(conn, session_token, session_id, user) do
    conn
    |> fetch_session()
    |> put_session(:user_token, session_token)
    |> put_session(:user_session_id, session_id)
    |> assign(:current_user, user)
  end
end
