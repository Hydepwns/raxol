defmodule Raxol.Terminal.Input.TextProcessor do
  @moduledoc """
  Handles text input processing for the terminal emulator.
  This module extracts the text input handling logic from the main emulator.
  """

  @doc """
  Processes text input and applies character set translation.
  """
  @spec handle_text_input(binary(), any()) :: any()
  def handle_text_input(input, emulator) do
    if printable_text?(input) do
      # If input ends with \n, treat as command and add to history
      if String.ends_with?(input, "\n") and String.trim(input) != "" do
        command = String.trim_trailing(input)
        # Remove the trailing newline for history
        command = String.trim_trailing(command, "\n")
        if command != "" do
          # Add to command history if possible
          if Map.has_key?(emulator, :command) and function_exported?(Raxol.Terminal.Command.Manager, :add_to_history, 2) do
            Raxol.Terminal.Command.Manager.add_to_history(emulator.command, command)
          end
        end
      end
      # Process each codepoint through the character processor for charset translation
      String.to_charlist(input)
      |> Enum.reduce(emulator, fn codepoint, emu ->
        Raxol.Terminal.Input.CharacterProcessor.process_character(
          emu,
          codepoint
        )
      end)
    else
      emulator
    end
  end

  @doc """
  Checks if the input contains printable text.
  """
  @spec printable_text?(binary()) :: boolean()
  def printable_text?(input) do
    String.valid?(input) and
      String.length(input) > 0 and
      not String.contains?(input, "\e") and
      String.graphemes(input) |> Enum.all?(&printable_char?/1)
  end

  @doc """
  Checks if a character is printable.
  """
  @spec printable_char?(binary()) :: boolean()
  def printable_char?(char) do
    # Check if character is printable (not control characters)
    case char do
      <<code::utf8>> when code >= 32 and code <= 126 -> true
      # Extended ASCII and Unicode
      <<code::utf8>> when code >= 160 -> true
      # Allow newline character for command input
      <<10::utf8>> -> true
      _ -> false
    end
  end
end
