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
          history_limit: non_neg_integer()
        }

  defstruct [
    :buffer,
    :mode,
    :history,
    :history_index,
    :history_limit
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
      history_limit: history_limit
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

  # Private functions

  defp handle_enter(%__MODULE__{} = input) do
    if input.buffer != "" do
      input
      |> add_to_history(input.buffer)
      |> clear_buffer()
    else
      input
    end
  end

  defp handle_backspace(%__MODULE__{} = input) do
    %{input | buffer: String.slice(input.buffer, 0..-2//1)}
  end

  defp handle_tab(%__MODULE__{} = input) do
    # Basic tab completion: insert spaces
    # TODO: Implement context-aware tab completion later
    # Or get from config/options
    tab_width = 4
    spaces = String.duplicate(" ", tab_width)
    %{input | buffer: input.buffer <> spaces}
  end

  defp handle_escape(%__MODULE__{} = input) do
    %{input | mode: :normal}
  end

  defp handle_printable(%__MODULE__{} = input, char) do
    %{input | buffer: input.buffer <> char}
  end

  defp handle_click(%__MODULE__{} = input, _x, _y, _button) do
    # TODO: Implement click handling
    input
  end

  defp handle_drag(%__MODULE__{} = input, _x, _y, _button) do
    # TODO: Implement drag handling
    input
  end

  defp handle_release(%__MODULE__{} = input, _x, _y, _button) do
    # TODO: Implement release handling
    input
  end
end
