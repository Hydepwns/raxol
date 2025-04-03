defmodule Raxol.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :is_active, :boolean, default: true, null: false
      add :is_admin, :boolean, default: false, null: false
      add :last_login_at, :utc_datetime
      add :confirmation_token, :string
      add :confirmed_at, :utc_datetime
      add :confirmation_sent_at, :utc_datetime
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
      add :role_id, references(:roles, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
    create index(:users, [:confirmation_token])
    create index(:users, [:reset_password_token])
    create index(:users, [:role_id])
  end
end 