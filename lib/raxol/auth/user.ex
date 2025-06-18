defmodule Raxol.Auth.User do
  @moduledoc '''
  User schema for authentication and authorization.
  '''

  use Ecto.Schema
  import Ecto.Changeset

  alias Raxol.Auth.Permission
  alias Raxol.Auth.Role

  schema "users" do
    field :email, :string
    field :username, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :is_active, :boolean, default: true
    field :last_login, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :reset_password_token, :string
    field :reset_password_sent_at, :utc_datetime
    field :confirmation_token, :string
    field :confirmed_at, :utc_datetime
    field :unconfirmed_email, :string

    # Associations
    belongs_to :role, Role
    many_to_many :permissions, Permission, join_through: "user_permissions"

    timestamps()
  end

  @doc '''
  Creates a changeset for a user.
  '''
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :username,
      :password,
      :is_active,
      :last_login,
      :failed_login_attempts,
      :locked_until,
      :reset_password_token,
      :reset_password_sent_at,
      :confirmation_token,
      :confirmed_at,
      :unconfirmed_email,
      :role_id
    ])
    |> validate_required([:email, :username])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 8, max: 72)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end

  @doc '''
  Creates a changeset for registration.
  '''
  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> validate_required([:password])
    |> put_confirmation_token()
  end

  @doc '''
  Creates a changeset for password reset.
  '''
  def password_reset_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> put_password_hash()
    |> put_reset_password_token()
  end

  # Private functions

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end

  defp put_confirmation_token(changeset) do
    token = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    put_change(changeset, :confirmation_token, token)
  end

  defp put_reset_password_token(changeset) do
    token = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    put_change(changeset, :reset_password_token, token)
  end
end
