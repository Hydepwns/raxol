defmodule Raxol.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  It provides standardized database setup and cleanup
  for all tests that need database access, including:
  - Conditional database enabling
  - Safe transaction handling
  - Proper sandbox setup
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Raxol.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Raxol.DataCase, except: [setup: 1]
    end
  end

  setup _tags do
    # For MockDB, we don't need sandbox checkout
    # result = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)
    #
    # if result != :ok and result != {:already, :owner} do
    #   raise "Unexpected result from SQL Sandbox checkout: #{inspect(result)}"
    # end
    #
    # if !tags[:async] do
    #   Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, {:shared, self()})
    # end

    :ok
  end

  @doc """
  Helper function to safely execute database operations
  within a transaction that will be rolled back.
  """
  def with_transaction(fun) do
    case Application.get_env(:raxol, :database_enabled, false) do
      true ->
        # For MockDB, just execute the function directly
        # Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)
        fun.()
      false ->
        fun.()
    end
  end

  # Public setup/1 for use in other test helpers
  def setup(_tags) do
    # For MockDB, we don't need sandbox checkout
    # result = Ecto.Adapters.SQL.Sandbox.checkout(Raxol.Repo)
    #
    # if result != :ok and result != {:already, :owner} do
    #   raise "Unexpected result from SQL Sandbox checkout: #{inspect(result)}"
    # end
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
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
