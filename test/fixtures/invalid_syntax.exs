import Config

config :raxol,
  terminal: %{
    width: 80,
    height: 24,
    mode: :normal
  },
  buffer: %{
    max_size: 10_000,
    scrollback: 1000
  },
  renderer: %{
    mode: :gpu,
    double_buffering: true
  }
