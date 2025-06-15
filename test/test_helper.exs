# Start Mox
IO.puts("[TestHelper] Starting Mox...")
Application.ensure_started(:mox, :permanent)

# Core runtime mocks
Mox.defmock(Raxol.Core.Runtime.Plugins.FileWatcherMock,
  for: Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LoaderMock,
  for: Raxol.Core.Runtime.Plugins.LoaderBehaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
  for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.PluginEventFilterMock,
  for: Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.PluginReloaderMock,
  for: Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.PluginCommandHandlerMock,
  for: Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.TimerManagerMock,
  for: Raxol.Core.Runtime.Plugins.TimerManager.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Rendering.EngineMock,
  for: Raxol.Core.Runtime.Rendering.Engine.Behaviour
)

# System and UI mocks
Mox.defmock(Raxol.System.DeltaUpdaterSystemAdapterMock,
  for: Raxol.System.DeltaUpdaterSystemAdapterBehaviour
)

Mox.defmock(Raxol.Terminal.Config.EnvironmentAdapterMock,
  for: Raxol.Terminal.Config.EnvironmentAdapterBehaviour
)

Mox.defmock(Raxol.Terminal.ClipboardMock,
  for: Raxol.Terminal.ClipboardBehaviour
)

# Start ExUnit
IO.puts("[TestHelper] Starting ExUnit...")
ExUnit.start()

# Start the application for testing
IO.puts("[TestHelper] Starting application for testing...")
Application.ensure_all_started(:raxol)

# Set test environment
IO.puts("[TestHelper] Setting test environment...")
Application.put_env(:raxol, :test_mode, true)

# Note: Module redefinition warnings are expected in test environment
# as test modules are often redefined during test runs.
# These warnings can be safely ignored.

# Load support files
IO.puts("[TestHelper] Loading support files...")
Code.require_file("support/helpers.ex", __DIR__)
Code.require_file("support/event_macro_helpers.ex", __DIR__)
Code.require_file("support/mocks.ex", __DIR__)
Code.require_file("support/test_helper.ex", __DIR__)

# Set up mocks
IO.puts("[TestHelper] Setting up mocks...")
# Raxol.Test.Support.MockSetup.setup_mocks()  # Removed, handled elsewhere

# Initialize terminal for tests unless explicitly skipped
if System.get_env("RAXOL_SKIP_TERMINAL_INIT") != "true" and
     not Enum.any?(
       System.argv(),
       &String.contains?(&1, "csi_handlers_test.exs")
     ) do
  IO.puts("[TestHelper] Initializing terminal...")
  init_result = Raxol.Terminal.Integration.Renderer.init_terminal()

  if init_result != :ok do
    raise "Terminal failed to initialize in test_helper.exs: #{inspect(init_result)}"
  end

  # Shutdown the terminal after the test suite
  System.at_exit(fn _exit_status ->
    IO.puts("[TestHelper] Shutting down terminal...")
    Raxol.Terminal.Integration.Renderer.shutdown_terminal()
  end)
else
  IO.puts("[TestHelper] Skipping terminal initialization and shutdown.")
end

# Initialize default theme for tests
IO.puts("[TestHelper] Initializing default theme...")
Raxol.UI.Theming.Theme.init()

# Make UserPreferences globally available
IO.puts("[TestHelper] Initializing UserPreferences...")
Raxol.Core.UserPreferences.start_link(test_mode?: true)

# Reset UserPreferences to defaults after the test suite
System.at_exit(fn _exit_status ->
  IO.puts("[TestHelper] Resetting UserPreferences to defaults...")
  Raxol.Core.UserPreferences.reset_to_defaults_for_test!()
end)

# Set up database if enabled
if Application.get_env(:raxol, :database_enabled, true) do
  IO.puts("[TestHelper] Setting up database...")
  Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, :manual)
  Application.ensure_all_started(:ecto_sql)
end

# Set up global test configuration
IO.puts("[TestHelper] Setting up global test configuration...")

# Configure test helpers
Application.put_env(:ex_unit, :capture_log, true)
Application.put_env(:ex_unit, :assert_receive_timeout, 1000)
Application.put_env(:ex_unit, :refute_receive_timeout, 1000)

# Configure test mode for all components
Application.put_env(:raxol, :terminal, test_mode: true)
Application.put_env(:raxol, :web, test_mode: true)
Application.put_env(:raxol, :core, test_mode: true)
Application.put_env(:raxol, :plugins, test_mode: true)
