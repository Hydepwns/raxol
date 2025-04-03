defmodule Raxol.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :string, primary_key: true
      add :user_id, :string, null: false
      add :status, :string, null: false
      add :created_at, :utc_datetime, null: false
      add :last_active, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :metadata, :map

      timestamps()
    end

    create index(:sessions, [:user_id])
    create index(:sessions, [:status])
    create index(:sessions, [:created_at])
    create index(:sessions, [:last_active])
  end
end 