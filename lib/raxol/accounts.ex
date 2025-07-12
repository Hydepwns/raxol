defmodule Raxol.Accounts do
  @moduledoc """
  Manages user accounts and authentication.

  This module provides a hybrid approach:
  - Primary: Database-backed authentication using Ecto schemas
  - Fallback: In-memory Agent storage for backward compatibility and testing

  ## Features

  - Secure password hashing with Bcrypt
  - Database persistence with Ecto
  - Role-based access control
  - Account lockout protection
  - Session management
  - Backward compatibility with existing Agent storage
  """

  use Agent

  alias Raxol.Auth.{User, Role}
  alias Raxol.Database
  alias Raxol.Repo

  require Raxol.Core.Runtime.Log

  # Configuration
  @max_failed_attempts 5
  # 15 minutes
  @lockout_duration_seconds 900
  @default_role_name "user"

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Returns the list of registered users.

  ## Returns

  - `{:ok, users}` - List of users from database
  - `{:error, reason}` - Database error
  - `%{}` - Fallback to Agent storage (for backward compatibility)

  ## Examples

      iex> list_users()
      {:ok, [%User{id: "user123", email: "user@example.com", ...}]}

      iex> list_users()
      %{"user@example.com" => %{id: "user123", email: "user@example.com"}}
  """
  def list_users do
    case database_enabled?() do
      true ->
        case Database.all(User) do
          {:ok, users} ->
            {:ok, users}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Database error listing users: #{inspect(reason)}"
            )

            # Fallback to Agent storage
            Agent.get(__MODULE__, & &1)
        end

      false ->
        # Use Agent storage when database is disabled
        Agent.get(__MODULE__, & &1)
    end
  end

  @doc """
  Registers a new user with secure password hashing.

  ## Parameters

  - `attrs` - User attributes (email, username, password, etc.)

  ## Returns

  - `{:ok, user}` - User created successfully
  - `{:error, changeset}` - Validation errors
  - `{:error, reason}` - Other error

  ## Examples

      iex> register_user(%{email: "user@example.com", username: "user", password: "password123"})
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{errors: [email: {"has invalid format", []}]}}
  """
  @spec register_user(map()) ::
          {:ok, map()} | {:error, map() | Ecto.Changeset.t()}
  def register_user(attrs) do
    case database_enabled?() do
      true ->
        register_user_database(attrs)

      false ->
        register_user_agent(attrs)
    end
  end

  @doc """
  Authenticates a user by email and password with secure verification.

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
  @spec authenticate_user(String.t(), String.t()) ::
          {:ok, map()}
          | {:error,
             :invalid_credentials | :user_locked | :user_inactive | term()}
  def authenticate_user(email, password)
      when is_binary(email) and is_binary(password) do
    case database_enabled?() do
      true ->
        authenticate_user_database(email, password)

      false ->
        authenticate_user_agent(email, password)
    end
  end

  def authenticate_user(_email, _password), do: {:error, :invalid_credentials}

  @doc """
  Retrieves a user by ID with efficient database lookup.

  ## Parameters

  - `user_id` - The user ID to retrieve

  ## Returns

  - `{:ok, user}` - User found with full information
  - `{:error, :not_found}` - User not found
  - `{:error, reason}` - Database error
  - `nil` - Fallback to Agent storage (for backward compatibility)

  ## Examples

      iex> get_user("user123")
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> get_user("nonexistent")
      {:error, :not_found}
  """
  @spec get_user(String.t()) ::
          {:ok, map()} | {:error, :not_found | term()} | nil
  def get_user(user_id) when is_binary(user_id) do
    case database_enabled?() do
      true ->
        case Database.get(User, user_id) do
          {:ok, user} ->
            # Preload associations for complete user data
            user_with_associations = Repo.preload(user, [:role, :permissions])
            {:ok, user_with_associations}

          {:error, :not_found} ->
            {:error, :not_found}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Database error retrieving user #{user_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      false ->
        # Use Agent storage when database is disabled
        Agent.get(__MODULE__, fn users ->
          Enum.find_value(users, fn {_email, user} ->
            if user.id == user_id, do: user, else: nil
          end)
        end)
    end
  end

  def get_user(_user_id), do: {:error, :invalid_user_id}

  @doc """
  Updates a user's password with secure hashing and current password verification.

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
  @spec update_password(String.t(), String.t(), String.t()) ::
          {:ok, map()}
          | {:error,
             :invalid_current_password
             | :not_found
             | Ecto.Changeset.t()
             | term()}
  def update_password(user_id, current_password, new_password)
      when is_binary(user_id) do
    case database_enabled?() do
      true ->
        update_password_database(user_id, current_password, new_password)

      false ->
        update_password_agent(user_id, current_password, new_password)
    end
  end

  def update_password(_user_id, _current_password, _new_password),
    do: {:error, :invalid_user_id}

  @doc """
  Checks if a user has permission to perform an action on a module.

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
  @spec has_permission?(
          map() | String.t(),
          atom() | String.t(),
          atom() | String.t()
        ) :: boolean()
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
  Finds a user by email address.

  ## Parameters

  - `email` - The email address to search for

  ## Returns

  - `{:ok, user}` - User found
  - `{:error, :not_found}` - User not found
  - `{:error, reason}` - Database error

  ## Examples

      iex> find_user_by_email("user@example.com")
      {:ok, %User{id: "user123", email: "user@example.com", ...}}

      iex> find_user_by_email("nonexistent@example.com")
      {:error, :not_found}
  """
  def find_user_by_email(email) when is_binary(email) do
    case database_enabled?() do
      true ->
        case Repo.get_by(User, email: email) do
          nil -> {:error, :not_found}
          user -> {:ok, Repo.preload(user, [:role, :permissions])}
        end

      false ->
        # Use Agent storage when database is disabled
        case Agent.get(__MODULE__, fn users -> Map.get(users, email) end) do
          nil -> {:error, :not_found}
          user -> {:ok, user}
        end
    end
  end

  def find_user_by_email(_email), do: {:error, :invalid_email}

  @doc """
  Creates a default admin user if no users exist in the system.

  ## Returns

  - `{:ok, user}` - Admin user created
  - `{:error, reason}` - Creation failed

  ## Examples

      iex> create_default_admin()
      {:ok, %User{id: "admin123", email: "admin@raxol.com", role: %Role{name: "admin"}}}
  """
  def create_default_admin do
    case database_enabled?() do
      true ->
        create_default_admin_database()

      false ->
        create_default_admin_agent()
    end
  end

  # Database-backed implementations

  defp register_user_database(attrs) do
    # Ensure we have a default role
    attrs = Map.put_new(attrs, :role_id, get_default_role_id())

    case Database.create(User, attrs) do
      {:ok, user} ->
        # Preload associations
        user_with_associations = Repo.preload(user, [:role, :permissions])
        {:ok, user_with_associations}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp authenticate_user_database(email, password) do
    case find_user_by_email(email) do
      {:ok, user} ->
        authenticate_user_password(user, password)

      {:error, :not_found} ->
        {:error, :invalid_credentials}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Database error during authentication: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp update_password_database(user_id, current_password, new_password) do
    case get_user(user_id) do
      {:ok, user} ->
        if verify_password(current_password, user.password_hash) do
          update_user_password(user, new_password)
        else
          {:error, :invalid_current_password}
        end

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_default_admin_database do
    # Check if any users exist
    case Database.all(User) do
      {:ok, []} ->
        # Create admin role if it doesn't exist
        admin_role =
          case Repo.get_by(Role, name: "admin") do
            nil ->
              case Database.create(Role, %{
                     name: "admin",
                     description: "System administrator",
                     system: true
                   }) do
                {:ok, role} -> role
                {:error, _reason} -> nil
              end

            role ->
              role
          end

        if admin_role do
          # Create admin user
          admin_attrs = %{
            email: "admin@raxol.com",
            username: "admin",
            password: "admin123",
            role_id: admin_role.id,
            active: true
          }

          case Database.create(User, admin_attrs) do
            {:ok, user} ->
              user_with_associations = Repo.preload(user, [:role, :permissions])
              {:ok, user_with_associations}

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :failed_to_create_admin_role}
        end

      {:ok, _users} ->
        {:error, :users_already_exist}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Agent-based implementations (for backward compatibility)

  defp register_user_agent(attrs) do
    email = Map.get(attrs, :email) || Map.get(attrs, "email")
    password = Map.get(attrs, :password) || Map.get(attrs, "password")

    Agent.get_and_update(__MODULE__, fn users ->
      if Map.has_key?(users, email) do
        {{:error, %{email: "has already been taken"}}, users}
      else
        user_id = Ecto.UUID.generate()
        # Hash the password for security
        password_hash = hash_password(password)
        new_user = %{id: user_id, email: email, password_hash: password_hash}

        {{:ok, Map.take(new_user, [:id, :email])},
         Map.put(users, email, new_user)}
      end
    end)
  end

  defp authenticate_user_agent(email, password) do
    Agent.get(__MODULE__, fn users ->
      case Map.get(users, email) do
        nil ->
          {:error, :invalid_credentials}

        user ->
          if verify_password(password, user.password_hash) do
            # Return only public user info on success
            {:ok, Map.take(user, [:id, :email])}
          else
            {:error, :invalid_credentials}
          end
      end
    end)
  end

  defp update_password_agent(user_id, current_password, new_password) do
    Agent.get_and_update(__MODULE__, fn users ->
      # Find user by ID first (inefficient)
      found_entry =
        Enum.find(users, fn {_email, user} -> user.id == user_id end)

      case found_entry do
        nil ->
          # User ID not found
          {{:error, :not_found}, users}

        {email, user} ->
          if verify_password(current_password, user.password_hash) do
            # Hash the new password
            password_hash = hash_password(new_password)
            updated_user = %{user | password_hash: password_hash}
            updated_users = Map.put(users, email, updated_user)
            {{:ok, updated_user}, updated_users}
          else
            # Current password mismatch
            {{:error, :invalid_current_password}, users}
          end
      end
    end)
  end

  defp create_default_admin_agent do
    Agent.get_and_update(__MODULE__, fn users ->
      if map_size(users) == 0 do
        admin_id = Ecto.UUID.generate()

        admin_user = %{
          id: admin_id,
          email: "admin@raxol.com",
          password_hash: hash_password("admin123"),
          role: "admin"
        }

        {{:ok, admin_user}, Map.put(users, "admin@raxol.com", admin_user)}
      else
        {{:error, :users_already_exist}, users}
      end
    end)
  end

  # Helper functions

  defp authenticate_user_password(user, password) do
    # Delegate to Auth module for authentication
    Raxol.Auth.authenticate_user_password(user, password)
  end

  defp verify_password(password, password_hash) do
    # Use Bcrypt for password verification
    Bcrypt.verify_pass(password, password_hash)
  rescue
    _ -> false
  end

  defp hash_password(password) do
    # Use Bcrypt for password hashing
    Bcrypt.hash_pwd_salt(password)
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
      if failed_attempts >= @max_failed_attempts,
        do:
          DateTime.add(DateTime.utc_now(), @lockout_duration_seconds, :second),
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

  defp check_user_permissions(user, module, action) do
    # Delegate to Auth module for permission checking
    Raxol.Auth.check_user_permissions(user, module, action)
  end

  defp has_admin_role?(user) do
    case user.role do
      %Role{name: "admin"} -> true
      # For Agent-based users
      %{role: "admin"} -> true
      _ -> false
    end
  end

  defp get_default_role_id do
    # Get the default "user" role ID
    case Repo.get_by(Role, name: @default_role_name) do
      # Will be handled by the changeset
      nil -> nil
      role -> role.id
    end
  end

  defp database_enabled? do
    Application.get_env(:raxol, :database_enabled, false)
  end

  # Legacy User struct for backward compatibility
  defmodule User do
    defstruct [:id, :email, :password_hash, :role]
  end
end
