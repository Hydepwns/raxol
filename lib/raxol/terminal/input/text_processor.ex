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
    process_text_based_on_printability(printable_text?(input), input, emulator)
  end

  defp process_text_based_on_printability(false, _input, emulator), do: emulator

  defp process_text_based_on_printability(true, input, emulator) do
    emulator
    |> maybe_add_to_command_history(input)
    |> process_input_characters(input)
  end

  defp maybe_add_to_command_history(emulator, input) do
    process_command_history(
      String.ends_with?(input, "\n") and String.trim(input) != "",
      emulator,
      input
    )
  end

  defp process_command_history(false, emulator, _input), do: emulator

  defp process_command_history(true, emulator, input) do
    command = String.trim_trailing(input, "\n")

    add_to_history_if_valid(
      command != "" and can_add_to_history?(emulator),
      emulator,
      command
    )

    emulator
  end

  defp add_to_history_if_valid(false, _emulator, _command), do: :ok

  defp add_to_history_if_valid(true, emulator, command) do
    Raxol.Terminal.Commands.Manager.add_to_history(emulator.command, command)
  end

  defp can_add_to_history?(emulator) do
    Map.has_key?(emulator, :command) and
      function_exported?(Raxol.Terminal.Commands.Manager, :add_to_history, 2)
  end

  defp process_input_characters(emulator, input) do
    # DEBUG output removed
    codepoints = String.to_charlist(input)
    # DEBUG output removed

    codepoints
    |> Enum.reduce(emulator, fn codepoint, emu ->
      # DEBUG: TextProcessor - Processing codepoint: #{inspect(codepoint)}

      Raxol.Terminal.Input.CharacterProcessor.process_character(emu, codepoint)
    end)
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
