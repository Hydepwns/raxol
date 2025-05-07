# ExUnit.configure(exclude: [:slow, :pending], trace: true, formatters: [ExUnit.CLIFormatter])

# # Ensure Mox application is started before use Mox
# Application.ensure_all_started(:mox)

# # Make sure all deps are available for tests
# Application.ensure_all_started(:phoenix)
# Application.ensure_all_started(:phoenix_pubsub)

# # Initialize UserPreferences with the test configuration
# Raxol.Core.UserPreferences.init(%{preferences_file_path: "test/support/test_preferences.json"})

# # Load test-specific configuration
# config_path = Path.join([__DIR__, "..", "config", "test.exs"])
# if File.exists?(config_path) do
#   Code.require_file(config_path)
# else
#   IO.puts(:stderr, "Warning: test.exs not found at #{config_path}")
# end

# # Only use Mox in the test environment
# # if Mix.env == :test do
# #  # Use Mox for mocking
# #  use Mox
# # end

# # Custom test setup and teardown hooks
# Raxol.Test.TestHelper.setup_all()
# ExUnit.after_suite(fn _ -> Raxol.Test.TestHelper.teardown_all() end)

# # Load mock definitions and other test support files
# Code.require_file("test/support/mocks.ex")
# Code.require_file("test/support/test_utils.ex")
# Code.require_file("test/support/component_manager_test_mocks.ex")

# Ensure Mox app is started right before ExUnit starts
# Application.ensure_all_started(:mox)

# Start ExUnit ONCE at the end
ExUnit.start(
  # include: [:focus],
  # exclude: [:skip, :pending],
  # seed: 0,
  # # Verify Mox expectations on exit
  # on_exit: {Mox, :verify_on_exit!, [%{post_verify_callback: &Mox.VerifyCallbacks.log_post_verify/1}]},
  # # Enable detailed trace for failures
  # trace: true,
  # # Maximum number of concurrent test cases
  # max_cases: System.schedulers_online() * 2 # Adjust based on your system
)
