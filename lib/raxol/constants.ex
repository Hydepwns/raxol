defmodule Raxol.Constants do
  @moduledoc """
  Centralized defaults for the Raxol framework.

  Provides canonical default values for terminal dimensions, rendering intervals,
  network ports, and buffer sizes. Use these instead of hardcoding magic numbers.
  """

  # Terminal
  @default_terminal_width 80
  @default_terminal_height 24
  @default_scrollback_size 10_000

  # Rendering (60fps)
  @default_frame_interval_ms 16

  # SSH
  @default_ssh_port 2222

  def default_terminal_width, do: @default_terminal_width
  def default_terminal_height, do: @default_terminal_height

  def default_terminal_dimensions,
    do: {@default_terminal_width, @default_terminal_height}

  def default_scrollback_size, do: @default_scrollback_size
  def default_frame_interval_ms, do: @default_frame_interval_ms
  def default_ssh_port, do: @default_ssh_port
end
