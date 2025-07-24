defmodule Raxol.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
        create table(:sessions) do
      add :user_id, :integer
      add :token, :string
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:sessions, [:user_id])
    create index(:sessions, [:token])
  end
end
