require Mox
require IO # Require IO for inspect

# Configure the test environment
Application.put_env(:raxol, :database_enabled, false)
Application.put_env(:phoenix, :serve_endpoints, false)

# Start necessary applications BEFORE ExUnit and Mox setup
# Start :mox first as Mox.Server depends on it.
{:ok, _} = Application.ensure_all_started(:mox)
IO.inspect(Application.started_applications(), label: "---> Started Apps before Mox.Server start_link") # DEBUG
{:ok, _} = Application.ensure_all_started(:ecto_sql) # Keep for now, might be needed by deps

# Configure MockDB (if needed for specific tests later, though DB seems disabled)
Application.put_env(:raxol, :database_adapter, Raxol.Test.MockDB)

# Start Mox Server *after* :mox app is started
IO.inspect(Mox.Server, label: "---> Mox.Server Module before start_link") # DEBUG

# Load mock definitions *after* Mox Server is potentially started (or not)
Code.require_file("test/support/mocks.ex")
Code.require_file("test/raxol/accessibility_test_helpers.ex") # Ensure helpers are loaded
Code.require_file("test/raxol/i18n_test_helpers.ex") # Ensure I18n helpers are loaded

# Start ExUnit ONCE at the end
ExUnit.start(
  # max_cases: 1 # Allow parallel execution
  # Verify Mox expectations on exit - COMMENTED OUT
  # on_exit: {Mox, :verify_on_exit!, [%{post_verify_callback: &Mox.VerifyCallbacks.log_post_verify/1}]}
)
