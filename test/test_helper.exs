ExUnit.start()

# Ensure necessary applications are started and Sandbox owner is running
if Application.get_env(:raxol, :database_enabled, true) do
  # Ensure the :raxol app (and its children like Repo) are started
  {:ok, _} = Application.ensure_all_started(:raxol)

  # Ensure ecto_sql is started (might be redundant if already in extra_applications, but safe)
  Application.ensure_all_started(:ecto_sql)

  # Start the Ecto Sandbox owner process
  # DB should have been created/migrated by the `mix test` alias now
  # :ok = Ecto.Adapters.SQL.Sandbox.start_owner!(Raxol.Repo, []) # COMMENT OUT
end

# Set Raxol.Test.Mocks.EventManagerMock to :stub mode globally for tests
# This allows Mox.stub/expect to be used on this manually defined mock module
# when it's injected via app config, without needing Mox.defmock for it.
# Mox.set_mode(Raxol.Test.Mocks.EventManagerMock, :stub) # No longer needed with dummy behaviour approach
