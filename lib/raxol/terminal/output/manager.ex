defmodule Raxol.Terminal.Output.Manager do
  @moduledoc """
  Manages terminal output and control sequences.
  Handles buffering, flushing, and processing of output data.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enqueue_output(pid \\ __MODULE__, data) do
    GenServer.call(pid, {:enqueue_output, data})
  end

  def flush_output(pid \\ __MODULE__) do
    GenServer.call(pid, :flush_output)
  end

  def clear_output_buffer(pid \\ __MODULE__) do
    GenServer.call(pid, :clear_output_buffer)
  end

  def get_output_buffer(pid \\ __MODULE__) do
    GenServer.call(pid, :get_output_buffer)
  end

  def enqueue_control_sequence(pid \\ __MODULE__, sequence) do
    GenServer.call(pid, {:enqueue_control_sequence, sequence})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      output_buffer: [],
      control_sequences: [],
      buffer_size: 0,
      max_buffer_size: 1024 * 1024  # 1MB default buffer size
    }}
  end

  @impl true
  def handle_call({:enqueue_output, data}, _from, state) do
    new_buffer = [data | state.output_buffer]
    new_size = state.buffer_size + byte_size(data)

    if new_size > state.max_buffer_size do
      {:reply, {:error, :buffer_full}, state}
    else
      {:reply, :ok, %{state | output_buffer: new_buffer, buffer_size: new_size}}
    end
  end

  @impl true
  def handle_call(:flush_output, _from, state) do
    output = state.output_buffer
             |> Enum.reverse()
             |> Enum.join()

    {:reply, {:ok, output}, %{state | output_buffer: [], buffer_size: 0}}
  end

  @impl true
  def handle_call(:clear_output_buffer, _from, state) do
    {:reply, :ok, %{state | output_buffer: [], buffer_size: 0}}
  end

  @impl true
  def handle_call(:get_output_buffer, _from, state) do
    output = state.output_buffer
             |> Enum.reverse()
             |> Enum.join()

    {:reply, output, state}
  end

  @impl true
  def handle_call({:enqueue_control_sequence, sequence}, _from, state) do
    new_sequences = [sequence | state.control_sequences]
    {:reply, :ok, %{state | control_sequences: new_sequences}}
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end
end
