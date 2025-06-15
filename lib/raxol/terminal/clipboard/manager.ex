defmodule Raxol.Terminal.Clipboard.Manager do
  @moduledoc """
  Manages clipboard operations for the terminal.
  """

  use GenServer

  alias Raxol.Terminal.Clipboard.{History, Store, Format, Sync}

  defstruct [:history, :store, :sync]

  @type t :: %__MODULE__{
          history: History.t(),
          store: Store.t(),
          sync: Sync.t()
        }

  # Client API

  @doc """
  Starts the clipboard manager.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Copies content to the clipboard.
  """
  @spec copy(String.t(), String.t()) :: :ok
  def copy(content, format) do
    GenServer.cast(__MODULE__, {:copy, content, format})
  end

  @doc """
  Pastes content from the clipboard.
  """
  @spec paste(String.t()) :: {:ok, String.t()} | {:error, :empty_clipboard}
  def paste(format) do
    GenServer.call(__MODULE__, {:paste, format})
  end

  @doc """
  Clears the clipboard.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # 1 hour in milliseconds
    _max_age = Keyword.get(opts, :max_age, 3_600_000)
    history_size = Keyword.get(opts, :history_size, 10)

    state = %__MODULE__{
      history: History.new(history_size),
      store: Store.new("", "text"),
      sync: Sync.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:copy, content, format}, state) do
    store = Store.new(content, format)
    history = History.add(state.history, content, format)
    Sync.broadcast(state.sync, content, format)

    {:noreply, %{state | store: store, history: history}}
  end

  @impl true
  def handle_cast(:clear, state) do
    store = Store.new("", "text")
    history = History.clear(state.history)

    {:noreply, %{state | store: store, history: history}}
  end

  @impl true
  def handle_call({:paste, format}, _from, state) do
    case Store.get_content(state.store) do
      "" ->
        {:reply, {:error, :empty_clipboard}, state}

      content ->
        case Format.apply_filter(format, content, Store.get_format(state.store)) do
          {:ok, formatted_content} -> {:reply, {:ok, formatted_content}, state}
          {:error, _} -> {:reply, {:error, :invalid_format}, state}
        end
    end
  end
end
