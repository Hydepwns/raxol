defmodule Raxol.Terminal.Emulator.Server do
  @moduledoc """
  GenServer implementation for the Terminal Emulator.
  
  Handles asynchronous terminal operations and maintains terminal state.
  """
  
  use GenServer
  require Logger
  
  alias Raxol.Terminal.Emulator
  
  ## Client API (delegated from Emulator module)
  
  def start_link({initial_state, opts}) do
    GenServer.start_link(__MODULE__, {initial_state, opts})
  end
  
  ## GenServer Callbacks
  
  @impl GenServer
  def init({initial_state, opts}) do
    # Set up any necessary process flags
    Process.flag(:trap_exit, true)
    
    # Log initialization
    Logger.debug("Terminal emulator server started with dimensions #{initial_state.width}x#{initial_state.height}")
    
    # Initialize state with any runtime configuration
    state = %{
      emulator: initial_state,
      opts: opts,
      session_id: Keyword.get(opts, :session_id, generate_session_id()),
      started_at: System.system_time(:millisecond)
    }
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call({:write, data}, _from, %{emulator: emulator} = state) do
    case Emulator.write_text(emulator, data) do
      {:ok, new_emulator} ->
        {:reply, :ok, %{state | emulator: new_emulator}}
      error ->
        {:reply, error, state}
    end
  end
  
  @impl GenServer
  def handle_call({:resize, width, height}, _from, %{emulator: emulator} = state) do
    case Emulator.resize(emulator, width, height) do
      {:ok, new_emulator} ->
        {:reply, :ok, %{state | emulator: new_emulator}}
      error ->
        {:reply, error, state}
    end
  end
  
  @impl GenServer
  def handle_call(:get_state, _from, %{emulator: emulator} = state) do
    {:reply, {:ok, emulator}, state}
  end
  
  @impl GenServer
  def handle_call(:get_cursor_position, _from, %{emulator: emulator} = state) do
    position = Emulator.get_cursor_position(emulator)
    {:reply, {:ok, position}, state}
  end
  
  @impl GenServer
  def handle_call({:set_cursor_position, x, y}, _from, %{emulator: emulator} = state) do
    new_emulator = Emulator.set_cursor_position(emulator, x, y)
    {:reply, :ok, %{state | emulator: new_emulator}}
  end
  
  @impl GenServer
  def handle_call(:get_buffer, _from, %{emulator: emulator} = state) do
    buffer = Emulator.get_screen_buffer(emulator)
    {:reply, {:ok, buffer}, state}
  end
  
  @impl GenServer
  def handle_call(:clear, _from, %{emulator: emulator} = state) do
    new_emulator = Emulator.clear_screen(emulator)
    {:reply, :ok, %{state | emulator: new_emulator}}
  end
  
  @impl GenServer
  def handle_call({:handle_input, input}, _from, %{emulator: emulator} = state) do
    case Emulator.process_input(emulator, input) do
      {new_emulator, _output} ->
        {:reply, :ok, %{state | emulator: new_emulator}}
      error ->
        {:reply, error, state}
    end
  end
  
  @impl GenServer
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :not_implemented}, state}
  end
  
  @impl GenServer
  def handle_cast({:write_async, data}, %{emulator: emulator} = state) do
    case Emulator.write_text(emulator, data) do
      {:ok, new_emulator} ->
        {:noreply, %{state | emulator: new_emulator}}
      _error ->
        {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_cast(request, state) do
    Logger.warning("Unhandled cast: #{inspect(request)}")
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.info("Terminal emulator server received EXIT signal: #{inspect(reason)}")
    {:stop, reason, state}
  end
  
  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Terminal emulator server received info: #{inspect(msg)}")
    {:noreply, state}
  end
  
  @impl GenServer
  def terminate(reason, %{session_id: session_id}) do
    Logger.info("Terminal emulator server #{session_id} terminating: #{inspect(reason)}")
    :ok
  end
  
  ## Private Functions
  
  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end