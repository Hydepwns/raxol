defmodule Raxol.Web.Session.Session do
  @moduledoc """
  Database schema for session storage.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  schema "sessions" do
    field :user_id, :string
    field :status, Ecto.Enum, values: [:active, :ended, :expired]
    field :created_at, :utc_datetime
    field :last_active, :utc_datetime
    field :ended_at, :utc_datetime
    field :metadata, :map

    timestamps()
  end

  @doc """
  Creates a changeset for a session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:id, :user_id, :status, :created_at, :last_active, :ended_at, :metadata])
    |> validate_required([:id, :user_id, :status, :created_at, :last_active])
    |> validate_inclusion(:status, [:active, :ended, :expired])
  end
end 