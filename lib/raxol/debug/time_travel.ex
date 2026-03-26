defmodule Raxol.Debug.TimeTravel do
  @moduledoc """
  Time-travel debugger for TEA applications.

  Records a snapshot of the application model at every `update/2` cycle.
  Supports stepping forward and backward through state history, inspecting
  diffs between any two points, and restoring the live application to a
  historical state.

  ## Usage

  Enable via Lifecycle options:

      Raxol.start_link(MyApp, time_travel: true)
      Raxol.start_link(MyApp, time_travel: [max_snapshots: 2000])

  Or start standalone and attach to a running Dispatcher:

      {:ok, pid} = TimeTravel.start_link(dispatcher: dispatcher_pid)

  Then navigate:

      TimeTravel.step_back()     # -> {:ok, %Snapshot{}}
      TimeTravel.step_forward()  # -> {:ok, %Snapshot{}}
      TimeTravel.current()       # -> {:ok, %Snapshot{}}
      TimeTravel.jump_to(42)     # -> {:ok, %Snapshot{}}
      TimeTravel.restore()       # re-render the model at the cursor position
  """

  use GenServer

  alias Raxol.Debug.Snapshot

  @default_max_snapshots 1000

  defmodule State do
    @moduledoc false
    defstruct dispatcher: nil,
              buffer: nil,
              cursor: nil,
              next_index: 0,
              max_snapshots: 1000,
              paused: false
  end

  # -- Client API --

  @doc "Starts the time-travel debugger."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)
    server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @doc "Records a snapshot. Called by the Dispatcher after each update/2."
  @spec record(pid() | atom(), term(), map(), map()) :: :ok
  def record(pid \\ __MODULE__, message, model_before, model_after) do
    GenServer.cast(pid, {:record, message, model_before, model_after})
  end

  @doc "Returns the snapshot at the current cursor position."
  @spec current(pid() | atom()) :: {:ok, Snapshot.t()} | {:error, :empty}
  def current(pid \\ __MODULE__) do
    GenServer.call(pid, :current)
  end

  @doc "Steps the cursor back one snapshot."
  @spec step_back(pid() | atom()) :: {:ok, Snapshot.t()} | {:error, :at_start}
  def step_back(pid \\ __MODULE__) do
    GenServer.call(pid, :step_back)
  end

  @doc "Steps the cursor forward one snapshot."
  @spec step_forward(pid() | atom()) :: {:ok, Snapshot.t()} | {:error, :at_end}
  def step_forward(pid \\ __MODULE__) do
    GenServer.call(pid, :step_forward)
  end

  @doc "Jumps the cursor to a specific snapshot index."
  @spec jump_to(pid() | atom(), non_neg_integer()) ::
          {:ok, Snapshot.t()} | {:error, :not_found}
  def jump_to(pid \\ __MODULE__, index) do
    GenServer.call(pid, {:jump_to, index})
  end

  @doc """
  Restores the live application model to the snapshot at the current cursor.

  Sends `{:restore_model, model}` to the Dispatcher, which updates its state
  and triggers a re-render. Automatically pauses recording so the restore
  itself doesn't get recorded as a new snapshot.
  """
  @spec restore(pid() | atom()) :: :ok | {:error, :empty | :no_dispatcher}
  def restore(pid \\ __MODULE__) do
    GenServer.call(pid, :restore)
  end

  @doc "Resumes recording after a restore (recording pauses automatically on restore)."
  @spec resume(pid() | atom()) :: :ok
  def resume(pid \\ __MODULE__) do
    GenServer.cast(pid, :resume)
  end

  @doc "Pauses snapshot recording."
  @spec pause(pid() | atom()) :: :ok
  def pause(pid \\ __MODULE__) do
    GenServer.cast(pid, :pause)
  end

  @doc "Returns a list of snapshot summaries."
  @spec list_entries(pid() | atom()) :: [map()]
  def list_entries(pid \\ __MODULE__) do
    GenServer.call(pid, :list_entries)
  end

  @doc "Diffs two snapshots by index. Returns change list."
  @spec diff(pid() | atom(), non_neg_integer(), non_neg_integer()) ::
          {:ok, [Snapshot.change()]} | {:error, :not_found}
  def diff(pid \\ __MODULE__, index_a, index_b) do
    GenServer.call(pid, {:diff, index_a, index_b})
  end

  @doc "Returns the total number of recorded snapshots."
  @spec count(pid() | atom()) :: non_neg_integer()
  def count(pid \\ __MODULE__) do
    GenServer.call(pid, :count)
  end

  @doc "Clears all recorded snapshots."
  @spec clear(pid() | atom()) :: :ok
  def clear(pid \\ __MODULE__) do
    GenServer.cast(pid, :clear)
  end

  @doc "Exports snapshots to a file (Erlang term format)."
  @spec export(pid() | atom(), Path.t()) :: :ok | {:error, term()}
  def export(pid \\ __MODULE__, path) do
    GenServer.call(pid, {:export, path})
  end

  @doc "Imports snapshots from a file."
  @spec import_file(pid() | atom(), Path.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def import_file(pid \\ __MODULE__, path) do
    GenServer.call(pid, {:import, path})
  end

  # -- Server --

  @impl true
  def init(opts) do
    max = Keyword.get(opts, :max_snapshots, @default_max_snapshots)
    dispatcher = Keyword.get(opts, :dispatcher)

    state = %State{
      dispatcher: dispatcher,
      buffer: CircularBuffer.new(max),
      cursor: nil,
      next_index: 0,
      max_snapshots: max,
      paused: false
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(
        {:record, _message, _before, _after},
        %State{paused: true} = state
      ) do
    {:noreply, state}
  end

  def handle_cast(
        {:record, message, model_before, model_after},
        %State{} = state
      ) do
    snapshot =
      Snapshot.new(state.next_index, message, model_before, model_after)

    buffer = CircularBuffer.insert(state.buffer, snapshot)

    {:noreply,
     %{
       state
       | buffer: buffer,
         next_index: state.next_index + 1,
         cursor: state.next_index
     }}
  end

  def handle_cast(:resume, state) do
    {:noreply, %{state | paused: false}}
  end

  def handle_cast(:pause, state) do
    {:noreply, %{state | paused: true}}
  end

  def handle_cast({:set_dispatcher, pid}, state) when is_pid(pid) do
    {:noreply, %{state | dispatcher: pid}}
  end

  def handle_cast(:clear, state) do
    {:noreply,
     %{
       state
       | buffer: CircularBuffer.new(state.max_snapshots),
         cursor: nil,
         next_index: 0
     }}
  end

  @impl true
  def handle_call(:current, _from, state) do
    case find_by_index(state, state.cursor) do
      nil -> {:reply, {:error, :empty}, state}
      snap -> {:reply, {:ok, snap}, state}
    end
  end

  def handle_call(:step_back, _from, state) do
    case find_by_index(state, state.cursor) do
      nil ->
        {:reply, {:error, :at_start}, state}

      snap ->
        prev_index = snap.index - 1

        case find_by_index(state, prev_index) do
          nil -> {:reply, {:error, :at_start}, state}
          prev -> {:reply, {:ok, prev}, %{state | cursor: prev_index}}
        end
    end
  end

  def handle_call(:step_forward, _from, state) do
    case state.cursor do
      nil ->
        {:reply, {:error, :at_end}, state}

      cursor ->
        next_index = cursor + 1

        case find_by_index(state, next_index) do
          nil -> {:reply, {:error, :at_end}, state}
          snap -> {:reply, {:ok, snap}, %{state | cursor: next_index}}
        end
    end
  end

  def handle_call({:jump_to, index}, _from, state) do
    case find_by_index(state, index) do
      nil -> {:reply, {:error, :not_found}, state}
      snap -> {:reply, {:ok, snap}, %{state | cursor: index}}
    end
  end

  def handle_call(:restore, _from, %State{dispatcher: nil} = state) do
    {:reply, {:error, :no_dispatcher}, state}
  end

  def handle_call(:restore, _from, state) do
    case find_by_index(state, state.cursor) do
      nil ->
        {:reply, {:error, :empty}, state}

      snap ->
        GenServer.cast(state.dispatcher, {:restore_model, snap.model_after})
        {:reply, :ok, %{state | paused: true}}
    end
  end

  def handle_call(:list_entries, _from, state) do
    entries =
      state.buffer
      |> CircularBuffer.to_list()
      |> Enum.map(fn snap ->
        %{
          index: snap.index,
          summary: Snapshot.summary(snap),
          changed: Snapshot.changed?(snap),
          timestamp_us: snap.timestamp_us
        }
      end)

    {:reply, entries, state}
  end

  def handle_call({:diff, index_a, index_b}, _from, state) do
    with snap_a when not is_nil(snap_a) <- find_by_index(state, index_a),
         snap_b when not is_nil(snap_b) <- find_by_index(state, index_b) do
      {:reply, {:ok, Snapshot.diff(snap_a, snap_b)}, state}
    else
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:count, _from, state) do
    {:reply, state.buffer.count, state}
  end

  def handle_call({:export, path}, _from, state) do
    snapshots = CircularBuffer.to_list(state.buffer)
    binary = :erlang.term_to_binary(snapshots)

    case File.write(path, binary) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:import, path}, _from, state) do
    with {:ok, binary} <- File.read(path),
         snapshots when is_list(snapshots) <- safe_binary_to_term(binary) do
      buffer =
        Enum.reduce(snapshots, CircularBuffer.new(state.max_snapshots), fn snap,
                                                                           buf ->
          CircularBuffer.insert(buf, snap)
        end)

      last_index =
        case List.last(snapshots) do
          %Snapshot{index: i} -> i
          _ -> 0
        end

      new_state = %{
        state
        | buffer: buffer,
          cursor: last_index,
          next_index: last_index + 1
      }

      {:reply, {:ok, length(snapshots)}, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
      _ -> {:reply, {:error, :invalid_format}, state}
    end
  end

  # -- Private --

  defp find_by_index(_state, nil), do: nil

  defp find_by_index(state, index) do
    state.buffer
    |> CircularBuffer.to_list()
    |> Enum.find(fn snap -> snap.index == index end)
  end

  defp safe_binary_to_term(binary) do
    :erlang.binary_to_term(binary)
  rescue
    ArgumentError -> {:error, :corrupt_data}
  end
end
