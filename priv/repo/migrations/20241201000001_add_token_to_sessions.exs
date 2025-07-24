defmodule Raxol.Repo.Migrations.AddTokenToSessions do
  use Ecto.Migration

  def change do
    # Token column is already created in the create_sessions migration
    # This migration is now a no-op
  end
end
