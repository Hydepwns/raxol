# Configure the test environment
Application.put_env(:raxol, :database_enabled, false)
Application.put_env(:raxol, Raxol.Repo, enabled: false)

# Ensure database is not started (redundant with above?)
Application.put_env(:phoenix, :serve_endpoints, false)
# Application.put_env(:raxol, :start_db, false)

# Start ExUnit without starting the full application explicitly here
# Applications needed by tests should be started in their respective setup blocks
ExUnit.start()

# Setup Ecto sandbox
# Note: Raxol.Repo might not be the correct Repo module name if using Phoenix default
# Check lib/raxol/repo.ex or config/config.exs if unsure
Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, :manual)

# Optional: Configure mock database if needed, but Sandbox is usually preferred
# Application.put_env(:raxol, Raxol.Repo, [
#   adapter: Raxol.Test.MockDB,
#   enabled: false, # Keep disabled if using Sandbox
#   pool: Ecto.Adapters.SQL.Sandbox
# ])
