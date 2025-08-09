defmodule Raxol.Terminal.Commands.CSIHandlers.SequenceDispatcher do
  @moduledoc """
  Handles CSI sequence dispatching and parsing.
  """

  alias Raxol.Terminal.Commands.CSIHandlers.{SequenceParser, ApplyHandlers}

  @sequence_handlers %{
    [?A] => {:cursor_up, 1},
    [?B] => {:cursor_down, 1},
    [?C] => {:cursor_forward, 1},
    [?D] => {:cursor_backward, 1},
    [?H] => {:cursor_position, []},
    [?G] => {:cursor_column, 1},
    [?J] => {:screen_clear, []},
    [?K] => {:line_clear, 0},
    [?m] => {:text_attributes, []},
    [?S] => {:scroll_up, 1},
    [?T] => {:scroll_down, 1},
    [?n] => {:device_status, []},
    [?s] => {:save_cursor, []},
    [?u] => {:restore_cursor, []},
    [?6, ?n] => {:device_status_report, []},
    [?6, ?R] => {:cursor_position_report, []},
    [?N] => {:locking_shift_g0, []},
    [?O] => {:locking_shift_g1, []},
    [?R] => {:single_shift_g2, []},
    # Bracketed paste sequences
    [?2, ?0, ?0, ?~] => {:bracketed_paste_start, []},
    [?2, ?0, ?1, ?~] => {:bracketed_paste_end, []}
  }

  def handle_sequence(emulator, sequence) do
    case Map.get(@sequence_handlers, sequence) do
      {handler, args} ->
        result = ApplyHandlers.apply_handler(emulator, handler, args)

        case result do
          {:ok, emu} -> emu
          {:error, _, emu} -> emu
          emu -> emu
        end

      nil ->
        # Handle parameterized sequences
        case parse_parameterized_sequence(sequence) do
          {:ok, handler, params} ->
            result = ApplyHandlers.apply_handler(emulator, handler, params)

            case result do
              {:ok, emu} -> emu
              {:error, _, emu} -> emu
              emu -> emu
            end

          {:error, :unknown_sequence, _sequence} ->
            # Ignore unknown sequences and return emulator unchanged
            emulator

          :error ->
            # Ignore unknown sequences and return emulator unchanged
            emulator
        end
    end
  end

  defp parse_parameterized_sequence(sequence) do
    cond do
      SequenceParser.parse_cursor_sequence(sequence) != :error ->
        SequenceParser.parse_cursor_sequence(sequence)

      true ->
        :error
    end
  end
end
