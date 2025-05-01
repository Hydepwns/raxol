# Configure the test environment
Application.put_env(:raxol, :database_enabled, false)
# Application.put_env(:raxol, Raxol.Repo, enabled: false)

# Ensure database is not started (redundant with above?)
Application.put_env(:phoenix, :serve_endpoints, false)
# Application.put_env(:raxol, :start_db, false)

# Start necessary applications before ExUnit
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:mox)
# {:ok, _} = Application.ensure_all_started(:raxol) # <-- Removed, starts mock supervisor

# Start the Web Endpoint explicitly for channel/web tests
# Ensure RaxolWeb.Endpoint can be started independently or find its supervisor
# This might require looking into RaxolWeb.Endpoint's definition
# {:ok, _pid} = RaxolWeb.Endpoint.start_link(nil) # <-- Reverted this change

# Re-enabled this for testing component behaviour - Commenting out to prevent conflicts
{:ok, _} = Application.ensure_all_started(:raxol)

# Start Mox before ExUnit compiles tests that use it
# {:ok, _} = Application.ensure_all_started(:mox)

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

Code.require_file("test/support/mocks.ex")

# Define mocks for behaviours used across tests
# Mox.defmock(Raxol.Core.Accessibility.Mock, for: Raxol.Core.Accessibility.ThemeIntegration) # REMOVED - ThemeIntegration is not a behaviour and is mocked via :meck where needed
# Mox.defmock(Raxol.Core.UserPreferences.Mock, for: Raxol.Core.Preferences.Persistence) # REMOVED - Persistence is not a behaviour
# Mox.defmock(Raxol.Test.MockDB, for: Raxol.Database.DBConnection) # REMOVED - MockDB is the implementation, not a behaviour to mock, and the module name was wrong.

# Configure mocks for testing
# REMOVED - No longer needed as the Mox mock was removed
# Application.put_env(:raxol, :accessibility_theme_integration,
#  Raxol.Core.Accessibility.Mock
#)

# REMOVED - No longer needed as the Mox mock was removed
# Application.put_env(:raxol, :user_preferences_persistence,
#  Raxol.Core.UserPreferences.Mock
# )

# Configure MockDB for database tests
Application.put_env(:raxol, :database_adapter, Raxol.Test.MockDB)
Application.put_env(:raxol, :database_enabled, false)

# Don't start Mox globally here; it's managed per-test or via setup hooks
# Mox.start_link([global: true]) # <--- Comment out this line

# Allow Clipboard globally for the ClipboardPlugin process - REMOVED (Incorrect usage/placement)
# Mox.allow(Clipboard, Raxol.Plugins.Core.ClipboardPlugin)

# Define RaxolWeb alias if not already present
# alias RaxolWeb.Endpoint # <-- Reverted this change

# Start ExUnit only after mocks are defined and configured
ExUnit.start()
