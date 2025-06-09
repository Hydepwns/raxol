import Config

# Configure Mox
# Set the mock implementation for the Clipboard Behaviour
config :raxol, :mocks, ClipboardBehaviour: ClipboardMock

# Configure your database
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20

# Override Repo adapter and pool for tests
# config :raxol, Raxol.Repo, # Commenting out this MockDB override
#   adapter: Raxol.Test.MockDB,
#   pool: Ecto.Adapters.SQL.Sandbox,
#   # Ensure it's disabled unless explicitly used in specific tests
#   enabled: true

# Configure database settings
# Global flag to disable database
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
