defmodule Raxol.Terminal.ANSI.Monitor do
  @moduledoc """
  Provides monitoring capabilities for the ANSI handling system.
  Tracks performance metrics, errors, and sequence statistics.
  """

  use GenServer
  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.{Parser, Processor}

  # --- Types ---

  @type metrics :: %{
          total_sequences: non_neg_integer(),
          total_bytes: non_neg_integer(),
          sequence_types: %{atom() => non_neg_integer()},
          errors: list({DateTime.t(), String.t(), map()}),
          performance: %{
            parse_time_ms: float(),
            process_time_ms: float(),
            total_time_ms: float()
          }
        }

  # --- Client API ---

  @doc """
  Starts the ANSI monitor process.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records the processing of an ANSI sequence.
  """
  @spec record_sequence(String.t()) :: :ok
  def record_sequence(input) do
    GenServer.cast(__MODULE__, {:record_sequence, input})
  end

  @doc """
  Records an error in ANSI sequence processing.
  """
  @spec record_error(String.t(), String.t(), map()) :: :ok
  def record_error(input, reason, context) do
    GenServer.cast(__MODULE__, {:record_error, input, reason, context})
  end

  @doc """
  Gets the current metrics.
  """
  @spec get_metrics() :: metrics()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Resets the metrics.
  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    GenServer.cast(__MODULE__, :reset_metrics)
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(_opts) do
    {:ok, initial_state()}
  end

  @impl GenServer
  def handle_cast({:record_sequence, input}, state) do
    {parse_time, parsed} = :timer.tc(Parser, :parse, [input])
    {process_time, _} = :timer.tc(Processor, :process_sequences, [parsed])

    new_state =
      state
      |> update_sequence_count(parsed)
      |> update_byte_count(input)
      |> update_sequence_types(parsed)
      |> update_performance(parse_time, process_time)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:record_error, _input, reason, context}, state) do
    error = {DateTime.utc_now(), reason, context}
    new_state = %{state | errors: [error | state.errors]}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:reset_metrics, _state) do
    {:noreply, initial_state()}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    {:reply, state, state}
  end

  # --- Private Implementation ---

  defp initial_state do
    %{
      total_sequences: 0,
      total_bytes: 0,
      sequence_types: %{},
      errors: [],
      performance: %{
        parse_time_ms: 0.0,
        process_time_ms: 0.0,
        total_time_ms: 0.0
      }
    }
  end

  defp update_sequence_count(state, sequences) do
    %{state | total_sequences: state.total_sequences + length(sequences)}
  end

  defp update_byte_count(state, input) do
    %{state | total_bytes: state.total_bytes + byte_size(input)}
  end

  defp update_sequence_types(state, sequences) do
    new_types =
      Enum.reduce(sequences, state.sequence_types, fn seq, types ->
        Map.update(types, seq.type, 1, &(&1 + 1))
      end)

    %{state | sequence_types: new_types}
  end

  defp update_performance(state, parse_time, process_time) do
    total_time = parse_time + process_time

    new_performance = %{
      parse_time_ms: state.performance.parse_time_ms + parse_time / 1000,
      process_time_ms: state.performance.process_time_ms + process_time / 1000,
      total_time_ms: state.performance.total_time_ms + total_time / 1000
    }

    %{state | performance: new_performance}
  end
end
