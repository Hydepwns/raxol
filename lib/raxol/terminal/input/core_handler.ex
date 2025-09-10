defmodule Raxol.Terminal.Input.CoreHandler do
  @moduledoc """
  Core input handling functionality for the terminal emulator.
  Manages the main input buffer and cursor state.
  """

  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.TerminalParser, as: Parser
  alias Raxol.Terminal.Emulator

  @type t :: %__MODULE__{
          buffer: String.t(),
          cursor_position: non_neg_integer(),
          tab_completion: map(),
          tab_completion_index: non_neg_integer(),
          tab_completion_matches: list(String.t()),
          mode_manager: ModeManager.t()
        }

  defstruct [
    :buffer,
    :cursor_position,
    :tab_completion,
    :tab_completion_index,
    :tab_completion_matches,
    :mode_manager
  ]

  @doc """
  Creates a new input handler with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      buffer: "",
      cursor_position: 0,
      tab_completion: %{},
      tab_completion_index: 0,
      tab_completion_matches: [],
      mode_manager: ModeManager.new()
    }
  end

  @doc """
  Inserts text at the specified position in the buffer.
  """
  @spec insert_text(String.t(), non_neg_integer(), String.t()) :: String.t()
  def insert_text(buffer, position, text) do
    before_text = String.slice(buffer, 0, position)
    after_text = String.slice(buffer, position..-1//1)
    before_text <> text <> after_text
  end

  @doc """
  Processes a raw input string for the terminal, parsing control sequences and printable characters.
  This function drives the terminal command parser.
  """
  @spec process_terminal_input(Emulator.t(), String.t()) ::
          {Emulator.t(), String.t()}
  def process_terminal_input(emulator, input) when is_binary(input) do
    current_parser_state = emulator.parser_state

    {parsed_emulator, parsed_parser_state, remaining_input_chunk} =
      Parser.parse_chunk(emulator, current_parser_state, input)

    case remaining_input_chunk do
      "" ->
        :ok

      _ ->
        Raxol.Core.Runtime.Log.debug(
          "[InputHandler] Parser.parse_chunk returned remaining input: #{inspect(remaining_input_chunk)}"
        )
    end

    final_emulator_updated = %{
      parsed_emulator
      | parser_state: parsed_parser_state
    }

    output_to_send = final_emulator_updated.output_buffer

    final_emulator_state_no_output = %{
      final_emulator_updated
      | output_buffer: ""
    }

    {final_emulator_state_no_output, output_to_send}
  end
end
