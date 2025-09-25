defmodule Raxol.Terminal.ParserState do
  @moduledoc """
  Alias module for parser state functionality.
  This module delegates to the actual implementation in Parser.ParserState.
  """

  alias Raxol.Terminal.Parser.ParserState, as: Implementation

  # Re-export the type
  @type t :: Implementation.t()

  @doc """
  Creates a new parser state.
  """
  @spec new() :: t()
  def new do
    %Implementation{}
  end

  @doc """
  Processes a character through the parser state.
  """
  @spec process_char(t(), byte()) :: {t(), list()}
  def process_char(state, char) do
    # Basic state machine implementation
    # This is a simplified version - you may need to expand based on your needs
    case state.state do
      :ground ->
        handle_ground_state(state, char)

      :escape ->
        handle_escape_state(state, char)

      :csi_entry ->
        handle_csi_entry_state(state, char)

      _ ->
        {state, []}
    end
  end

  defp handle_ground_state(state, char) do
    case char do
      # ESC
      0x1B ->
        {%{state | state: :escape}, []}

      _ when char >= 0x20 and char <= 0x7E ->
        {state, [{:print, <<char>>}]}

      _ ->
        {state, []}
    end
  end

  defp handle_escape_state(state, char) do
    case char do
      # CSI
      ?[ ->
        {%{state | state: :csi_entry, params: [], params_buffer: ""}, []}

      _ ->
        {%{state | state: :ground}, []}
    end
  end

  defp handle_csi_entry_state(state, char) do
    cond do
      char >= ?0 and char <= ?9 ->
        # Accumulate parameter digits
        {%{state | params_buffer: state.params_buffer <> <<char>>}, []}

      char == ?; ->
        # Parameter separator
        param =
          if state.params_buffer == "",
            do: 0,
            else: String.to_integer(state.params_buffer)

        {%{state | params: state.params ++ [param], params_buffer: ""}, []}

      char >= 0x40 and char <= 0x7E ->
        # Final byte - execute CSI sequence
        params = finalize_params(state)

        {%{state | state: :ground, params: [], params_buffer: ""},
         [{:csi, params, char}]}

      true ->
        {state, []}
    end
  end

  defp finalize_params(state) do
    params = state.params

    if state.params_buffer != "" do
      params ++ [String.to_integer(state.params_buffer)]
    else
      params
    end
  end
end
