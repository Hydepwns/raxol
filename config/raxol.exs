# Raxol Terminal Emulator Configuration
# This file uses the simple map structure expected by the Config Manager

%{
  dev: %{
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
  },
  test: %{
    terminal: %{
      width: 80,
      height: 24,
      mode: :normal
    },
    buffer: %{
      max_size: 1000,
      scrollback: 100
    },
    renderer: %{
      mode: :cpu,
      double_buffering: false
    }
  },
  prod: %{
    terminal: %{
      width: 120,
      height: 30,
      mode: :normal
    },
    buffer: %{
      max_size: 50_000,
      scrollback: 5000
    },
    renderer: %{
      mode: :gpu,
      double_buffering: true
    }
  }
}
