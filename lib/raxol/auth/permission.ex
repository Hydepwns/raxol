defmodule Raxol.Auth.Permission do
  @moduledoc """
  Permission schema for role-based access control.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Raxol.Auth.Role

  schema "permissions" do
    field :name, :string
    field :description, :string
    field :module, :string
    field :action, :string
    field :is_system, :boolean, default: false

    # Associations
    many_to_many :roles, Role, join_through: "role_permissions"

    timestamps()
  end

  @doc """
  Creates a changeset for a permission.
  """
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :description, :module, :action, :is_system])
    |> validate_required([:name, :module, :action])
    |> validate_length(:name, min: 3, max: 50)
    |> validate_length(:description, max: 500)
    |> validate_length(:module, min: 3, max: 100)
    |> validate_length(:action, min: 3, max: 50)
    |> unique_constraint([:module, :action])
  end

  @doc """
  Creates a changeset for a system permission.
  """
  def system_changeset(permission, attrs) do
    permission
    |> changeset(attrs)
    |> put_change(:is_system, true)
  end
end 