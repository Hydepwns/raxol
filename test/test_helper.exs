IO.puts("[TestHelper] === TEST HELPER STARTING ===")

# Start Mox - wrapped in try/catch for safety
try do
  {:ok, _} = Application.ensure_all_started(:mox)
  IO.puts("[TestHelper] Mox started successfully")
rescue
  e ->
    IO.puts(:stderr, "[TestHelper] Warning: Could not start Mox: #{inspect(e)}")
end

# --- Global Docker Test Skip Logic ---
if System.get_env("SKIP_TERMBOX2_TESTS") == "true" do
  IO.puts(
    :stderr,
    "[CI] Skipping Docker-dependent tests (SKIP_TERMBOX2_TESTS=true)"
  )

  ExUnit.configure(exclude: [docker: true])
end

# To mark a test as Docker-dependent, use:
#   @tag :docker
#   test "..." do ... end

# Start ExUnit
IO.puts("[TestHelper] Starting ExUnit...")
ExUnit.start(max_failures: 10)
ExUnit.configure(formatters: [ExUnit.CLIFormatter])

# Set test environment
IO.puts("[TestHelper] Setting test environment...")
Application.put_env(:raxol, :test_mode, true)

# Set up database BEFORE starting the application
if Application.get_env(:raxol, :database_enabled, true) do
  IO.puts("[TestHelper] Setting up database...")
  # Ensure Ecto is started
  # {:ok, _} = Application.ensure_all_started(:ecto)  # Removed to prevent auto-starting Repo
  # {:ok, _} = Application.ensure_all_started(:ecto_sql)  # Removed to prevent auto-starting Repo

  # Start the application (which includes the repo)
  IO.puts("[TestHelper] Starting application for testing...")
  {:ok, _} = Application.ensure_all_started(:raxol)

  # Don't set up sandbox mode for MockDB - it doesn't support it
  # Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, :manual)
else
  # Start the application without database setup
  IO.puts("[TestHelper] Starting application for testing...")
  Application.ensure_all_started(:raxol)
end

# Mox is a library, not an application - no need to start it

# Note: Module redefinition warnings are expected in test environment
# as test modules are often redefined during test runs.
# These warnings can be safely ignored.

# Support files are automatically compiled by Mix due to elixirc_paths configuration
# No need to require them explicitly
IO.puts("[TestHelper] Support files loaded via elixirc_paths...")

# Set up mocks
IO.puts("[TestHelper] Setting up mocks...")
# Raxol.Test.Support.MockSetup.setup_mocks()  # Removed, handled elsewhere

# Initialize terminal for tests unless explicitly skipped
if System.get_env("RAXOL_SKIP_TERMINAL_INIT") != "true" and
     not Enum.any?(
       System.argv(),
       &String.contains?(&1, "csi_handlers_test.exs")
     ) do
  IO.puts("[TestHelper] Initializing terminal (test mode)...")

  # In test mode, we don't actually initialize the real terminal
  # Instead, we just set up the test environment
  Application.put_env(:raxol, :terminal_test_mode, true)

  # Mock the terminal initialization for tests
  # This prevents the actual termbox2_nif.tb_init() call that hangs in test environments
  :ok

  # Temporarily disable the at_exit handler to avoid the crash
  # System.at_exit(fn _exit_status ->
  #   IO.puts("[TestHelper] Shutting down terminal (test mode)...")
  #   # In test mode, we don't need to actually shutdown the terminal
  #   :ok
  # end)
else
  IO.puts("[TestHelper] Skipping terminal initialization and shutdown.")
end

# Initialize default theme for tests
IO.puts("[TestHelper] Initializing default theme...")
Raxol.UI.Theming.Theme.init()

# Make UserPreferences globally available
IO.puts("[TestHelper] Initializing UserPreferences...")

# Raxol.Core.UserPreferences is started by the supervision tree; do not start it manually here.
# Manual start_link removed to avoid race/duplication issues. See test stabilization notes.

# Reset UserPreferences to defaults after the test suite
# Temporarily disable the at_exit handler to avoid the crash
# System.at_exit(fn _exit_status ->
#   IO.puts("[TestHelper] Resetting UserPreferences to defaults...")
#   Raxol.Core.UserPreferences.reset_to_defaults_for_test!()
# end)

# Start the Accessibility Announcements Agent for global subscription storage
{:ok, _} = Raxol.Core.Accessibility.Announcements.start_link([])

# Start ProcessStore for replacing Process dictionary usage
{:ok, _} = Raxol.Core.Runtime.ProcessStore.start_link()

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

# Start the endpoint globally for all tests
IO.puts("[TestHelper] Starting endpoint globally for tests...")
Application.ensure_all_started(:phoenix)
Application.ensure_all_started(:plug_cowboy)

# Configure Mox mocks after application is started
IO.puts("[TestHelper] Configuring Mox mocks...")

# Skip Mox configuration if Mox is not available
if Code.ensure_loaded?(Mox) do
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

  # TimerManager mock removed - no behavior exists for TimerManager
  # Mox.defmock(Raxol.Core.Runtime.Plugins.TimerManagerMock,
  #   for: Raxol.Core.Runtime.Plugins.TimerManager.Behaviour
  # )

  # Rendering Engine mock removed - no behavior exists for Rendering Engine
  # Mox.defmock(Raxol.Core.Runtime.Rendering.EngineMock,
  #   for: Raxol.Core.Runtime.Rendering.Engine.Behaviour
  # )

  # System and UI mocks
  Mox.defmock(Raxol.System.DeltaUpdaterSystemAdapterMock,
    for: Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  )

  Mox.defmock(SystemInteractionMock,
    for: Raxol.System.Interaction
  )

  Mox.defmock(Raxol.Terminal.Config.EnvironmentAdapterMock,
    for: Raxol.Terminal.Config.EnvironmentAdapterBehaviour
  )

  Mox.defmock(Raxol.Core.ClipboardMock,
    for: Raxol.Core.Clipboard.Behaviour
  )

  # Accessibility and UX mocks
  Mox.defmock(Raxol.Mocks.AccessibilityMock,
    for: Raxol.Core.Accessibility.Behaviour
  )

  Mox.defmock(Raxol.Mocks.FocusManagerMock,
    for: Raxol.Core.FocusManager.Behaviour
  )

  # KeyboardShortcuts mock for UX refinement tests
  Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock,
    for: Raxol.Core.KeyboardShortcutsBehaviour
  )

  IO.puts("[TestHelper] Mox mocks configured successfully")
else
  IO.puts("[TestHelper] Skipping Mox mock configuration - Mox not available")
end

# Clipboard assertions are automatically loaded via elixirc_paths
IO.puts("[TestHelper] Clipboard assertions loaded via elixirc_paths...")

# Start the event registry for tests
IO.puts("[TestHelper] Starting event registry...")

{:ok, _registry_pid} =
  Registry.start_link(keys: :duplicate, name: :raxol_event_subscriptions)

# Start the EventManager for tests
IO.puts("[TestHelper] Starting EventManager...")

case Raxol.Core.Events.EventManager.start_link(
       name: Raxol.Core.Events.EventManager
     ) do
  {:ok, _pid} ->
    IO.puts("[TestHelper] EventManager started successfully")

  {:error, {:already_started, _pid}} ->
    IO.puts("[TestHelper] EventManager already running")

  {:error, reason} ->
    IO.puts(
      :stderr,
      "[TestHelper] Failed to start EventManager: #{inspect(reason)}"
    )
end

# Skip endpoint startup - Phoenix web interface removed
# if Process.whereis(RaxolWeb.Endpoint) do
#   IO.puts("[TestHelper] Endpoint already running")
# else
#   {:ok, _pid} = RaxolWeb.Endpoint.start_link()
#   IO.puts("[TestHelper] Endpoint started successfully")
# end
IO.puts("[TestHelper] Skipping endpoint - Phoenix web interface disabled")

IO.puts("[TestHelper] Test helper setup complete!")
