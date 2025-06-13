defmodule Raxol.Terminal.Command.Manager do
  @moduledoc """
  Manages terminal command execution and state.
  Handles command history, execution, and command-related operations.
  """

  use GenServer
  require Logger

  # Types
  @type command :: String.t()
  @type command_history :: [command()]
  @type command_state :: :idle | :running | :completed | :error
  @type key_event :: term()

  @type t :: %__MODULE__{
    command_buffer: String.t(),
    command_history: command_history(),
    last_key_event: key_event() | nil,
    current_command: command() | nil,
    status: command_state(),
    max_history_size: non_neg_integer()
  }

  defstruct [
    command_buffer: "",
    command_history: [],
    last_key_event: nil,
    current_command: nil,
    status: :idle,
    max_history_size: 1000
  ]

  @doc """
  Creates a new command manager instance with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_history_size: Keyword.get(opts, :max_history_size, 1000)
    }
  end

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current command buffer.
  """
  def get_command_buffer do
    GenServer.call(__MODULE__, :get_command_buffer)
  end

  @doc """
  Updates the command buffer.
  """
  def update_command_buffer(buffer) when is_binary(buffer) do
    GenServer.call(__MODULE__, {:update_command_buffer, buffer})
  end

  @doc """
  Gets the command history.
  """
  def get_command_history do
    GenServer.call(__MODULE__, :get_command_history)
  end

  @doc """
  Adds a command to the history.
  """
  def add_to_history(command) when is_binary(command) do
    GenServer.call(__MODULE__, {:add_to_history, command})
  end

  @doc """
  Clears the command history.
  """
  def clear_history do
    GenServer.call(__MODULE__, :clear_history)
  end

  @doc """
  Gets the last key event.
  """
  def get_last_key_event do
    GenServer.call(__MODULE__, :get_last_key_event)
  end

  @doc """
  Updates the last key event.
  """
  def update_last_key_event(event) do
    GenServer.call(__MODULE__, {:update_last_key_event, event})
  end

  @doc """
  Processes a key event.
  """
  def process_key_event(event) do
    GenServer.call(__MODULE__, {:process_key_event, event})
  end

  @doc """
  Gets a command from history by index.
  """
  def get_history_command(index) when is_integer(index) do
    GenServer.call(__MODULE__, {:get_history_command, index})
  end

  @doc """
  Searches the command history for a substring.
  """
  def search_history(prefix) when is_binary(prefix) do
    GenServer.call(__MODULE__, {:search_history, prefix})
  end

  @doc """
  Executes a command.
  """
  def execute_command(command) when is_binary(command) do
    GenServer.call(__MODULE__, {:execute_command, command})
  end

  @doc """
  Gets the current command status.
  """
  def get_command_status do
    GenServer.call(__MODULE__, :get_command_status)
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    state = %__MODULE__{
      max_history_size: Keyword.get(opts, :max_history_size, 1000)
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:get_command_buffer, _from, state) do
    {:reply, state.command_buffer, state}
  end

  @impl true
  def handle_call({:update_command_buffer, buffer}, _from, state) do
    {:reply, :ok, %{state | command_buffer: buffer}}
  end

  @impl true
  def handle_call(:get_command_history, _from, state) do
    {:reply, state.command_history, state}
  end

  @impl true
  def handle_call({:add_to_history, command}, _from, state) do
    new_history = [command | state.command_history] |> Enum.take(state.max_history_size)
    {:reply, :ok, %{state | command_history: new_history}}
  end

  @impl true
  def handle_call(:clear_history, _from, state) do
    {:reply, :ok, %{state | command_history: []}}
  end

  @impl true
  def handle_call(:get_last_key_event, _from, state) do
    {:reply, state.last_key_event, state}
  end

  @impl true
  def handle_call({:update_last_key_event, event}, _from, state) do
    {:reply, :ok, %{state | last_key_event: event}}
  end

  @impl true
  def handle_call({:process_key_event, event}, _from, state) do
    # Here you would implement actual key event processing logic
    # For now, we'll just update the last key event
    {:reply, :ok, %{state | last_key_event: event}}
  end

  @impl true
  def handle_call({:get_history_command, index}, _from, state) do
    result = Enum.at(state.command_history, index)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:search_history, prefix}, _from, state) do
    matches = Enum.filter(state.command_history, &String.starts_with?(&1, prefix))
    {:reply, matches, state}
  end

  @impl true
  def handle_call({:execute_command, command}, _from, state) do
    # Here you would implement actual command execution
    # For now, we'll just update the state
    new_state = %{state |
      current_command: command,
      status: :running,
      command_history: [command | state.command_history] |> Enum.take(state.max_history_size)
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_command_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end
end
