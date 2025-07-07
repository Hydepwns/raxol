import Config

# Configure your database for tests - use MockDB adapter
config :raxol, Raxol.Repo,
  adapter: Raxol.Test.MockDB,
  # Remove SQL Sandbox pool as it's incompatible with MockDB
  # pool: Ecto.Adapters.SQL.Sandbox,
  enabled: true

# Configure database settings
# Global flag to enable database for tests
config :raxol, database_enabled: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :raxol, RaxolWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # Must be at least 64 bytes for Plug/Phoenix session
  secret_key_base: String.duplicate("a", 64),
  server: false,
  pubsub_server: Raxol.PubSub

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful sandbox testing commands (from raxol/support/test_helper.ex)
config :raxol, :enable_test_commands, true

# Configure terminal settings for testing
config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 100,
  enable_ansi: true,
  enable_mouse: false,
  debug_mode: false,
  log_level: :warn,
  # --- REVERT TO MOCK NIF FOR TESTING --- #
  use_termbox: false,
  mock_termbox: true

# --------------------------------------- #

# Flag to control compilation of AI-related tests
config :raxol, :compile_ai_tests, false

# Configure web interface settings for testing
config :raxol, :web,
  default_theme: "dark",
  enable_websockets: false,
  session_timeout: 60,
  debug_mode: false,
  enable_hot_reload: false

# Configure test helpers
config :raxol, :test_helpers,
  enable_mock_web: true,
  mock_timeout: 1000

# Disable unnecessary services for ANSI processor tests
config :raxol, :ansi_processor_test,
  disable_services: [
    :database,
    :web,
    :mailer,
    :hot_reload,
    :color_system
  ]

# Configure Swoosh API Client adapter
config :swoosh, :api_client, Raxol.Finch

config :swoosh,
  log_level: :warning,
  api_client: Raxol.Finch

# Configure Mox for testing behaviours
config :mox, :exclude_compilation, false

# Configure all mock implementations
config :raxol, :mocks, %{
  # Core runtime mocks
  :"Raxol.Core.Runtime.Plugins.FileWatcher" =>
    :"Raxol.Core.Runtime.Plugins.FileWatcherMock",
  :"Raxol.Core.Runtime.Plugins.Loader" =>
    :"Raxol.Core.Runtime.Plugins.LoaderMock",
  :"Raxol.Core.Runtime.Plugins.LifecycleHelper" =>
    :"Raxol.Core.Runtime.Plugins.LifecycleHelperMock",
  :"Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelper" =>
    :"Raxol.Core.Runtime.Plugins.EdgeCasesLifecycleHelperMock",
  :"Raxol.Core.Runtime.Plugins.PluginEventFilter" =>
    :"Raxol.Core.Runtime.Plugins.PluginEventFilterMock",
  :"Raxol.Core.Runtime.Plugins.PluginCommandDispatcher" =>
    :"Raxol.Core.Runtime.Plugins.PluginCommandDispatcherMock",
  :"Raxol.Core.Runtime.Plugins.PluginReloader" =>
    :"Raxol.Core.Runtime.Plugins.PluginReloaderMock",
  :"Raxol.Core.Runtime.Plugins.PluginCommandHandler" =>
    :"Raxol.Core.Runtime.Plugins.PluginCommandHandlerMock",
  :"Raxol.Core.Runtime.Plugins.TimerManager" =>
    :"Raxol.Core.Runtime.Plugins.TimerManagerMock",
  :"Raxol.Core.Runtime.Rendering.Engine" =>
    :"Raxol.Core.Runtime.Rendering.EngineMock",

  # System and UI mocks
  :"Raxol.System.DeltaUpdaterSystemAdapter" =>
    :"Raxol.System.DeltaUpdaterSystemAdapterMock",
  :"Raxol.Terminal.Config.EnvironmentAdapter" =>
    :"Raxol.Terminal.Config.EnvironmentAdapterMock",
  :"Raxol.Terminal.ClipboardBehaviour" => :"Raxol.Terminal.ClipboardMock"
}

# Configure the KeyboardShortcuts module to use for testing
config :raxol, :keyboard_shortcuts_module, Raxol.Mocks.KeyboardShortcutsMock

# Configure Raxol specific test settings
config :raxol, :env, :test
# Enable debug mode for tests if needed
config :raxol, :debug_mode, true

# Configure mock implementations for behaviours
config :raxol, :keyboard_shortcuts_impl, Raxol.Mocks.KeyboardShortcutsMock

config :raxol,
       :delta_updater_system_adapter_impl,
       Raxol.Mocks.DeltaUpdaterSystemAdapterMock

config :raxol, :environment_adapter_impl, Raxol.Mocks.EnvironmentAdapterMock

# Note: This was not Raxol.Mocks.SystemInteractionMock, may need consistency check
config :raxol, :system_interaction_impl, SystemInteractionMock
config :raxol, :focus_manager_impl, Raxol.Mocks.FocusManagerMock
config :raxol, :accessibility_impl, Raxol.Mocks.AccessibilityMock
config :raxol, :event_manager, Raxol.Mocks.EventManagerMock

# Configure Mox mocks for testing
config :raxol,
  accessibility_module: Raxol.Mocks.AccessibilityMock,
  focus_manager_module: Raxol.Mocks.FocusManagerMock,
  keyboard_shortcuts_module: Raxol.Mocks.KeyboardShortcutsMock

# Configure test environment
config :raxol,
  test_mode: true,
  database_enabled: true

# Configure test helpers
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 1000,
  refute_receive_timeout: 1000
