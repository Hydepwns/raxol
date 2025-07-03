# Invalid config file with syntax error
%{
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
  # Missing closing brace - this will cause a syntax error
