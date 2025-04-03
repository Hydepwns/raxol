defmodule Raxol.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :description, :string
      add :module, :string, null: false
      add :action, :string, null: false
      add :is_system, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:permissions, [:name])
    create unique_index(:permissions, [:module, :action])
  end
end 