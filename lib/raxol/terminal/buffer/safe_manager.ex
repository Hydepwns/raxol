defmodule Raxol.Terminal.Buffer.SafeManager do
  @moduledoc """
  Enhanced buffer manager with comprehensive error handling and recovery.
  Refactored to use functional error handling patterns instead of try/catch.
  """

  use GenServer
  require Logger

  alias Raxol.Core.ErrorRecovery
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Buffer.Manager.BufferImpl

  @circuit_breaker_threshold 5
  @circuit_breaker_timeout 30_000
  @retry_attempts 3
  @retry_backoff 100
  @max_input_size 1_000_000

  defstruct [
    :manager_pid,
    :circuit_breaker,
    :error_count,
    :last_error_time,
    :fallback_buffer,
    :stats
  ]

  @type t :: %__MODULE__{
          manager_pid: pid() | nil,
          circuit_breaker: map(),
          error_count: non_neg_integer(),
          last_error_time: DateTime.t() | nil,
          fallback_buffer: term(),
          stats: map()
        }

  # Client API

  @doc """
  Starts the safe buffer manager with error handling.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Safely writes data to the buffer with automatic retry and fallback.
  """
  def write(pid \\ __MODULE__, data, opts \\ []) do
    with {:ok, pid} <- ensure_pid(pid),
         {:ok, result} <- safe_genserver_call(pid, {:write, data, opts}, 10_000) do
      {:ok, result}
    else
      {:error, :timeout} ->
        Logger.error("Write operation timed out, using fallback")
        {:error, :timeout}

      error ->
        error
    end
  end

  @doc """
  Safely reads from the buffer with error recovery.
  """
  def read(pid \\ __MODULE__, opts \\ []) do
    with {:ok, pid} <- ensure_pid(pid),
         {:ok, result} <- safe_genserver_call(pid, {:read, opts}, 5_000) do
      result
    else
      {:error, :timeout} ->
        Logger.error("Read operation timed out")
        {:error, :timeout}

      error ->
        error
    end
  end

  @doc """
  Safely resizes the buffer with validation.
  """
  def resize(pid \\ __MODULE__, width, height)

  def resize(pid, width, height) when width > 0 and height > 0 do
    GenServer.call(pid, {:resize, {width, height}})
  end

  def resize(_pid, _width, _height) do
    {:error, :invalid_dimensions}
  end

  @doc """
  Gets buffer statistics including error rates.
  """
  def get_stats(pid \\ __MODULE__) do
    GenServer.call(pid, :get_stats)
  end

  @doc """
  Resets the circuit breaker and error counters.
  """
  def reset_errors(pid \\ __MODULE__) do
    GenServer.cast(pid, :reset_errors)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Initialize with error handling
    with {:ok, manager_pid} <- safe_start_manager(opts),
         {:ok, initial_state} <- build_initial_state(manager_pid, opts) do
      {:ok, initial_state}
    else
      {:error, reason} ->
        Logger.error("Failed to start buffer manager: #{inspect(reason)}")
        # Start with fallback mode
        {:ok, build_fallback_state()}
    end
  end

  @impl true
  def handle_call({:write, data, opts}, from, state) do
    with {:ok, :valid_size} <- validate_input_size(data),
         {:ok, result, new_state} <- execute_safe_write(data, opts, state) do
      {:reply, {:ok, result}, new_state}
    else
      {:error, :input_too_large} ->
        {:reply, {:error, :input_too_large}, state}

      {:error, :circuit_open} ->
        handle_fallback_write(data, opts, state)

      {:error, :circuit_failure, message} ->
        handle_write_error(data, opts, message, state, from)

      {:error, reason} ->
        handle_write_exception(reason, state)

      error ->
        handle_write_exception({:unexpected_error, error}, state)
    end
  end

  @impl true
  def handle_call({:read, opts}, _from, state) do
    with {:ok, result, new_state} <- execute_safe_read(opts, state) do
      {:reply, {:ok, result}, new_state}
    else
      {:error, reason} -> handle_read_error(opts, reason, state)
      error -> handle_read_exception(error, state)
    end
  end

  @impl true
  def handle_call({:resize, {width, height}}, from, state) do
    # Delegate to the non-tuple version
    handle_call({:resize, width, height}, from, state)
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state)
      when is_number(width) and is_number(height) do
    with {:ok, :valid} <- validate_dimensions(width, height),
         {:ok, new_state} <- execute_safe_resize(width, height, state) do
      {:reply, :ok, new_state}
    else
      {:error, reason}
      when reason in [:invalid_dimensions, :dimensions_too_large] ->
        {:reply, {:error, reason}, state}

      {:error, reason} ->
        Logger.error("Resize failed: #{inspect(reason)}")
        {:reply, {:error, reason}, increment_error_count(state)}

      error ->
        handle_resize_exception(error, state)
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        circuit_breaker_state:
          ErrorRecovery.circuit_breaker_state(state.circuit_breaker),
        error_count: state.error_count,
        last_error_time: state.last_error_time,
        manager_alive:
          is_pid(state.manager_pid) and Process.alive?(state.manager_pid)
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast(:reset_errors, state) do
    new_breaker = ErrorRecovery.circuit_breaker_reset(state.circuit_breaker)

    new_state = %{
      state
      | circuit_breaker: new_breaker,
        error_count: 0,
        last_error_time: nil
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %{manager_pid: pid} = state
      ) do
    Logger.error("Buffer manager process died: #{inspect(reason)}")

    # Attempt to restart the manager
    new_state =
      with {:ok, new_pid} <- safe_restart_manager(),
           {:ok, monitored_pid} <- safe_monitor_process(new_pid) do
        new_stats = Map.update(state.stats, :recoveries, 1, &(&1 + 1))
        %{state | manager_pid: monitored_pid, stats: new_stats}
      else
        {:error, restart_reason} ->
          Logger.error("Failed to restart manager: #{inspect(restart_reason)}")
          increment_error_count(state)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helper functions

  defp ensure_pid(pid) when is_pid(pid), do: {:ok, pid}

  defp ensure_pid(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :process_not_found}
      pid -> {:ok, pid}
    end
  end

  defp ensure_pid(_), do: {:error, :invalid_pid}

  defp safe_start_manager(opts) do
    manager_opts = Keyword.take(opts, [:width, :height, :scrollback_size])

    case Manager.start_link(manager_opts) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_initial_state(manager_pid, opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    fallback_buffer = BufferImpl.new(width, height)

    circuit_breaker =
      ErrorRecovery.circuit_breaker_init(
        threshold: @circuit_breaker_threshold,
        timeout: @circuit_breaker_timeout
      )

    state = %__MODULE__{
      manager_pid: manager_pid,
      circuit_breaker: circuit_breaker,
      error_count: 0,
      last_error_time: nil,
      fallback_buffer: fallback_buffer,
      stats: %{
        writes: 0,
        reads: 0,
        errors: 0,
        recoveries: 0
      }
    }

    {:ok, state}
  end

  defp build_fallback_state do
    %__MODULE__{
      manager_pid: nil,
      circuit_breaker: ErrorRecovery.circuit_breaker_init(),
      error_count: 0,
      fallback_buffer: BufferImpl.new(80, 24),
      stats: %{errors: 1}
    }
  end

  defp validate_input_size(data) do
    case byte_size(data) > @max_input_size do
      true -> {:error, :input_too_large}
      false -> {:ok, :valid_size}
    end
  end

  defp execute_safe_write(data, opts, state) do
    with {:ok, breaker_result} <-
           safe_circuit_breaker_call(:buffer_write, fn ->
             perform_write(state.manager_pid, data, opts)
           end) do
      case breaker_result do
        {:ok, result} ->
          new_stats = Map.update(state.stats, :writes, 1, &(&1 + 1))
          new_state = %{state | stats: new_stats, error_count: 0}
          {:ok, result, new_state}

        {:error, :circuit_open, _message, _metadata} ->
          Logger.warning("Circuit breaker open, using fallback buffer")
          {:error, :circuit_open}

        {:error, :circuit_failure, message, _metadata} ->
          {:error, :circuit_failure, message}

        other ->
          {:error, {:unexpected_breaker_result, other}}
      end
    else
      {:error, reason} ->
        {:error, {:write_exception, reason}}
    end
  end

  defp safe_circuit_breaker_call(name, fun) do
    # Wrap the circuit breaker call to handle any exceptions
    Raxol.Core.ErrorHandling.safe_call(fn ->
      ErrorRecovery.with_circuit_breaker(name, fun)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:circuit_breaker_exception, reason}}
    end
  end

  defp handle_write_exception(reason, state) do
    Logger.error("Error in write handler: #{inspect(reason)}")
    new_stats = Map.update(state.stats, :errors, 1, &(&1 + 1))
    {:reply, {:error, reason}, %{state | stats: new_stats}}
  end

  defp execute_safe_read(opts, state) do
    with {:ok, retry_result} <-
           safe_retry_call(
             fn -> perform_read(state.manager_pid, opts) end,
             max_attempts: @retry_attempts,
             backoff: @retry_backoff
           ) do
      case retry_result do
        {:ok, result} ->
          new_stats = Map.update(state.stats, :reads, 1, &(&1 + 1))
          {:ok, result, %{state | stats: new_stats}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, {:read_exception, reason}}
    end
  end

  defp safe_retry_call(fun, opts) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      ErrorRecovery.with_retry(fun, opts)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:retry_exception, reason}}
    end
  end

  defp handle_read_exception(reason, state) do
    Logger.error("Error in read handler: #{inspect(reason)}")
    new_stats = Map.update(state.stats, :errors, 1, &(&1 + 1))
    {:reply, {:error, reason}, %{state | stats: new_stats}}
  end

  defp validate_dimensions(width, height) do
    case {width, height} do
      {w, h} when w <= 0 or h <= 0 ->
        {:error, :invalid_dimensions}

      {w, h} when w > 10_000 or h > 10_000 ->
        {:error, :dimensions_too_large}

      {_, _} ->
        {:ok, :valid}
    end
  end

  defp execute_safe_resize(width, height, state) do
    with {:ok, result} <- perform_resize_safe(state.manager_pid, width, height) do
      case result do
        :ok ->
          # Update fallback buffer dimensions
          new_fallback = BufferImpl.new(width, height)
          {:ok, %{state | fallback_buffer: new_fallback}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, {:resize_exception, reason}}
    end
  end

  defp perform_resize_safe(manager_pid, width, height) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      perform_resize(manager_pid, width, height)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:resize_rescue, reason}}
    end
  end

  defp handle_resize_exception(reason, state) do
    Logger.error("Error in resize handler: #{inspect(reason)}")
    new_stats = Map.update(state.stats, :errors, 1, &(&1 + 1))
    {:reply, {:error, reason}, %{state | stats: new_stats}}
  end

  defp perform_write(nil, _data, _opts) do
    {:error, :no_manager}
  end

  defp perform_write(manager_pid, data, opts) do
    with {:ok, result} <-
           safe_genserver_call(manager_pid, {:write, data, opts}, 5_000) do
      case result do
        :ok -> {:ok, :written}
        error -> error
      end
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_write_error, error}}
    end
  end

  defp safe_genserver_call(pid, message, timeout) do
    # Use Process.alive? to check before calling
    with true <- Process.alive?(pid),
         {:ok, _ref} <- safe_monitor_setup(pid) do
      Raxol.Core.ErrorHandling.safe_call(fn ->
        GenServer.call(pid, message, timeout)
      end)
      |> case do
        {:ok, result} -> {:ok, result}
        {:error, {:exit, {:timeout, _}}} -> {:error, :timeout}
        {:error, {:exit, {:noproc, _}}} -> {:error, :manager_dead}
        {:error, {kind, reason}} -> {:error, {:call_caught, {kind, reason}}}
        {:error, reason} -> {:error, {:call_exception, reason}}
      end
    else
      false -> {:error, :manager_dead}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_monitor_setup(pid) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      Process.monitor(pid)
      :monitored
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:monitor_exception, reason}}
    end
  end

  defp perform_read(nil, _opts) do
    {:error, :no_manager}
  end

  defp perform_read(manager_pid, opts) do
    with {:ok, result} <- safe_genserver_call(manager_pid, {:read, opts}, 5_000) do
      result
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_read_error, error}}
    end
  end

  defp perform_resize(nil, _width, _height) do
    {:error, :no_manager}
  end

  defp perform_resize(manager_pid, width, height) do
    with {:ok, result} <- safe_manager_resize(manager_pid, width, height) do
      result
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_resize_error, error}}
    end
  end

  defp safe_manager_resize(manager_pid, width, height) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      Manager.resize(manager_pid, {width, height})
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, {:exit, {:timeout, _}}} -> {:error, :timeout}
      {:error, {:exit, {:noproc, _}}} -> {:error, :manager_dead}
      {:error, {kind, reason}} -> {:error, {:resize_caught, {kind, reason}}}
      {:error, reason} -> {:error, {:resize_exception, reason}}
    end
  end

  defp handle_fallback_write(data, _opts, state) do
    # Write to fallback buffer
    new_fallback = BufferImpl.write(state.fallback_buffer, data)

    new_stats =
      state.stats
      |> Map.update(:writes, 1, &(&1 + 1))
      |> Map.update(:errors, 1, &(&1 + 1))

    new_state = %{state | fallback_buffer: new_fallback, stats: new_stats}

    {:reply, {:ok, :fallback}, new_state}
  end

  defp handle_write_error(data, opts, reason, state, _from) do
    Logger.warning("Write error: #{inspect(reason)}, attempting retry")

    # Retry with exponential backoff
    with {:ok, retry_result} <-
           safe_retry_call(
             fn -> perform_write(state.manager_pid, data, opts) end,
             max_attempts: @retry_attempts,
             backoff: @retry_backoff
           ) do
      case retry_result do
        {:ok, result} ->
          new_stats = Map.update(state.stats, :writes, 1, &(&1 + 1))
          {:reply, {:ok, result}, %{state | stats: new_stats}}

        {:error, _retry_reason} ->
          # Fall back to local buffer
          handle_fallback_write(data, opts, increment_error_count(state))
      end
    else
      {:error, _} ->
        handle_fallback_write(data, opts, increment_error_count(state))
    end
  end

  defp handle_read_error(_opts, reason, state) do
    Logger.error("Read error: #{inspect(reason)}")

    new_state = increment_error_count(state)

    # Return empty data as fallback
    {:reply, {:ok, ""}, new_state}
  end

  defp safe_restart_manager do
    case Manager.start_link([]) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_monitor_process(pid) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      Process.monitor(pid)
      pid
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, {:monitor_failed, reason}}
    end
  end

  defp increment_error_count(state) do
    %{
      state
      | error_count: state.error_count + 1,
        last_error_time: DateTime.utc_now(),
        stats: Map.update(state.stats, :errors, 1, &(&1 + 1))
    }
  end
end
