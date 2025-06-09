# Start Mox
IO.puts("[TestHelper] Starting Mox...")
Application.ensure_started(:mox, :permanent)

# Start ExUnit
IO.puts("[TestHelper] Starting ExUnit...")
ExUnit.start()

# Set test environment
IO.puts("[TestHelper] Setting test environment...")
Application.put_env(:raxol, :test_mode, true)

# Start the application for testing
IO.puts("[TestHelper] Starting application for testing...")
Application.ensure_all_started(:raxol)

# Initialize terminal for tests unless explicitly skipped
if System.get_env("RAXOL_SKIP_TERMINAL_INIT") != "true" and
     not Enum.any?(
       System.argv(),
       &String.contains?(&1, "csi_handlers_test.exs")
     ) do
  IO.puts("[TestHelper] Initializing terminal...")
  init_result = Raxol.Terminal.Integration.Renderer.init_terminal()
  IO.inspect(init_result, label: "Terminal Initialization Result")

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

# Define mocks
IO.puts("[TestHelper] Defining mocks...")

# Core mocks
Mox.defmock(FileWatcherMock,
  for: Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour
)

Mox.defmock(LoaderMock, for: Raxol.Core.Runtime.Plugins.Loader.Behaviour)
Mox.defmock(AccessibilityMock, for: Raxol.Core.Accessibility.Behaviour)
Mox.defmock(ClipboardMock, for: Raxol.Core.Clipboard.Behaviour)

# Runtime plugin mocks
Mox.defmock(Raxol.Core.Runtime.Plugins.FileWatcherMock,
  for: Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LoaderMock,
  for: Raxol.Core.Runtime.Plugins.Loader.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.LifecycleHelperMock,
  for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
)

Mox.defmock(Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelperMock,
  for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
)

# System mocks
Mox.defmock(Raxol.System.DeltaUpdaterSystemAdapterMock,
  for: Raxol.System.DeltaUpdaterSystemAdapterBehaviour
)

Mox.defmock(Raxol.Terminal.Config.EnvironmentAdapterMock,
  for: Raxol.Terminal.Config.EnvironmentAdapterBehaviour
)

Mox.defmock(FileSystemMock, for: FileSystem.Behaviour)
Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

# Feature mocks
Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock,
  for: Raxol.Core.KeyboardShortcutsBehaviour
)

Mox.defmock(Raxol.Mocks.AccessibilityMock,
  for: Raxol.Core.Accessibility.Behaviour
)

Mox.defmock(Raxol.Mocks.ClipboardMock, for: Raxol.Core.Clipboard.Behaviour)

# Load support files
IO.puts("[TestHelper] Loading support files...")

# Load support helpers
Code.require_file("support/helpers.ex", __DIR__)
Code.require_file("support/event_macro_helpers.ex", __DIR__)

# Set up database if enabled
if Application.get_env(:raxol, :database_enabled, true) do
  IO.puts("[TestHelper] Setting up database...")
  Ecto.Adapters.SQL.Sandbox.mode(Raxol.Repo, :manual)
  Application.ensure_all_started(:ecto_sql)
end
