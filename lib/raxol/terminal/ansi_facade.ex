defmodule Raxol.Terminal.ANSIFacade do
  @moduledoc """
  Facade for the ANSI module functionality that maintains backward compatibility.

  This module provides the same interface as the original monolithic ANSI module
  but delegates to the refactored sub-modules. This allows for a smooth transition
  while code that depends on the original API is updated.

  DEPRECATED: This module is provided for backward compatibility only. New code should
  use the appropriate sub-modules directly.
  """

  alias Raxol.Terminal.ANSI.Parser
  alias Raxol.Terminal.ANSI.Emitter
  alias Raxol.Terminal.ANSI.Processor
  alias Raxol.Terminal.ANSI.Sequences.{Cursor, Colors, Modes}
  require Logger

  # Constants
  @colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  # State initialization
  def new do
    # Forward to the appropriate new module
    # TODO: Update to reflect new state structure
    %{
      mouse_state: Raxol.Terminal.ANSI.MouseEvents.new(),
      window_state: Raxol.Terminal.ANSI.WindowManipulation.new(),
      sixel_state: Raxol.Terminal.ANSI.SixelGraphics.new()
    }
  end

  @doc """
  Parses ANSI escape sequences from a string.

  This method delegates to the ANSI.Parser module for the actual parsing.

  ## Parameters

  * `input` - The string containing ANSI escape sequences

  ## Returns

  A list of parsed tokens.

  ## Migration Path

  Update your code to use the Parser module directly:

  ```elixir
  # Before
  tokens = Raxol.Terminal.ANSI.parse(input)

  # After
  tokens = Raxol.Terminal.ANSI.Parser.parse(input)
  ```
  """
  def parse(input) when is_binary(input) do
    Logger.warn(
      "Raxol.Terminal.ANSI.parse/1 is deprecated. " <>
      "Use Raxol.Terminal.ANSI.Parser.parse/1 instead."
    )
    Parser.parse(input)
  end

  @doc """
  Emits an ANSI escape sequence for a specific operation.

  This method delegates to the ANSI.Emitter module for sequence generation.

  ## Parameters

  * `operation` - The operation to emit a sequence for
  * `args` - Arguments for the operation

  ## Returns

  The ANSI escape sequence string.

  ## Migration Path

  Update your code to use the Emitter module directly:

  ```elixir
  # Before
  sequence = Raxol.Terminal.ANSI.emit(:cursor_up, [2])

  # After
  sequence = Raxol.Terminal.ANSI.Emitter.emit(:cursor_up, [2])
  ```
  """
  def emit(operation, args \\ []) do
    Logger.warn(
      "Raxol.Terminal.ANSI.emit/2 is deprecated. " <>
      "Use Raxol.Terminal.ANSI.Emitter.emit/2 instead."
    )
    Emitter.emit(operation, args)
  end

  # Forward interface for ANSI sequence processing
  def process_escape(emulator, sequence) do
    Logger.warn(
      "Raxol.Terminal.ANSI.process_escape/2 is deprecated. " <>
      "Use Raxol.Terminal.ANSI.Parser.parse_sequence/1 and Raxol.Terminal.ANSI.Processor.process/2 instead."
    )

    # Parse the sequence using the Parser module and process it using the Processor module
    parsed_sequence = Parser.parse_sequence(sequence)
    Processor.process(parsed_sequence, emulator)
  end

  # Screen manipulation functions have been moved to the appropriate modules
  # and are now delegated through the Processor module.

  # Add other methods from the original ANSI module that need compatibility shims
  # ...
end
