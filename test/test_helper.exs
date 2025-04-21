# Configure the test environment
Application.put_env(:raxol, :database_enabled, false)
# Application.put_env(:raxol, Raxol.Repo, enabled: false)

# Ensure database is not started (redundant with above?)
Application.put_env(:phoenix, :serve_endpoints, false)
# Application.put_env(:raxol, :start_db, false)

# Start necessary applications before ExUnit
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# Re-enabled this for testing component behaviour - Commenting out to prevent conflicts
# {:ok, _} = Application.ensure_all_started(:raxol)

# Start Mox before ExUnit compiles tests that use it
{:ok, _} = Application.ensure_all_started(:mox)

# Define global mocks *before* ExUnit starts
# Mox.defmock(HTTPoison.Base, for: HTTPoison.Base) # Commented out global mock
# Mox.defmock(Raxol.Core.AccessibilityMock, for: Raxol.Core.Accessibility) # Removed - Will use stub_with

# Start ExUnit without starting the full application explicitly here
# Applications needed by tests should be started in their respective setup blocks
# Set max_cases to 1 to disable parallel test execution
ExUnit.start(max_cases: 1)

# Start the Repo supervisor for tests
{:ok, _pid} = Raxol.Repo.start_link()

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
