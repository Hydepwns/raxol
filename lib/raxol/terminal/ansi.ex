defmodule Raxol.Terminal.ANSI do
  @moduledoc """
  ANSI escape sequence handling.

  DEPRECATED: This module is being refactored into smaller, more focused modules.
  Use the modules in the Raxol.Terminal.ANSI namespace instead:

  - Raxol.Terminal.ANSI.Parser - For parsing ANSI sequences
  - Raxol.Terminal.ANSI.Emitter - For generating ANSI sequences
  - Raxol.Terminal.ANSI.Processor - For processing ANSI sequences
  - Raxol.Terminal.ANSI.Sequences.{Cursor, Colors, Modes} - For specific sequence types

  This module is maintained for backward compatibility and will be removed in a future release.
  """

  # alias Raxol.Terminal.ANSIFacade # Removed
  alias Raxol.Terminal.ANSI.Sequences.Colors
  alias Raxol.Terminal.ANSI.Parser
  alias Raxol.Terminal.ANSI.Processor

  @doc """
  Returns a map of ANSI color codes.

  DEPRECATED: Use Raxol.Terminal.ANSI.Sequences.Colors.color_codes/0 instead.

  ## Returns

  A map of color names to ANSI codes.

  ## Migration Path

  ```elixir
  # Before
  colors = Raxol.Terminal.ANSI.colors()

  # After
  colors = Raxol.Terminal.ANSI.Sequences.Colors.color_codes()
  ```
  """
  def colors do
    # Delegate to the Colors module
    Colors.color_codes()
  end

  @doc """
  Parses ANSI escape sequences from a string.

  DEPRECATED: Use Raxol.Terminal.ANSI.Parser.parse/1 instead.

  ## Parameters

  * `input` - The string containing ANSI escape sequences

  ## Returns

  A list of parsed tokens.

  ## Migration Path

  ```elixir
  # Before
  tokens = Raxol.Terminal.ANSI.parse(input)

  # After
  tokens = Raxol.Terminal.ANSI.Parser.parse(input)
  ```
  """
  def parse(input) do
    # ANSIFacade.parse(input) # Old call
    Parser.parse(input) # Delegate to the Parser module
  end

  @doc """
  Processes an ANSI escape sequence.

  DEPRECATED: Use the Processor and specific sequence handler modules instead.

  ## Parameters

  * `sequence` - The ANSI escape sequence to process
  * `state` - The current state

  ## Returns

  Updated state after processing the sequence.

  ## Migration Path

  ```elixir
  # Before
  new_state = Raxol.Terminal.ANSI.process_escape(sequence, state)

  # After
  parsed = Raxol.Terminal.ANSI.Parser.parse_sequence(sequence)
  new_state = Raxol.Terminal.ANSI.Processor.process(parsed, state)
  ```
  """
  def process_escape(sequence, state) do
    # ANSIFacade.process_escape(sequence, state) # Old call
    # Delegate to the Processor module. Assumes sequence is already parsed appropriately.
    Processor.process(sequence, state)
  end
end
