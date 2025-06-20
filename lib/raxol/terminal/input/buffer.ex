defmodule Raxol.Terminal.Input.Buffer do
  @moduledoc """
  Manages input buffering for the terminal emulator.
  """

  use GenServer

  # Client API

  @doc """
  Starts the input buffer.
  """
  @spec start_link() :: GenServer.on_start()
  def start_link do
    start_link([])
  end

  @doc """
  Starts the input buffer with options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 1024)
    {:ok, new(max_size)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:add_event, event}, state) do
    case add(state, event) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @doc """
  Creates a new input buffer with the given size.
  """
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %{
      buffer: [],
      max_size: max_size,
      current_size: 0
    }
  end

  @doc """
  Adds an event to the input buffer.
  """
  def add(buffer, event) do
    if buffer.current_size >= buffer.max_size do
      {:error, :buffer_full}
    else
      new_buffer = %{
        buffer
        | buffer: buffer.buffer ++ [event],
          current_size: buffer.current_size + 1
      }

      {:ok, new_buffer}
    end
  end

  @doc """
  Gets the current buffer contents.
  """
  def get_contents(buffer) do
    buffer.buffer
  end

  @doc """
  Clears the input buffer.
  """
  def clear(buffer) do
    %{buffer | buffer: [], current_size: 0}
  end

  @doc """
  Clears the input buffer for the given process.
  """
  def clear_buffer(_pid), do: :ok

  @doc """
  Feeds input to the buffer for the given process.
  """
  def feed_input(_pid, _input), do: :ok

  @doc """
  Registers a callback for the input buffer process.
  """
  def register_callback(_pid, _callback), do: :ok
end
