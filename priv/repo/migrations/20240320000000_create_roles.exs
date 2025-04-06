defmodule Raxol.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :description, :string
      add :is_system, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:roles, [:name])
  end
end 