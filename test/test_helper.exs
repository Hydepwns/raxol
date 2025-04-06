# Configure the test environment
Application.put_env(:raxol, :database_enabled, false)
Application.put_env(:raxol, Raxol.Repo, [enabled: false])

# Start ExUnit without starting the application
ExUnit.start()

# Configure test environment
Application.put_env(:raxol, :environment, :test)

# Ensure database is not started
Application.put_env(:phoenix, :serve_endpoints, false)
Application.put_env(:raxol, :start_db, false)

# Configure mock database
Application.put_env(:raxol, Raxol.Repo, [
  adapter: Raxol.Test.MockDB,
  enabled: false,
  pool: Ecto.Adapters.SQL.Sandbox
])
