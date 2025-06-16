defmodule Raxol.Terminal.Command.Manager do
  @moduledoc """
  Manages terminal command state, history, and execution.
  """

  defstruct [
    command_buffer: "",
    command_history: [],
    last_key_event: nil,
    history_index: -1
  ]

  @type t :: %__MODULE__{
    command_buffer: String.t(),
    command_history: [String.t()],
    last_key_event: term(),
    history_index: integer()
  }

  @doc """
  Creates a new command manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current command buffer.
  """
  def get_command_buffer(%__MODULE__{} = state) do
    state.command_buffer
  end

  @doc """
  Updates the command buffer.
  """
  def update_command_buffer(%__MODULE__{} = state, new_buffer) when is_binary(new_buffer) do
    %{state | command_buffer: new_buffer}
  end

  @doc """
  Gets the command history.
  """
  def get_command_history(%__MODULE__{} = state) do
    state.command_history
  end

  @doc """
  Adds a command to the history.
  """
  def add_to_history(%__MODULE__{} = state, command) when is_binary(command) do
    %{state |
      command_history: [command | state.command_history],
      history_index: -1
    }
  end

  @doc """
  Clears the command history.
  """
  def clear_history(%__MODULE__{} = state) do
    %{state | command_history: [], history_index: -1}
  end

  @doc """
  Gets the last key event.
  """
  def get_last_key_event(%__MODULE__{} = state) do
    state.last_key_event
  end

  @doc """
  Updates the last key event.
  """
  def update_last_key_event(%__MODULE__{} = state, event) do
    %{state | last_key_event: event}
  end

  @doc """
  Processes a key event and updates the command buffer accordingly.
  """
  def process_key_event(%__MODULE__{} = state, key_event) do
    case key_event do
      {:key, :enter} ->
        if state.command_buffer != "" do
          state = add_to_history(state, state.command_buffer)
          %{state | command_buffer: ""}
        else
          state
        end

      {:key, :backspace} ->
        if state.command_buffer != "" do
          %{state | command_buffer: String.slice(state.command_buffer, 0..-2)}
        else
          state
        end

      {:key, :up} ->
        if state.history_index < length(state.command_history) - 1 do
          new_index = state.history_index + 1
          command = Enum.at(state.command_history, new_index)
          %{state |
            command_buffer: command,
            history_index: new_index
          }
        else
          state
        end

      {:key, :down} ->
        if state.history_index > -1 do
          new_index = state.history_index - 1
          command = if new_index == -1, do: "", else: Enum.at(state.command_history, new_index)
          %{state |
            command_buffer: command,
            history_index: new_index
          }
        else
          state
        end

      {:char, char} ->
        %{state | command_buffer: state.command_buffer <> char}

      _ ->
        state
    end
  end

  @doc """
  Gets a command from history by index.
  """
  def get_history_command(%__MODULE__{} = state, index) when is_integer(index) do
    if index >= 0 and index < length(state.command_history) do
      {:ok, Enum.at(state.command_history, index)}
    else
      {:error, :invalid_index}
    end
  end

  @doc """
  Searches command history for a matching command.
  """
  def search_history(%__MODULE__{} = state, pattern) when is_binary(pattern) do
    matches = Enum.filter(state.command_history, &String.contains?(&1, pattern))
    if Enum.empty?(matches), do: {:error, :not_found}, else: {:ok, matches}
  end
end
