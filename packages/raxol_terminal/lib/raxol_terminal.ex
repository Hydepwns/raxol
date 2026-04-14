defmodule RaxolTerminal do
  @moduledoc """
  Terminal emulation and rendering for Elixir.

  Provides VT100/ANSI terminal emulation, screen buffer management,
  cursor handling, input processing, and the termbox2 NIF backend.
  Handles color downsampling, Unicode display width, synchronized
  output, and cross-platform rendering (native NIF on Unix,
  pure Elixir IOTerminal on Windows).
  """
end
