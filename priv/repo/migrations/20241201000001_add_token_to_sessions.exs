defmodule Raxol.Repo.Migrations.AddTokenToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :token, :string
    end

    create index(:sessions, [:token])
  end
end
