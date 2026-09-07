import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :raxol_playground, RaxolPlaygroundWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test-secret-key-base-at-least-64-characters-long-for-security-purposes-in-test",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# /replay rate-limits server-side seeks per socket. The tests drive many seeks
# in a row through `handle_event/3` and read the screen back synchronously, so
# the limiter would defer them to a `:seek_tick` they never wait for. Disabled
# here; `ReplayLiveTest` sets a real interval for the one case that asserts the
# limiter itself.
config :raxol_playground, :replay_min_seek_interval_ms, 0
