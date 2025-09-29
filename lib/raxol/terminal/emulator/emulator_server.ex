defmodule Raxol.Terminal.Emulator.EmulatorServer do
  @moduledoc """
  GenServer implementation for the Terminal Emulator.

  Handles asynchronous terminal operations and maintains terminal state.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  alias Raxol.Terminal.Emulator

  ## Client API
  # Use BaseManager's start_link - it accepts keyword list options
  # Callers need to pass initial_emulator as part of options

  ## BaseManager Callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    # Set up any necessary process flags
    Process.flag(:trap_exit, true)

    initial_emulator = Keyword.get(opts, :initial_emulator)
    session_id = Keyword.get(opts, :session_id, generate_session_id())

    # Log initialization if we have an emulator
    case initial_emulator do
      nil ->
        Logger.debug("Terminal emulator server started without initial state")
      emulator ->
        Logger.debug(
          "Terminal emulator server started with dimensions #{emulator.width}x#{emulator.height}"
        )
    end

    # Initialize state with any runtime configuration
    state = %{
      emulator: initial_emulator,
      opts: Keyword.drop(opts, [:initial_emulator, :session_id, :name]),
      session_id: session_id,
      started_at: System.system_time(:millisecond)
    }

    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:write, data}, _from, %{emulator: emulator} = state) do
    case Emulator.write_text(emulator, data) do
      {:ok, new_emulator} ->
        {:reply, :ok, %{state | emulator: new_emulator}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_manager_call(
        {:resize, width, height},
        _from,
        %{emulator: emulator} = state
      ) do
    case Emulator.resize(emulator, width, height) do
      {:ok, new_emulator} ->
        {:reply, :ok, %{state | emulator: new_emulator}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_manager_call(:get_state, _from, %{emulator: emulator} = state) do
    {:reply, {:ok, emulator}, state}
  end

  def handle_manager_call(:get_cursor_position, _from, %{emulator: emulator} = state) do
    position = Emulator.get_cursor_position(emulator)
    {:reply, {:ok, position}, state}
  end

  def handle_manager_call(
        {:set_cursor_position, x, y},
        _from,
        %{emulator: emulator} = state
      ) do
    new_emulator = Emulator.set_cursor_position(emulator, x, y)
    {:reply, :ok, %{state | emulator: new_emulator}}
  end

  def handle_manager_call(:get_buffer, _from, %{emulator: emulator} = state) do
    buffer = Emulator.get_screen_buffer(emulator)
    {:reply, {:ok, buffer}, state}
  end

  def handle_manager_call(:clear, _from, %{emulator: emulator} = state) do
    new_emulator = Emulator.clear_screen(emulator)
    {:reply, :ok, %{state | emulator: new_emulator}}
  end

  def handle_manager_call({:handle_input, input}, _from, %{emulator: emulator} = state) do
    case Emulator.process_input(emulator, input) do
      {new_emulator, _output} ->
        {:reply, :ok, %{state | emulator: new_emulator}}

      error ->
        {:reply, error, state}
    end
  end

  # Catch-all is handled by BaseManager's default implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:write_async, data}, %{emulator: emulator} = state) do
    case Emulator.write_text(emulator, data) do
      {:ok, new_emulator} ->
        {:noreply, %{state | emulator: new_emulator}}

      _error ->
        {:noreply, state}
    end
  end

  # Catch-all is handled by BaseManager's default implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:EXIT, _pid, reason}, state) do
    Logger.info(
      "Terminal emulator server received EXIT signal: #{inspect(reason)}"
    )

    {:stop, reason, state}
  end

  # Other info messages handled by BaseManager's default implementation

  @impl GenServer
  def terminate(reason, %{session_id: session_id}) do
    Logger.info(
      "Terminal emulator server #{session_id} terminating: #{inspect(reason)}"
    )

    :ok
  end

  ## Private Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
