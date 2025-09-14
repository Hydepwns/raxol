defmodule Raxol.Terminal.Commands.History do
  @moduledoc false

  @type command_history :: [String.t()]
  @type command_history_config :: %{
          max_size: non_neg_integer(),
          current_input: String.t()
        }

  @type t :: %__MODULE__{
          commands: command_history(),
          current_index: integer(),
          max_size: non_neg_integer(),
          current_input: String.t()
        }

  defstruct [
    :commands,
    :current_index,
    :max_size,
    :current_input
  ]

  @spec new(non_neg_integer()) :: t()
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %__MODULE__{
      commands: [],
      current_index: -1,
      max_size: max_size,
      current_input: ""
    }
  end

  @spec add(t(), String.t()) :: t()
  def add(%__MODULE__{} = history, command) when is_binary(command) do
    commands = [command | history.commands]
    commands = Enum.take(commands, history.max_size)

    %{history | commands: commands, current_index: -1, current_input: ""}
  end

  @spec previous(t()) :: {String.t() | nil, t()}
  def previous(%__MODULE__{} = history) do
    case history.current_index + 1 < length(history.commands) do
      true ->
        new_index = history.current_index + 1
        command = Enum.at(history.commands, new_index)
        {command, %{history | current_index: new_index}}

      false ->
        {nil, history}
    end
  end

  @doc """
  Retrieves the next command in history.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.add(history, "cd /tmp")
      iex> {_, history} = History.previous(history)
      iex> History.next(history)
      {"ls -la", %History{...}}
  """
  @spec next(t()) :: {String.t() | nil, t()}
  def next(%__MODULE__{} = history) do
    case history.current_index - 1 >= -1 do
      true ->
        new_index = history.current_index - 1

        command =
          case new_index do
            -1 -> history.current_input
            _ -> Enum.at(history.commands, new_index)
          end

        {command, %{history | current_index: new_index}}

      false ->
        {nil, history}
    end
  end

  @doc """
  Saves the current input state.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.save_input(history, "ls -l")
      iex> history.current_input
      "ls -l"
  """
  @spec save_input(t(), String.t()) :: t()
  def save_input(%__MODULE__{} = history, input) when is_binary(input) do
    %{history | current_input: input}
  end

  @doc """
  Clears the command history.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.clear(history)
      iex> history.commands
      []
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = history) do
    %{history | commands: [], current_index: -1, current_input: ""}
  end

  @doc """
  Returns the current command history as a list.

  ## Examples

      iex> history = History.new(1000)
      iex> history = History.add(history, "ls -la")
      iex> history = History.add(history, "cd /tmp")
      iex> History.list(history)
      ["cd /tmp", "ls -la"]
  """
  @spec list(t()) :: command_history()
  def list(%__MODULE__{} = history) do
    history.commands
  end

  @doc """
  Adds to the emulator's command history if the input is a newline (10),
  or appends to the current command buffer if it's a printable character.
  Returns the updated emulator struct.
  """
  @spec maybe_add_to_history(Emulator.t(), integer()) :: Emulator.t()
  def maybe_add_to_history(emulator, 10) do
    # On newline, add the current buffer to history if not empty, then clear buffer
    cmd = String.trim(emulator.current_command_buffer)

    case cmd do
      "" ->
        %{emulator | current_command_buffer: ""}

      _ ->
        updated_history =
          [cmd | emulator.command_history]
          |> Enum.take(emulator.max_command_history)

        %{
          emulator
          | command_history: updated_history,
            current_command_buffer: ""
        }
    end
  end

  @spec maybe_add_to_history(Emulator.t(), integer()) :: Emulator.t()
  def maybe_add_to_history(emulator, char)
      when is_integer(char) and char >= 32 and char <= 0x10FFFF do
    # Skip history if disabled (current_command_buffer is nil)
    case emulator.current_command_buffer do
      nil ->
        emulator

      buffer ->
        new_buffer = buffer <> <<char::utf8>>
        %{emulator | current_command_buffer: new_buffer}
    end
  end

  @spec maybe_add_to_history(Emulator.t(), any()) :: Emulator.t()
  def maybe_add_to_history(emulator, _), do: emulator

  @doc """
  Updates the maximum size of the command history. Truncates the history if needed.
  """
  @spec update_size(t(), non_neg_integer()) :: t()
  def update_size(%__MODULE__{} = history, new_size)
      when is_integer(new_size) and new_size > 0 do
    commands = Enum.take(history.commands, new_size)

    %{
      history
      | commands: commands,
        max_size: new_size,
        current_index: min(history.current_index, new_size - 1)
    }
  end

  @doc """
  Updates the command history configuration.
  Delegates to update_size/2 for compatibility.
  """
  def update_config(%__MODULE__{} = history, config) do
    update_size(history, config.command_history_limit)
  end
end
