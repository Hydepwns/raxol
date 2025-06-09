defmodule Raxol.Terminal.Input do
  @moduledoc """
  Terminal input module.

  This module handles keyboard and mouse input events for the terminal, including:
  - Input buffering
  - Mode management
  - Input history
  - Special key handling
  """

  @type t :: %__MODULE__{
          buffer: String.t(),
          mode: atom(),
          history: list(String.t()),
          history_index: non_neg_integer(),
          history_limit: non_neg_integer(),
          completion_callback: (String.t() -> list(String.t())) | nil,
          completion_options: list(String.t()),
          completion_index: non_neg_integer() | nil,
          last_click: {integer(), integer(), integer()} | nil,
          last_drag: {integer(), integer(), integer()} | nil,
          last_release: {integer(), integer(), integer()} | nil
        }

  defstruct [
    :buffer,
    :mode,
    :history,
    :history_index,
    :history_limit,
    :completion_callback,
    :completion_options,
    :completion_index,
    :last_click,
    :last_drag,
    :last_release
  ]

  @doc """
  Creates a new input handler.

  ## Examples

      iex> input = Input.new()
      iex> input.mode
      :normal
      iex> input.buffer
      ""
  """
  def new(history_limit \\ 100) do
    %__MODULE__{
      buffer: "",
      mode: :normal,
      history: [],
      history_index: 0,
      history_limit: history_limit,
      completion_callback: nil,
      completion_options: [],
      completion_index: nil
    }
  end

  @doc """
  Processes a keyboard event.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "a")
      iex> input.buffer
      "a"
  """
  def process_keyboard(%__MODULE__{} = input, key) do
    case key do
      "\r" -> handle_enter(input)
      "\b" -> handle_backspace(input)
      "\t" -> handle_tab(input)
      "\e" -> handle_escape(input)
      key when byte_size(key) == 1 -> handle_printable(input, key)
      _ -> input
    end
  end

  @doc """
  Processes a mouse event.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.process_mouse(input, {:click, 1, 2, 1})
      iex> input.buffer
      ""
  """
  def process_mouse(%__MODULE__{} = input, event) do
    case event do
      {:click, x, y, button} -> handle_click(input, x, y, button)
      {:drag, x, y, button} -> handle_drag(input, x, y, button)
      {:release, x, y, button} -> handle_release(input, x, y, button)
      _ -> input
    end
  end

  @doc """
  Gets the current input buffer.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "test")
      iex> Input.get_buffer(input)
      "test"
  """
  def get_buffer(%__MODULE__{} = input) do
    input.buffer
  end

  @doc """
  Clears the input buffer.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "test")
      iex> input = Input.clear_buffer(input)
      iex> Input.get_buffer(input)
      ""
  """
  def clear_buffer(%__MODULE__{} = input) do
    %{input | buffer: ""}
  end

  @doc """
  Sets the input mode.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.set_mode(input, :insert)
      iex> input.mode
      :insert
  """
  def set_mode(%__MODULE__{} = input, mode) do
    %{input | mode: mode}
  end

  @doc """
  Gets the input mode.

  ## Examples

      iex> input = Input.new()
      iex> Input.get_mode(input)
      :normal
  """
  def get_mode(%__MODULE__{} = input) do
    input.mode
  end

  @doc """
  Adds a command to the history.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.add_to_history(input, "test")
      iex> length(input.history)
      1
  """
  def add_to_history(%__MODULE__{} = input, command) do
    new_history =
      [command | input.history]
      |> Enum.take(input.history_limit)

    %{input | history: new_history, history_index: 0}
  end

  @doc """
  Gets the previous command from history.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.add_to_history(input, "test")
      iex> input = Input.previous_command(input)
      iex> input.buffer
      "test"
  """
  def previous_command(%__MODULE__{} = input) do
    if input.history_index < length(input.history) do
      command = Enum.at(input.history, input.history_index)
      %{input | buffer: command, history_index: input.history_index + 1}
    else
      input
    end
  end

  @doc """
  Gets the next command from history.

  ## Examples

      iex> input = Input.new()
      iex> input = Input.add_to_history(input, "test")
      iex> input = Input.previous_command(input)
      iex> input = Input.next_command(input)
      iex> input.buffer
      ""
  """
  def next_command(%__MODULE__{} = input) do
    if input.history_index > 0 do
      %{
        input
        | history_index: input.history_index - 1,
          buffer:
            if(input.history_index == 1,
              do: "",
              else: Enum.at(input.history, input.history_index - 2)
            )
      }
    else
      input
    end
  end

  @doc """
  Sets a callback function for context-aware tab completion.
  The callback receives the current buffer and returns a list of completion options.
  """
  def set_completion_callback(%__MODULE__{} = input, callback)
      when is_function(callback, 1) do
    %{input | completion_callback: callback}
  end

  @doc """
  Triggers or cycles tab completion. If a callback is set, cycles through options; otherwise, inserts spaces.
  """
  def tab_complete(%__MODULE__{} = input) do
    if is_function(input.completion_callback, 1) do
      current_buffer = input.buffer
      options = input.completion_callback.(current_buffer)

      cond do
        options == [] ->
          input

        length(options) == 1 ->
          %{
            input
            | buffer: Enum.at(options, 0),
              completion_options: [],
              completion_index: 0
          }

        length(options) > 1 ->
          new_index = rem((input.completion_index || 0) + 1, length(options))

          %{
            input
            | buffer: Enum.at(options, new_index),
              completion_options: options,
              completion_index: new_index
          }
      end
    else
      # Fallback: insert spaces
      tab_width = 4
      spaces = String.duplicate(" ", tab_width)
      %{input | buffer: input.buffer <> spaces}
    end
  end

  @doc """
  Example completion callback: completes common Elixir keywords.
  """
  def example_completion_callback(buffer) do
    keywords = [
      "def",
      "defmodule",
      "defp",
      "if",
      "else",
      "case",
      "cond",
      "end",
      "do",
      "fn",
      "receive",
      "try",
      "catch",
      "rescue",
      "after"
    ]

    Enum.filter(keywords, &String.starts_with?(&1, buffer))
  end

  # Private functions

  def handle_enter(%__MODULE__{} = input) do
    if input.buffer != "" do
      input
      |> add_to_history(input.buffer)
      |> clear_buffer()
    else
      input
    end
  end

  def handle_backspace(%__MODULE__{} = input) do
    %{input | buffer: String.slice(input.buffer, 0..-2//1)}
  end

  def handle_tab(%__MODULE__{} = input), do: tab_complete(input)

  def handle_escape(%__MODULE__{} = input) do
    %{input | mode: :normal}
  end

  def handle_printable(%__MODULE__{} = input, char) do
    %{input | buffer: input.buffer <> char}
  end

  def handle_click(%__MODULE__{} = input, x, y, button) do
    # Basic click handling: store last click position and button
    %{input | last_click: {x, y, button}}
  end

  def handle_drag(%__MODULE__{} = input, x, y, button) do
    # Basic drag handling: store last drag position and button
    %{input | last_drag: {x, y, button}}
  end

  def handle_release(%__MODULE__{} = input, x, y, button) do
    # Basic release handling: store last release position and button
    %{input | last_release: {x, y, button}}
  end
end
