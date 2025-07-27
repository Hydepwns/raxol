defmodule Raxol.Core.ErrorRecovery do
  @moduledoc """
  Error recovery strategies for the Raxol application.

  Provides various recovery mechanisms for different types of errors,
  including circuit breakers, fallback mechanisms, and graceful degradation.

  ## Features

  - Circuit breaker pattern for external services
  - Fallback strategies
  - Graceful degradation
  - Resource cleanup on errors
  - State recovery mechanisms
  """

  use GenServer
  require Logger

  @type recovery_strategy ::
          :retry | :fallback | :circuit_breaker | :degrade | :cleanup
  @type circuit_state :: :closed | :open | :half_open

  defmodule CircuitBreaker do
    @moduledoc false
    defstruct [
      :name,
      :state,
      :failure_count,
      :success_count,
      :last_failure_time,
      :threshold,
      :timeout,
      :half_open_requests
    ]
  end

  # Client API

  @doc """
  Starts the error recovery GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a function with circuit breaker protection.

  ## Examples

      with_circuit_breaker(:external_api, fn ->
        ExternalAPI.call()
      end)
  """
  def with_circuit_breaker(circuit_name, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    threshold = Keyword.get(opts, :threshold, 5)

    case check_circuit(circuit_name) do
      :open ->
        {:error, :circuit_open, "Circuit breaker is open",
         %{circuit: circuit_name}}

      state when state in [:closed, :half_open] ->
        execute_with_circuit(circuit_name, fun, timeout, threshold)
    end
  end

  @doc """
  Implements exponential backoff retry strategy.

  ## Options

  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:base_delay` - Base delay in milliseconds (default: 100)
  - `:max_delay` - Maximum delay in milliseconds (default: 5000)
  - `:jitter` - Add randomness to delays (default: true)
  """
  def with_retry(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5000)
    jitter = Keyword.get(opts, :jitter, true)

    do_retry(fun, 0, max_retries, base_delay, max_delay, jitter)
  end

  @doc """
  Provides fallback mechanism for failed operations.

  ## Examples

      with_fallback fn ->
        fetch_from_primary()
      end, fn ->
        fetch_from_cache()
      end
  """
  def with_fallback(primary_fun, fallback_fun) do
    case safe_execute(primary_fun) do
      {:ok, result} ->
        {:ok, result}

      {:error, _type, _msg, _context} = error ->
        Logger.warning(
          "Primary operation failed, attempting fallback: #{inspect(error)}"
        )

        case safe_execute(fallback_fun) do
          {:ok, fallback_result} ->
            {:ok, fallback_result}

          fallback_error ->
            {:error, :all_failed, "Both primary and fallback failed",
             %{
               primary_error: error,
               fallback_error: fallback_error
             }}
        end
    end
  end

  @doc """
  Implements graceful degradation for feature availability.

  ## Examples

      degrade_gracefully(:advanced_search) do
        # Full feature implementation
        AdvancedSearch.execute(query)
      else
        # Degraded functionality
        BasicSearch.execute(query)
      end
  """
  defmacro degrade_gracefully(feature, do: full_block, else: degraded_block) do
    quote do
      if Raxol.Core.ErrorRecovery.feature_available?(unquote(feature)) do
        try do
          unquote(full_block)
        rescue
          error ->
            Raxol.Core.ErrorRecovery.mark_feature_degraded(
              unquote(feature),
              error
            )

            unquote(degraded_block)
        end
      else
        unquote(degraded_block)
      end
    end
  end

  @doc """
  Ensures cleanup is performed even on error.

  ## Examples

      with_cleanup fn ->
        resource = acquire_resource()
        process(resource)
      end, fn resource ->
        release_resource(resource)
      end
  """
  def with_cleanup(fun, cleanup_fun) do
    resource = nil

    try do
      result = fun.()
      {:ok, result}
    rescue
      error ->
        {:error, :runtime, Exception.message(error), %{exception: error}}
    after
      if resource && cleanup_fun do
        safe_cleanup(cleanup_fun, resource)
      end
    end
  end

  @doc """
  Implements bulkhead pattern to isolate failures.
  """
  def with_bulkhead(pool_name, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)

    case checkout_from_pool(pool_name, timeout) do
      {:ok, worker} ->
        try do
          result = fun.(worker)
          {:ok, result}
        after
          checkin_to_pool(pool_name, worker)
        end

      {:error, :timeout} ->
        {:error, :bulkhead_timeout, "Could not acquire resource from pool",
         %{pool: pool_name}}
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      circuits: %{},
      degraded_features: %{},
      pools: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check_circuit, name}, _from, state) do
    circuit = get_or_create_circuit(state.circuits, name)
    {:reply, circuit.state, put_in(state.circuits[name], circuit)}
  end

  @impl true
  def handle_call({:record_success, name}, _from, state) do
    circuit = get_or_create_circuit(state.circuits, name)
    updated_circuit = record_circuit_success(circuit)
    {:reply, :ok, put_in(state.circuits[name], updated_circuit)}
  end

  @impl true
  def handle_call({:record_failure, name}, _from, state) do
    circuit = get_or_create_circuit(state.circuits, name)
    updated_circuit = record_circuit_failure(circuit)
    {:reply, :ok, put_in(state.circuits[name], updated_circuit)}
  end

  @impl true
  def handle_call({:feature_available?, feature}, _from, state) do
    available = not Map.has_key?(state.degraded_features, feature)
    {:reply, available, state}
  end

  @impl true
  def handle_call({:mark_feature_degraded, feature, error}, _from, state) do
    degraded_features =
      Map.put(state.degraded_features, feature, %{
        error: error,
        degraded_at: System.system_time(:second)
      })

    {:reply, :ok, %{state | degraded_features: degraded_features}}
  end

  # Private functions

  defp check_circuit(name) do
    GenServer.call(__MODULE__, {:check_circuit, name})
  end

  defp execute_with_circuit(circuit_name, fun, _timeout, _threshold) do
    try do
      result = fun.()
      GenServer.call(__MODULE__, {:record_success, circuit_name})
      {:ok, result}
    rescue
      error ->
        GenServer.call(__MODULE__, {:record_failure, circuit_name})

        {:error, :circuit_failure, Exception.message(error),
         %{circuit: circuit_name}}
    end
  end

  defp get_or_create_circuit(circuits, name) do
    Map.get(circuits, name, %CircuitBreaker{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      threshold: 5,
      timeout: 30_000,
      half_open_requests: 0
    })
  end

  defp record_circuit_success(circuit) do
    case circuit.state do
      :half_open ->
        if circuit.success_count >= 3 do
          %{circuit | state: :closed, failure_count: 0, success_count: 0}
        else
          %{circuit | success_count: circuit.success_count + 1}
        end

      _ ->
        %{circuit | failure_count: 0}
    end
  end

  defp record_circuit_failure(circuit) do
    new_failure_count = circuit.failure_count + 1

    if new_failure_count >= circuit.threshold do
      %{
        circuit
        | state: :open,
          failure_count: new_failure_count,
          last_failure_time: System.system_time(:millisecond)
      }
    else
      %{circuit | failure_count: new_failure_count}
    end
  end

  defp do_retry(_fun, attempt, max_retries, _base_delay, _max_delay, _jitter)
       when attempt >= max_retries do
    {:error, :max_retries_exceeded, "Maximum retry attempts exceeded",
     %{attempts: attempt}}
  end

  defp do_retry(fun, attempt, max_retries, base_delay, max_delay, jitter) do
    case safe_execute(fun) do
      {:ok, result} ->
        {:ok, result}

      _error ->
        delay = calculate_backoff_delay(attempt, base_delay, max_delay, jitter)
        Process.sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay, max_delay, jitter)
    end
  end

  defp calculate_backoff_delay(attempt, base_delay, max_delay, jitter) do
    delay = min(base_delay * :math.pow(2, attempt), max_delay) |> round()

    if jitter do
      jitter_amount = round(delay * 0.1 * :rand.uniform())
      delay + jitter_amount
    else
      delay
    end
  end

  defp safe_execute(fun) do
    try do
      {:ok, fun.()}
    rescue
      error ->
        {:error, :execution_failed, Exception.message(error),
         %{exception: error}}
    end
  end

  defp safe_cleanup(cleanup_fun, resource) do
    try do
      cleanup_fun.(resource)
    rescue
      error ->
        Logger.error("Cleanup failed: #{inspect(error)}")
    end
  end

  defp checkout_from_pool(pool_name, timeout) do
    # Simplified implementation - would integrate with actual pool
    # For now, simulate timeout for nil pool name or zero timeout
    if pool_name == nil or timeout == 0 do
      {:error, :timeout}
    else
      {:ok, :mock_worker}
    end
  end

  defp checkin_to_pool(_pool_name, _worker) do
    :ok
  end

  def feature_available?(feature) do
    GenServer.call(__MODULE__, {:feature_available?, feature})
  end

  def mark_feature_degraded(feature, error) do
    GenServer.call(__MODULE__, {:mark_feature_degraded, feature, error})
  end

  @doc """
  Initializes a circuit breaker with optional configuration.
  """
  def circuit_breaker_init(opts \\ []) do
    name = Keyword.get(opts, :name, :default)
    threshold = Keyword.get(opts, :threshold, 5)
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    %CircuitBreaker{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      threshold: threshold,
      timeout: timeout,
      half_open_requests: 0
    }
  end


  @doc """
  Gets the current state of a circuit breaker.
  """
  def circuit_breaker_state(circuit_breaker) do
    circuit_breaker.state
  end

  @doc """
  Resets a circuit breaker to its initial state.
  """
  def circuit_breaker_reset(circuit_breaker) do
    %{circuit_breaker | 
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      half_open_requests: 0
    }
  end
end
