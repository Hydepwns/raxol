defmodule Raxol.Terminal.Command.Manager do
  use GenServer
  require Logger

  @moduledoc """
  Manages terminal command processing and execution.
  This module is responsible for handling command parsing, validation, and execution.
  """

  import Raxol.Guards
  alias Raxol.Terminal.{Emulator, Command}
  require Raxol.Core.Runtime.Log

  defstruct command_buffer: "",
            command_history: [],
            last_key_event: nil,
            history_index: -1

  @type t :: %__MODULE__{
          command_buffer: String.t(),
          command_history: [String.t()],
          last_key_event: term(),
          history_index: integer()
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new command manager.
  """
  @spec new() :: Command.t()
  def new do
    %Command{
      history: [],
      current: nil,
      max_history: 100
    }
  end

  @doc """
  Creates a new command manager with options.
  """
  @spec new(keyword()) :: Command.t()
  def new(opts) do
    max_history = Keyword.get(opts, :max_command_history, 100)

    %Command{
      history: [],
      current: nil,
      max_history: max_history,
      command_buffer: "",
      history_index: -1,
      last_key_event: nil,
      command_state: nil
    }
  end

  def execute_command(pid \\ __MODULE__, command) do
    GenServer.call(pid, {:execute_command, command})
  end

  def get_command_history(manager \\ %Raxol.Terminal.Command{})

  def get_command_history(%Raxol.Terminal.Command{} = state) do
    state.history
  end

  def get_command_history(pid) do
    GenServer.call(pid, :get_command_history)
  end

  def add_to_history(pid, command) when binary?(command) do
    GenServer.call(pid, {:add_to_history, command})
  end

  def clear_command_history(pid \\ __MODULE__) do
    GenServer.call(pid, :clear_command_history)
  end

  def get_current_command(pid \\ __MODULE__) do
    GenServer.call(pid, :get_current_command)
  end

  def set_current_command(pid \\ __MODULE__, command) do
    GenServer.call(pid, {:set_current_command, command})
  end

  def get_command_buffer(manager \\ %Raxol.Terminal.Command{})

  def get_command_buffer(%Raxol.Terminal.Command{} = state) do
    state.command_buffer
  end

  def get_command_buffer(pid) do
    GenServer.call(pid, :get_command_buffer)
  end

  def clear_command_buffer(pid \\ __MODULE__) do
    GenServer.call(pid, :clear_command_buffer)
  end

  def get_command_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_command_state)
  end

  def set_command_state(pid \\ __MODULE__, state) do
    GenServer.call(pid, {:set_command_state, state})
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(opts) do
    state = new(opts)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute_command, command}, _from, state) do
    case Map.get(state.commands, command) do
      nil ->
        {:reply, {:error, :command_not_found}, state}

      command_fn ->
        result = command_fn.()

        new_history = [
          command | Enum.take(state.history, state.max_history - 1)
        ]

        new_state = %{state | history: new_history}
        {:reply, {:ok, result}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_command_history, _from, state) do
    {:reply, state.history, state}
  end

  @impl GenServer
  def handle_call({:add_to_history, command}, _from, state)
      when binary?(command) do
    new_state = add_to_history_state(state, command)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:clear_command_history, _from, state) do
    new_state = %{state | history: [], history_index: -1}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_current_command, _from, state) do
    {:reply, state.current_command, state}
  end

  @impl GenServer
  def handle_call({:set_current_command, command}, _from, state) do
    new_state = %{state | current_command: command}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_command_buffer, _from, state) do
    {:reply, state.command_buffer, state}
  end

  @impl GenServer
  def handle_call(:clear_command_buffer, _from, state) do
    new_state = %{state | command_buffer: []}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_command_state, _from, state) do
    {:reply, state.command_state, state}
  end

  @impl GenServer
  def handle_call({:set_command_state, new_state}, _from, state) do
    new_state = %{state | command_state: new_state}
    {:reply, :ok, new_state}
  end

  @doc """
  Updates the command buffer.
  """
  def update_command_buffer(%Raxol.Terminal.Command{} = state, new_buffer)
      when binary?(new_buffer) do
    %{state | command_buffer: new_buffer}
  end

  @doc """
  Adds a command to the history.
  """
  def add_to_history_state(%Raxol.Terminal.Command{} = state, command)
      when binary?(command) do
    new_history = state.history ++ [command]
    max_history = state.max_history || 100

    trimmed_history =
      if length(new_history) > max_history do
        Enum.slice(new_history, -max_history, max_history)
      else
        new_history
      end

    %{
      state
      | history: trimmed_history,
        history_index: -1
    }
  end

  @doc """
  Clears the command history.
  """
  def clear_history(%Raxol.Terminal.Command{} = state) do
    %{state | history: [], history_index: -1}
  end

  @doc """
  Gets the last key event.
  """
  def get_last_key_event(%Raxol.Terminal.Command{} = state) do
    state.last_key_event
  end

  @doc """
  Updates the last key event.
  """
  def update_last_key_event(%Raxol.Terminal.Command{} = state, event) do
    %{state | last_key_event: event}
  end

  @doc """
  Processes a key event and updates the command buffer accordingly.
  """
  def process_key_event(%Raxol.Terminal.Command{} = state, {:key, :enter}),
    do: handle_enter(state)

  def process_key_event(%Raxol.Terminal.Command{} = state, {:key, :backspace}),
    do: handle_backspace(state)

  def process_key_event(%Raxol.Terminal.Command{} = state, {:key, :up}),
    do: handle_up(state)

  def process_key_event(%Raxol.Terminal.Command{} = state, {:key, :down}),
    do: handle_down(state)

  def process_key_event(%Raxol.Terminal.Command{} = state, {:char, char}),
    do: handle_char(state, char)

  def process_key_event(state, _), do: state

  defp handle_enter(state) do
    if state.command_buffer != "" do
      state = add_to_history_state(state, state.command_buffer)
      %{state | command_buffer: ""}
    else
      state
    end
  end

  defp handle_backspace(state) do
    if state.command_buffer != "" do
      %{state | command_buffer: String.slice(state.command_buffer, 0..-2//-1)}
    else
      state
    end
  end

  defp handle_up(state) do
    if state.history_index < length(state.history) - 1 do
      new_index = state.history_index + 1
      command = Enum.at(state.history, new_index)
      %{state | command_buffer: command, history_index: new_index}
    else
      state
    end
  end

  defp handle_down(state) do
    if state.history_index > -1 do
      new_index = state.history_index - 1

      command =
        case new_index do
          -1 -> ""
          _ -> Enum.at(state.history, new_index)
        end

      %{state | command_buffer: command, history_index: new_index}
    else
      state
    end
  end

  defp handle_char(state, char),
    do: %{state | command_buffer: state.command_buffer <> char}

  @doc """
  Gets a command from history by index.
  """
  def get_history_command(%Raxol.Terminal.Command{} = state, index)
      when integer?(index) do
    if index >= 0 and index < length(state.history) do
      {:ok, Enum.at(state.history, index)}
    else
      {:error, :invalid_index}
    end
  end

  @doc """
  Searches command history for a matching command.
  """
  def search_history(%Raxol.Terminal.Command{} = state, pattern)
      when binary?(pattern) do
    matches = Enum.filter(state.history, &String.contains?(&1, pattern))
    if Enum.empty?(matches), do: {:error, :not_found}, else: {:ok, matches}
  end

  @doc """
  Processes a command string.
  Returns the updated emulator and any output.
  """
  @spec process_command(Emulator.t(), String.t()) :: {Emulator.t(), any()}
  def process_command(emulator, command) do
    case parse_command(command) do
      {:ok, parsed_command} ->
        execute_command_internal(emulator, parsed_command)

      {:error, reason} ->
        {emulator, {:error, reason}}
    end
  end

  @doc """
  Gets the current command.
  Returns the current command or nil.
  """
  @spec get_current(Emulator.t()) :: String.t() | nil
  def get_current(emulator) do
    emulator.command.current
  end

  @doc """
  Sets the current command.
  Returns the updated emulator.
  """
  @spec set_current(Emulator.t(), String.t()) :: Emulator.t()
  def set_current(emulator, command) do
    %{emulator | command: %{emulator.command | current: command}}
  end

  # Private helper functions

  defp parse_command(command) when binary?(command) do
    # Split command into name and arguments
    [cmd | args] = String.split(command)
    {:ok, {cmd, args}}
  rescue
    _ -> {:error, :invalid_command}
  end

  defp execute_command_internal(emulator, {"clear", _args}) do
    # Example: clear command
    # You would call the actual clear logic here
    {emulator, :cleared}
  end

  defp execute_command_internal(emulator, {"echo", args}) do
    # Example: echo command
    output = Enum.join(args, " ")
    {emulator, output}
  end

  defp execute_command_internal(emulator, {cmd, _args}) do
    # Unknown command
    {emulator, {:error, {:unknown_command, cmd}}}
  end
end

defmodule Command.Manager do
  def new, do: :ok
end
