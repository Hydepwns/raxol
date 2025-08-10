import Config

# CI-specific configuration
config :raxol,
  ci_environment: true,
  skip_docker_tests: System.get_env("SKIP_DOCKER_TESTS") == "true",
  skip_termbox2_tests: System.get_env("SKIP_TERMBOX2_TESTS") == "true",
  docker_available: System.get_env("DOCKER_AVAILABLE") == "true"

# Database configuration for CI
if System.get_env("CI") == "true" do
  config :raxol, Raxol.Repo,
    username: System.get_env("POSTGRES_USER", "postgres"),
    password: System.get_env("POSTGRES_PASSWORD", "postgres"),
    database: System.get_env("POSTGRES_DB", "raxol_test"),
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
    pool_size: 10,
    pool: Ecto.Adapters.SQL.Sandbox
end

# Platform-specific settings
platform = System.get_env("PLATFORM", "unknown")

config :raxol, :platform,
  name: platform,
  is_macos: platform == "macOS" or platform == "Darwin",
  is_linux: platform == "Linux",
  is_ci: System.get_env("CI") == "true"

# Test-specific overrides for CI
if config_env() == :test do
  # Disable features that require Docker on macOS CI
  if platform in ["macOS", "Darwin"] and System.get_env("CI") == "true" do
    config :raxol,
      disable_docker_features: true,
      disable_termbox2: true,
      headless_mode: true
  end

  # Use mock implementations for CI
  config :raxol,
    use_mock_terminal: System.get_env("CI") == "true",
    use_mock_graphics: System.get_env("CI") == "true"
end

# Logger configuration for CI
config :logger,
  level: if(System.get_env("CI") == "true", do: :warning, else: :info)

# Ensure test watcher doesn't run in CI
if System.get_env("CI") == "true" do
  config :mix_test_watch,
    clear: false,
    tasks: []
end
