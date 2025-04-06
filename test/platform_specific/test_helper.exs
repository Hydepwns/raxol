ExUnit.start()

# Set up platform-specific environment variables
System.put_env("TERM", "xterm-256color")
System.put_env("COLORTERM", "truecolor")
System.put_env("LANG", "en_US.UTF-8")
System.put_env("TERM_PROGRAM", "iTerm.app")

# Set up platform-specific test configuration
ExUnit.configure(
  exclude: [:platform_specific],
  timeout: 60_000
)
