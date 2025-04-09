defmodule Raxol.Accounts do
  @moduledoc """
  The Accounts context.
  Manages user accounts and registration.
  (Currently uses an in-memory Agent for storage)
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Returns the list of registered users.
  """
  def list_users do
    Agent.get(__MODULE__, &(&1))
  end

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:ok, %{id: ..., email: "user@example.com"}}

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:error, %{email: "has already been taken"}}

  """
  def register_user(attrs) do
    email = attrs[:email]

    Agent.update(__MODULE__, fn users ->
      if Map.has_key?(users, email) do
        {:error, %{email: "has already been taken"}, users}
      else
        user_id = Ecto.UUID.generate()
        # In a real app, hash the password here
        new_user = %{id: user_id, email: email, password_hash: attrs[:password]}
        {:ok, new_user, Map.put(users, email, new_user)}
      end
    end)
    |> case do
      {:ok, user, _users} -> {:ok, Map.take(user, [:id, :email])}
      {:error, changeset, _users} -> {:error, changeset}
    end
  end

  # Placeholder User struct if needed, otherwise remove
  # defmodule User do
  #   defstruct [:id, :email, :password_hash]
  # end
end
