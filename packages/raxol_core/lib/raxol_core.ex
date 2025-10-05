defmodule RaxolCore do
  @moduledoc """
  Lightweight terminal buffer primitives for Elixir.

  RaxolCore provides pure functional operations for creating, manipulating,
  and rendering terminal buffers. It has zero runtime dependencies and
  compiles to less than 100KB, making it perfect for:

  - CLI tools and scripts
  - Terminal UIs
  - Phoenix LiveView integration
  - Custom terminal renderers

  ## Quick Start

      alias Raxol.Core.{Buffer, Box}

      # Create a buffer
      buffer = Buffer.create_blank_buffer(40, 10)

      # Draw a box
      buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)

      # Write text
      buffer = Buffer.write_at(buffer, 5, 4, "Hello, Raxol!")

      # Render it
      IO.puts(Buffer.to_string(buffer))

  ## Modules

  - `Raxol.Core.Buffer` - Buffer creation and manipulation
  - `Raxol.Core.Renderer` - Rendering and diffing
  - `Raxol.Core.Box` - Box drawing utilities
  - `Raxol.Core.Style` - Style management and ANSI codes

  ## Documentation

  See the [Getting Started Guide](https://hexdocs.pm/raxol_core/readme.html)
  for tutorials and examples.
  """

  @doc """
  Returns the version of RaxolCore.
  """
  def version, do: unquote(Mix.Project.config()[:version])
end
