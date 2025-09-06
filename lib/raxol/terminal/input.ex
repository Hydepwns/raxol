defmodule Raxol.Terminal.Input do
  @moduledoc """
  Handles input processing for the terminal.
  """

  defstruct [
    :buffer,
    :state,
    :last_click,
    :last_drag,
    :last_release,
    :completion_callback,
    :completion_options,
    :completion_index
  ]

  @type completion_callback :: (String.t() -> [String.t()])

  @type t :: %__MODULE__{
          buffer: list(),
          state: atom(),
          last_click: {integer(), integer(), atom()} | nil,
          last_drag: {integer(), integer(), atom()} | nil,
          last_release: {integer(), integer(), atom()} | nil,
          completion_callback: completion_callback() | nil,
          completion_options: [String.t()],
          completion_index: non_neg_integer()
        }

  @doc """
  Creates a new input handler.
  """
  def new do
    %__MODULE__{
      buffer: [],
      state: :normal,
      last_click: nil,
      last_drag: nil,
      last_release: nil,
      completion_callback: nil,
      completion_options: [],
      completion_index: 0
    }
  end

  @doc """
  Handles a mouse click event.
  """
  def handle_click(input, x, y, button) do
    %{input | last_click: {x, y, button}}
  end

  @doc """
  Handles a mouse drag event.
  """
  def handle_drag(input, x, y, button) do
    %{input | last_drag: {x, y, button}}
  end

  @doc """
  Handles a mouse release event.
  """
  def handle_release(input, x, y, button) do
    %{input | last_release: {x, y, button}}
  end

  @doc """
  Performs tab completion on the input buffer.
  Uses the completion_callback to find matches and cycles through them.
  """
  def tab_complete(%__MODULE__{completion_callback: nil} = input) do
    # No completion callback set, return unchanged
    input
  end

  def tab_complete(%__MODULE__{completion_callback: callback} = input) do
    # Convert buffer to string for completion
    buffer_string = buffer_to_string(input.buffer)

    # Ensure completion_options is a list
    completion_options = input.completion_options || []

    case completion_options == [] do
      true ->
        # First tab - get initial completions
        options = callback.(buffer_string)

        case options do
          [] ->
            # No matches, return unchanged
            input

          [single_match] ->
            # Single match, complete immediately and clear options
            %{
              input
              | buffer: string_to_buffer(single_match),
                completion_options: [],
                completion_index: 0
            }

          multiple_matches ->
            # Multiple matches, set up for cycling
            first_match = Enum.at(multiple_matches, 0)

            %{
              input
              | buffer: string_to_buffer(first_match),
                completion_options: multiple_matches,
                completion_index: 0
            }
        end
      false ->
        # Subsequent tabs - cycle through existing options
        next_index = rem(input.completion_index + 1, length(completion_options))
        next_match = Enum.at(completion_options, next_index)

        %{
          input
          | buffer: string_to_buffer(next_match),
            completion_index: next_index
        }
    end
  end

  @doc """
  Clears completion state. Should be called when input changes other than tab completion.
  """
  def clear_completion(%__MODULE__{} = input) do
    %{input | completion_options: [], completion_index: 0}
  end

  @doc """
  Example completion callback that provides Elixir keywords.
  """
  def example_completion_callback(prefix) do
    elixir_keywords = [
      "def",
      "defp",
      "defmodule",
      "defstruct",
      "defprotocol",
      "defimpl",
      "do",
      "end",
      "if",
      "unless",
      "when",
      "case",
      "cond",
      "with",
      "try",
      "catch",
      "rescue",
      "after",
      "receive",
      "for",
      "import",
      "alias",
      "require",
      "use",
      "quote",
      "unquote",
      "spawn",
      "send",
      "fn",
      "->",
      "true",
      "false",
      "nil"
    ]

    elixir_keywords
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.sort()
  end

  # Helper functions

  defp buffer_to_string(buffer) when is_list(buffer) do
    buffer |> Enum.join("")
  end

  defp string_to_buffer(string) when is_binary(string) do
    String.graphemes(string)
  end
end
