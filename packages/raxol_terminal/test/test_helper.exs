# Configure ExUnit
ExUnit.start(exclude: [:slow, :integration, :docker, :skip_on_ci])

# Set test environment variables
System.put_env("MIX_ENV", "test")
