# Invalid config file with missing required fields
%{
  terminal: %{
    # Missing required fields: width, height, mode
  },
  buffer: %{
    # Missing required fields: max_size, scrollback
  },
  renderer: %{
    # Missing required fields: mode, double_buffering
  }
}
