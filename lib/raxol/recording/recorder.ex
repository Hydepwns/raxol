defmodule Raxol.Recording.Recorder do
  @moduledoc """
  GenServer that captures terminal output during a live Raxol session.

  Registers itself as `Raxol.Recording.Recorder` so the rendering engine
  can send output frames via `record_output/2`. Accumulates timestamped
  events for later serialization.

  ## Usage

      {:ok, pid} = Recorder.start_link(title: "My Demo")
      # ... run app, output is captured automatically ...
      session = Recorder.stop(pid)
      Asciicast.write!(session, "demo.cast")
  """

  use GenServer

  alias Raxol.Recording.Session

  # -- Client API --

  @doc "Starts the recorder and registers it."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Records an output frame. Called by the rendering engine."
  @spec record_output(pid() | atom(), binary()) :: :ok
  def record_output(pid \\ __MODULE__, data) when is_binary(data) do
    GenServer.cast(pid, {:output, data})
  end

  @doc "Stops recording and returns the completed session."
  @spec stop(pid() | atom()) :: Session.t()
  def stop(pid \\ __MODULE__) do
    GenServer.call(pid, :stop)
  end

  @doc "Returns the current session (without stopping)."
  @spec get_session(pid() | atom()) :: Session.t()
  def get_session(pid \\ __MODULE__) do
    GenServer.call(pid, :get_session)
  end

  @doc "Checks if a recorder is currently active."
  @spec active?() :: boolean()
  def active? do
    Process.whereis(__MODULE__) != nil
  end

  # -- Server --

  @impl true
  def init(opts) do
    session = Session.new(opts)
    start_mono = System.monotonic_time(:microsecond)

    {:ok, %{session: session, start_mono: start_mono}}
  end

  @impl true
  def handle_cast({:output, data}, state) do
    elapsed = System.monotonic_time(:microsecond) - state.start_mono
    event = {elapsed, :output, data}
    session = %{state.session | events: state.session.events ++ [event]}
    {:noreply, %{state | session: session}}
  end

  @impl true
  def handle_call(:get_session, _from, state) do
    {:reply, state.session, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    session = %{state.session | ended_at: DateTime.utc_now()}
    {:stop, :normal, session, state}
  end
end
