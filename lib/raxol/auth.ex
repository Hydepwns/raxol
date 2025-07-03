defmodule Raxol.Auth do
  @moduledoc """
  Authentication module for handling user authentication and authorization.

  This module provides functionality for:
  - User authentication
  - Token generation and validation
  - Role-based access control
  - Session management
  - Permission checking
  """

  alias Raxol.Accounts
  alias Raxol.Auth.{Session, User, Role}
  alias Raxol.Database
  alias Raxol.Repo

  require Raxol.Core.Runtime.Log

  @doc """
  Validates a session token and returns the associated user ID.
  """
  def validate_token(session_id, token) do
    Session.validate_session(session_id, token)
  end

  @doc """
  Checks if a user has the required role.

  ## Parameters

  - `user_id` - The user ID to check
  - `required_role` - The role name (atom or string) to check for

  ## Returns

  - `true` - User has the required role
  - `false` - User does not have the required role

  ## Examples

      iex> has_role?("user123", :admin)
      false

      iex> has_role?("admin123", :admin)
      true
  """
  def has_role?(user_id, required_role) when is_binary(user_id) do
    case get_user_with_role(user_id) do
      {:ok, user} ->
        role_name = get_role_name(user.role)
        required_role_name = normalize_role(required_role)
        role_name == required_role_name

      {:error, _reason} ->
        false
    end
  end

  def has_role?(_user_id, _required_role), do: false

  @doc """
  Creates a new session for an authenticated user.
  """
  @spec create_user_session(String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def create_user_session(user_id, metadata \\ %{}) do
    Raxol.Core.Runtime.Log.debug("Creating session for user ID: #{user_id}")

    case Session.create_session(user_id, metadata) do
      {:ok, session_data} ->
        Raxol.Core.Runtime.Log.debug(
          "Session created successfully: #{session_data.session_id}"
        )

        {:ok, session_data}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to create session: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Cleans up a user session.
  """
  @spec cleanup_user_session(String.t()) :: :ok | {:error, term()}
  def cleanup_user_session(session_id) do
    Raxol.Core.Runtime.Log.debug("Cleaning up session: #{session_id}")
    Session.cleanup_session(session_id)
  end

  @doc """
  Retrieves user information by ID.

  ## Parameters

  - `user_id` - The user ID to retrieve

  ## Returns

  - `{:ok, user}` - User found with full information
  - `{:error, :not_found}` - User not found
  - `{:error, reason}` - Database error

  ## Examples

      iex> get_user("user123")
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> get_user("nonexistent")
      {:error, :not_found}
  """
  def get_user(user_id) when is_binary(user_id) do
    case Database.get(User, user_id) do
      {:ok, user} ->
        # Preload associations for complete user data
        user_with_associations = Repo.preload(user, [:role, :permissions])
        {:ok, user_with_associations}

      {:error, :not_found} ->
        # Fallback to Accounts for backward compatibility
        case Accounts.get_user(user_id) do
          nil -> {:error, :not_found}
          user -> {:ok, user}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Database error retrieving user #{user_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def get_user(_user_id), do: {:error, :invalid_user_id}

  @doc """
  Checks if a user has permission for a specific action.

  ## Parameters

  - `user` - The user struct or user ID
  - `module` - The module name (atom or string) to check permissions for
  - `action` - The action name (atom or string) to check permissions for

  ## Returns

  - `true` - User has permission
  - `false` - User does not have permission

  ## Examples

      iex> has_permission?(user, :dashboard, :read)
      true

      iex> has_permission?(user, :admin, :delete)
      false
  """
  def has_permission?(user, module, action) when is_map(user) do
    check_user_permissions(user, module, action)
  end

  def has_permission?(user_id, module, action) when is_binary(user_id) do
    case get_user(user_id) do
      {:ok, user} -> check_user_permissions(user, module, action)
      {:error, _reason} -> false
    end
  end

  def has_permission?(_user, _module, _action), do: false

  @doc """
  Retrieves a user by their session ID.

  ## Parameters

  - `session_id` - The session identifier

  ## Returns

  - `{:ok, user}` - User found
  - `{:error, :not_found}` - Session or user not found
  - `{:error, reason}` - Other error

  ## Examples

      iex> get_user_by_session("session123")
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> get_user_by_session("invalid")
      {:error, :not_found}
  """
  def get_user_by_session(session_id) when is_binary(session_id) do
    case Session.get_session(session_id) do
      {:ok, session} ->
        get_user(session.user_id)

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error("Session error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_user_by_session(_session_id), do: {:error, :invalid_session_id}

  @doc """
  Authenticates a user with email and password.

  ## Parameters

  - `email` - User's email address
  - `password` - User's password

  ## Returns

  - `{:ok, user}` - Authentication successful
  - `{:error, :invalid_credentials}` - Invalid email or password
  - `{:error, :user_locked}` - User account is locked
  - `{:error, :user_inactive}` - User account is inactive
  - `{:error, reason}` - Other error

  ## Examples

      iex> authenticate_user("user@example.com", "password123")
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> authenticate_user("user@example.com", "wrong_password")
      {:error, :invalid_credentials}
  """
  def authenticate_user(email, password)
      when is_binary(email) and is_binary(password) do
    case find_user_by_email(email) do
      {:ok, user} ->
        authenticate_user_password(user, password)

      {:error, :not_found} ->
        # Use Accounts as fallback for backward compatibility
        case Accounts.authenticate_user(email, password) do
          {:ok, user} -> {:ok, user}
          {:error, _reason} -> {:error, :invalid_credentials}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Database error during authentication: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def authenticate_user(_email, _password), do: {:error, :invalid_credentials}

  @doc """
  Registers a new user.

  ## Parameters

  - `attrs` - User attributes (email, username, password, etc.)

  ## Returns

  - `{:ok, user}` - User created successfully
  - `{:error, changeset}` - Validation errors
  - `{:error, reason}` - Other error

  ## Examples

      iex> register_user(%{email: "new@example.com", username: "newuser", password: "password123"})
      {:ok, %User{id: "user123", email: "new@example.com", ...}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{errors: [email: {"has invalid format", []}]}}
  """
  def register_user(attrs) do
    # Ensure we have a default role
    attrs = Map.put_new(attrs, :role_id, get_default_role_id())

    case Database.create(User, attrs) do
      {:ok, user} ->
        # Preload associations
        user_with_associations = Repo.preload(user, [:role, :permissions])
        {:ok, user_with_associations}

      {:error, changeset} ->
        {:error, changeset}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Database error creating user: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Updates a user's password.

  ## Parameters

  - `user_id` - The user ID
  - `current_password` - Current password for verification
  - `new_password` - New password

  ## Returns

  - `{:ok, user}` - Password updated successfully
  - `{:error, :invalid_current_password}` - Current password is incorrect
  - `{:error, :not_found}` - User not found
  - `{:error, changeset}` - Validation errors
  - `{:error, reason}` - Other error

  ## Examples

      iex> update_password("user123", "oldpass", "newpass123")
      {:ok, %User{id: "user123", ...}}

      iex> update_password("user123", "wrongpass", "newpass123")
      {:error, :invalid_current_password}
  """
  def update_password(user_id, current_password, new_password)
      when is_binary(user_id) do
    case get_user(user_id) do
      {:ok, user} ->
        if verify_password(current_password, user.password_hash) do
          update_user_password(user, new_password)
        else
          {:error, :invalid_current_password}
        end

      {:error, :not_found} ->
        # Fallback to Accounts for backward compatibility
        case Accounts.update_password(user_id, current_password, new_password) do
          :ok -> {:ok, %{id: user_id}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_password(_user_id, _current_password, _new_password),
    do: {:error, :invalid_user_id}

  # Private functions

  defp get_user_with_role(user_id) do
    case get_user(user_id) do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_role_name(%Role{name: name}), do: normalize_role(name)
  defp get_role_name(_), do: nil

  defp normalize_role(role) when is_atom(role), do: Atom.to_string(role)
  defp normalize_role(role) when is_binary(role), do: role
  defp normalize_role(_), do: nil

  defp check_user_permissions(user, module, action) do
    # Check if user has admin role (admin has all permissions)
    if has_admin_role?(user) do
      true
    else
      # Check specific permissions
      module_str = to_string(module)
      action_str = to_string(action)

      user.permissions
      |> Enum.any?(fn permission ->
        permission.module == module_str && permission.action == action_str
      end)
    end
  end

  defp has_admin_role?(user) do
    case user.role do
      %Role{name: "admin"} -> true
      _ -> false
    end
  end

  defp find_user_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> {:error, :not_found}
      user -> {:ok, Repo.preload(user, [:role, :permissions])}
    end
  end

  defp authenticate_user_password(user, password) do
    cond do
      not user.active ->
        {:error, :user_inactive}

      user.locked_until &&
          DateTime.compare(user.locked_until, DateTime.utc_now()) == :gt ->
        {:error, :user_locked}

      verify_password(password, user.password_hash) ->
        # Update last login and reset failed attempts
        update_user_login_success(user)

      true ->
        # Increment failed login attempts
        update_user_login_failure(user)
        {:error, :invalid_credentials}
    end
  end

  defp verify_password(password, password_hash) do
    # Use Bcrypt for password verification
    Bcrypt.verify_pass(password, password_hash)
  rescue
    _ -> false
  end

  defp update_user_login_success(user) do
    attrs = %{
      last_login: DateTime.utc_now(),
      failed_login_attempts: 0,
      locked_until: nil
    }

    case Database.update(User, user, attrs) do
      {:ok, updated_user} ->
        {:ok, Repo.preload(updated_user, [:role, :permissions])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_user_login_failure(user) do
    failed_attempts = (user.failed_login_attempts || 0) + 1

    locked_until =
      if failed_attempts >= 5,
        do: DateTime.add(DateTime.utc_now(), 900, :second),
        else: nil

    attrs = %{
      failed_login_attempts: failed_attempts,
      locked_until: locked_until
    }

    case Database.update(User, user, attrs) do
      {:ok, _updated_user} -> :ok
      # Don't fail authentication due to update error
      {:error, _reason} -> :ok
    end
  end

  defp update_user_password(user, new_password) do
    attrs = %{password: new_password}

    case Database.update(User, user, attrs) do
      {:ok, updated_user} ->
        {:ok, Repo.preload(updated_user, [:role, :permissions])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp get_default_role_id do
    # Get the default "user" role ID
    case Repo.get_by(Role, name: "user") do
      # Will be handled by the changeset
      nil -> nil
      role -> role.id
    end
  end
end
