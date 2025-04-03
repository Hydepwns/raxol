defmodule Raxol.Auth.Role do
  @moduledoc """
  Role schema for role-based access control.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Raxol.Auth.{Permission, User}

  schema "roles" do
    field :name, :string
    field :description, :string
    field :is_system, :boolean, default: false

    # Associations
    has_many :users, User
    many_to_many :permissions, Permission, join_through: "role_permissions"

    timestamps()
  end

  @doc """
  Creates a changeset for a role.
  """
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description, :is_system])
    |> validate_required([:name])
    |> validate_length(:name, min: 3, max: 50)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name)
  end

  @doc """
  Creates a changeset for a system role.
  """
  def system_changeset(role, attrs) do
    role
    |> changeset(attrs)
    |> put_change(:is_system, true)
  end
end 