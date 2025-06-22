defmodule Raxol.Accounts do
  @moduledoc """
  Manages user accounts and authentication.
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
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:ok, %{id: ..., email: "user@example.com"}}

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:error, %{email: "has already been taken"}}

  """
  @spec register_user(map()) :: {:ok, map()} | {:error, map()}
  def register_user(attrs) do
    # Handle both atom and string keys for email
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    password = Map.get(attrs, :password) || Map.get(attrs, "password")

    Agent.get_and_update(__MODULE__, fn users ->
      if Map.has_key?(users, email) do
        {{:error, %{email: "has already been taken"}}, users}
      else
        user_id = Ecto.UUID.generate()
        # In a real app, hash the password here
        new_user = %{id: user_id, email: email, password_hash: password}

        {{:ok, Map.take(new_user, [:id, :email])},
         Map.put(users, email, new_user)}
      end
    end)
  end

  @doc """
  Authenticates a user by email and password.

  Currently checks against plaintext passwords stored in the agent.
  In a real app, this should use password hashing.
  """
  @spec authenticate_user(String.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_credentials}
  def authenticate_user(email, password) do
    Agent.get(__MODULE__, fn users ->
      case Map.get(users, email) do
        nil ->
          {:error, :invalid_credentials}

        user when user.password_hash == password ->
          # Return only public user info on success
          {:ok, Map.take(user, [:id, :email])}

        _ ->
          {:error, :invalid_credentials}
      end
    end)
  end

  @doc """
  Retrieves the full user map by user ID.
  Note: Inefficient O(N) scan of the agent state.
  """
  @spec get_user(String.t()) :: map() | nil
  def get_user(user_id) do
    Agent.get(__MODULE__, fn users ->
      Enum.find_value(users, fn {_email, user} ->
        if user.id == user_id, do: user, else: nil
      end)
    end)
  end

  @doc """
  Updates a user's password after verifying the current password.
  Uses user_id to find the user.
  """
  @spec update_password(String.t(), String.t(), String.t()) ::
          :ok | {:error, atom() | map()}
  def update_password(user_id, current_password, new_password) do
    Agent.get_and_update(__MODULE__, fn users ->
      # Find user by ID first (inefficient)
      found_entry =
        Enum.find(users, fn {_email, user} -> user.id == user_id end)

      case found_entry do
        nil ->
          # User ID not found
          {{:error, :not_found}, users}

        {email, user} ->
          if user.password_hash == current_password do
            # In a real app, hash the new_password here
            updated_user = %{user | password_hash: new_password}
            updated_users = Map.put(users, email, updated_user)
            {{:ok}, updated_users}
          else
            # Current password mismatch
            # In a real app, return a changeset-like error
            {{:error, :invalid_current_password}, users}
          end
      end
    end)
  end

  defmodule User do
    defstruct [:id, :email, :password_hash]
  end
end
