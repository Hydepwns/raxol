defmodule Raxol.Terminal.Command.Manager do
  use GenServer
  require Logger

  @moduledoc """
  Manages terminal command state, history, and execution.
  """

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

  def new(opts \\ []) do
    %{
      commands: %{},
      history: [],
      current_command: nil,
      status: :idle,
      error: nil
    }
  end

  def execute_command(pid \\ __MODULE__, command) do
    GenServer.call(pid, {:execute_command, command})
  end

  def get_command_history(manager \\ %__MODULE__{}) do
    GenServer.call(manager, :get_command_history)
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

  def get_command_buffer(manager \\ %__MODULE__{}) do
    GenServer.call(manager, :get_command_buffer)
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

  @impl true
  def init(opts) do
    state = new(opts)
    {:ok, state}
  end

  @impl true
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

  @impl true
  def handle_call(:get_command_history, _from, state) do
    {:reply, state.history, state}
  end

  @impl true
  def handle_call(:clear_command_history, _from, state) do
    new_state = %{state | history: []}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_current_command, _from, state) do
    {:reply, state.current_command, state}
  end

  @impl true
  def handle_call({:set_current_command, command}, _from, state) do
    new_state = %{state | current_command: command}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_command_buffer, _from, state) do
    {:reply, state.command_buffer, state}
  end

  @impl true
  def handle_call(:clear_command_buffer, _from, state) do
    new_state = %{state | command_buffer: []}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_command_state, _from, state) do
    {:reply, state.command_state, state}
  end

  @impl true
  def handle_call({:set_command_state, new_state}, _from, state) do
    new_state = %{state | command_state: new_state}
    {:reply, :ok, new_state}
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
  def update_command_buffer(%__MODULE__{} = state, new_buffer)
      when is_binary(new_buffer) do
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
    %{
      state
      | command_history: [command | state.command_history],
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
          %{
            state
            | command_buffer: String.slice(state.command_buffer, 0..-2//-1)
          }
        else
          state
        end

      {:key, :up} ->
        if state.history_index < length(state.command_history) - 1 do
          new_index = state.history_index + 1
          command = Enum.at(state.command_history, new_index)
          %{state | command_buffer: command, history_index: new_index}
        else
          state
        end

      {:key, :down} ->
        if state.history_index > -1 do
          new_index = state.history_index - 1

          command =
            if new_index == -1,
              do: "",
              else: Enum.at(state.command_history, new_index)

          %{state | command_buffer: command, history_index: new_index}
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
  def get_history_command(%__MODULE__{} = state, index)
      when is_integer(index) do
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
