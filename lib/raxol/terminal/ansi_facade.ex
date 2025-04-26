defmodule Raxol.Terminal.ANSIFacade do
  @moduledoc """
  DEPRECATED: Provides a simplified facade for interacting with ANSI escape sequences.

  This module is being replaced by the more structured modules within
  `Raxol.Terminal.ANSI.*` (Parser, Processor, Emitter, Sequences, etc.).

  Functions are kept temporarily for backward compatibility but primarily log warnings.
  """

  require Logger

  # alias Raxol.Terminal.ANSI # Unused
  # alias Raxol.Terminal.ScreenBuffer # Unused
  # alias Raxol.Terminal.ANSI.Emitter # Unused
  # alias Raxol.Terminal.ANSI.Processor # Unused
  # alias Raxol.Terminal.Attributes # Unused
  # alias Raxol.Terminal.Emulator # Unused

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
    Logger.warning(
      "Raxol.Terminal.ANSI.parse/1 is deprecated. " <>
        "Use Raxol.Terminal.ANSI.Parser.parse/1 instead."
    )

    Raxol.Terminal.ANSI.Parser.parse(input)
  end

  # Removed deprecated emit/2 function. Users should call functions in
  # Raxol.Terminal.ANSI.Emitter directly.
  # def emit(operation, args) do ... end

  # Forward interface for ANSI sequence processing
  def process_escape(byte_sequence, emulator) do
    case Raxol.Terminal.ANSI.Parser.parse(byte_sequence) do
      {:ok, parsed_sequence} ->
        Logger.debug("Parsed ANSI: #{inspect(parsed_sequence)}")
        Raxol.Terminal.ANSI.Processor.process(parsed_sequence, emulator)

      {:error, reason} ->
        Logger.warning("Failed to parse ANSI sequence: #{reason} - #{inspect(byte_sequence)}")
    end
  end

  # Screen manipulation functions have been moved to the appropriate modules
  # and are now delegated through the Processor module.

  # Add other methods from the original ANSI module that need compatibility shims
  # ...
end
