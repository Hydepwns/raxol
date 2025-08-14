defmodule Raxol.Terminal.Emulator.SafeEmulator do
  @moduledoc """
  Enhanced terminal emulator with comprehensive error handling.
  Refactored to use functional error handling patterns instead of try/catch.
  """

  use GenServer
  require Logger

  alias Raxol.Core.ErrorRecovery
  alias Raxol.Terminal.Emulator.Telemetry

  # 1MB max input
  @max_input_size 1_048_576
  @processing_timeout 5_000
  @recovery_delay 1_000

  defstruct [
    :emulator_state,
    :error_stats,
    :recovery_state,
    :input_buffer,
    :last_checkpoint,
    :config
  ]

  @type error_stats :: %{
          total_errors: non_neg_integer(),
          errors_by_type: map(),
          last_error: {DateTime.t(), term()} | nil,
          recovery_attempts: non_neg_integer()
        }

  @type t :: %__MODULE__{
          emulator_state: term(),
          error_stats: error_stats(),
          recovery_state: atom(),
          input_buffer: binary(),
          last_checkpoint: term(),
          config: map()
        }

  # Client API

  @doc """
  Starts the safe emulator with error handling capabilities.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Safely processes input with validation and error recovery.
  """
  def process_input(pid \\ __MODULE__, input) do
    with {:ok, :valid_size} <- validate_input_size(input),
         {:ok, result} <- safe_call_with_timeout(pid, {:process_input, input}) do
      result
    else
      {:error, :input_too_large} -> {:error, :input_too_large}
      {:error, :timeout} -> 
        Logger.error("Input processing timeout")
        {:error, :timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Safely handles ANSI sequences with fallback.
  """
  def handle_sequence(pid \\ __MODULE__, sequence) do
    GenServer.call(pid, {:handle_sequence, sequence})
  end

  @doc """
  Safely resizes the terminal with validation.
  """
  def resize(pid \\ __MODULE__, width, height) do
    with {:ok, :valid} <- validate_resize_dimensions(width, height),
         {:ok, result} <- safe_genserver_call(pid, {:resize, width, height}) do
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the current terminal state with error recovery.
  """
  def get_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Gets error statistics and health status.
  """
  def get_health(pid \\ __MODULE__) do
    GenServer.call(pid, :get_health)
  end

  @doc """
  Performs checkpoint/restore operations.
  """
  def checkpoint(pid \\ __MODULE__) do
    GenServer.call(pid, :checkpoint)
  end

  def restore(pid \\ __MODULE__, checkpoint) do
    GenServer.call(pid, {:restore, checkpoint})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    with {:ok, initial_state} <- create_initial_emulator_state(opts),
         {:ok, config} <- build_config(opts) do
      state = %__MODULE__{
        emulator_state: initial_state,
        error_stats: init_error_stats(),
        recovery_state: :healthy,
        input_buffer: <<>>,
        last_checkpoint: initial_state,
        config: config
      }

      # Schedule periodic health checks
      schedule_health_check()

      {:ok, state}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize safe emulator: #{inspect(reason)}")
        # Start with minimal fallback state
        {:ok, build_fallback_state()}
    end
  end

  @impl true
  def handle_call({:process_input, input}, _from, state) do
    Telemetry.span([:raxol, :emulator, :input], %{input_size: byte_size(input)}, fn ->
      with {:ok, chunks} <- perform_input_chunking(input),
           {:ok, new_emulator_state} <- process_chunks_safely(chunks, state.emulator_state),
           {:ok, updated_state} <- update_state_safely(state, new_emulator_state) do
        {:reply, {:ok, :processed}, updated_state}
      else
        {:error, reason} ->
          Telemetry.record_error(:processing_error, reason)
          new_state = handle_processing_error(reason, input, state)
          {:reply, {:error, reason}, new_state}
      end
    end)
  end

  @impl true
  def handle_call({:handle_sequence, sequence}, _from, state) do
    Telemetry.span([:raxol, :emulator, :sequence], %{sequence: sequence}, fn ->
      with {:ok, valid_sequence} <- perform_sequence_validation(sequence),
           {:ok, new_emulator_state} <- perform_sequence_application(valid_sequence, state.emulator_state),
           {:ok, updated_state} <- update_state_safely(state, new_emulator_state) do
        {:reply, {:ok, :handled}, updated_state}
      else
        {:error, reason} ->
          Telemetry.record_error(:sequence_error, reason)
          new_state = record_error(state, :sequence_error, reason)
          {:reply, {:error, reason}, new_state}
      end
    end)
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state) do
    Telemetry.span([:raxol, :emulator, :resize], %{width: width, height: height}, fn ->
      with {:ok, new_emulator_state} <- perform_resize(state.emulator_state, width, height),
           {:ok, updated_state} <- update_state_safely(state, new_emulator_state) do
        {:reply, {:ok, :resized}, updated_state}
      else
        {:error, reason} ->
          Telemetry.record_error(:resize_error, reason)
          new_state = record_error(state, :resize_error, reason)
          {:reply, {:error, reason}, new_state}
      end
    end)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Return a safe copy of the state
    safe_state = safe_state_copy(state.emulator_state)
    {:reply, {:ok, safe_state}, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health = %{
      status: determine_health_status(state),
      error_stats: state.error_stats,
      recovery_state: state.recovery_state,
      buffer_size: byte_size(state.input_buffer)
    }
    {:reply, {:ok, health}, state}
  end

  @impl true
  def handle_call(:checkpoint, _from, state) do
    checkpoint = create_checkpoint(state.emulator_state)
    new_state = %{state | last_checkpoint: checkpoint}
    Telemetry.record_checkpoint_created(%{checkpoint_size: map_size(checkpoint)})
    {:reply, {:ok, checkpoint}, new_state}
  end

  @impl true
  def handle_call({:restore, checkpoint}, _from, state) do
    with {:ok, restored_state} <- perform_restore(checkpoint) do
      new_state = %{state | emulator_state: restored_state, recovery_state: :restored}
      Telemetry.record_checkpoint_restored(%{checkpoint_size: map_size(checkpoint)})
      {:reply, {:ok, :restored}, new_state}
    else
      {:error, reason} ->
        Telemetry.record_error(:restore_error, reason)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state = perform_health_check(state)
    schedule_health_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:retry_processing, input}, state) do
    with {:ok, result} <- process_with_retry(input, state) do
      Logger.info("Retry successful for buffered input")
      new_state = %{state | 
        input_buffer: <<>>,
        recovery_state: :healthy
      }
      {:noreply, new_state}
    else
      {:error, reason} ->
        Logger.error("Retry failed, discarding input: #{inspect(reason)}")
        new_state = %{state | 
          input_buffer: <<>>,
          recovery_state: :degraded
        }
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helper functions

  defp validate_input_size(input) when is_binary(input) do
    if byte_size(input) > @max_input_size do
      {:error, :input_too_large}
    else
      {:ok, :valid_size}
    end
  end
  defp validate_input_size(_), do: {:error, :invalid_input}

  defp safe_call_with_timeout(pid, message) do
    with true <- Process.alive?(pid) do
      task = Task.async(fn -> GenServer.call(pid, message, @processing_timeout) end)
      
      case Task.yield(task, @processing_timeout) || Task.shutdown(task) do
        {:ok, result} -> {:ok, result}
        nil -> {:error, :timeout}
        {:exit, reason} -> {:error, {:exit, reason}}
      end
    else
      false -> {:error, :process_dead}
    end
  end

  defp validate_resize_dimensions(width, height)
       when width <= 0 or height <= 0, do: {:error, :invalid_dimensions}

  defp validate_resize_dimensions(width, height)
       when width > 10_000 or height > 10_000, do: {:error, :dimensions_too_large}

  defp validate_resize_dimensions(_width, _height), do: {:ok, :valid}

  defp safe_genserver_call(pid, message) do
    with true <- Process.alive?(pid) do
      result = GenServer.call(pid, message)
      {:ok, result}
    else
      false -> {:error, :process_dead}
    end
  rescue
    e -> {:error, {:call_exception, e}}
  catch
    :exit, reason -> {:error, {:genserver_exit, reason}}
    error -> {:error, {:genserver_error, error}}
  end

  defp perform_input_chunking(input) do
    with {:ok, validated_input} <- validate_input(input) do
      chunks = chunk_input(validated_input)
      {:ok, chunks}
    end
  rescue
    e ->
      Logger.error("Exception in input chunking: #{inspect(e)}")
      {:error, {:chunking_exception, e}}
  end

  defp validate_input(input) when is_binary(input), do: {:ok, input}
  defp validate_input(_), do: {:error, :invalid_input_type}

  defp chunk_input(input) do
    # Simple chunking implementation - can be customized
    chunk_size = 1024
    for <<chunk::binary-size(chunk_size) <- input>>, do: chunk
  end

  defp process_chunks_safely(chunks, initial_state) do
    result = Enum.reduce_while(chunks, {:ok, initial_state}, fn chunk, {:ok, acc} ->
      case process_chunk(chunk, acc) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    
    result
  end

  defp process_chunk(chunk, state) do
    # Placeholder for actual chunk processing
    # This would call into the actual emulator logic
    {:ok, Map.put(state, :last_chunk, chunk)}
  rescue
    e -> {:error, {:chunk_processing_error, e}}
  end

  defp update_state_safely(state, new_emulator_state) do
    with {:ok, updated} <- safe_state_update(state, :emulator_state, new_emulator_state) do
      {:ok, updated}
    end
  end

  defp safe_state_update(state, key, value) do
    updated = Map.put(state, key, value)
    {:ok, updated}
  rescue
    e -> {:error, {:state_update_error, e}}
  end

  defp perform_sequence_validation(sequence) do
    # Placeholder for sequence validation logic
    if is_binary(sequence) or is_list(sequence) do
      {:ok, sequence}
    else
      {:error, :invalid_sequence}
    end
  end

  defp perform_sequence_application(sequence, emulator_state) do
    # Placeholder for sequence application logic
    {:ok, Map.put(emulator_state, :last_sequence, sequence)}
  rescue
    e ->
      Logger.error("Exception applying sequence: #{inspect(e)}")
      {:error, {:application_exception, e}}
  end

  defp perform_resize(emulator_state, width, height) do
    # Placeholder for resize logic
    {:ok, Map.merge(emulator_state, %{width: width, height: height})}
  rescue
    e -> {:error, {:resize_exception, e}}
  end

  defp create_initial_emulator_state(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    
    state = %{
      width: width,
      height: height,
      buffer: [],
      cursor: {0, 0},
      attributes: %{}
    }
    
    {:ok, state}
  end

  defp build_config(opts) do
    config = %{
      max_retries: Keyword.get(opts, :max_retries, 3),
      buffer_inputs: Keyword.get(opts, :buffer_inputs, true),
      telemetry_enabled: Keyword.get(opts, :telemetry_enabled, true)
    }
    {:ok, config}
  end

  defp init_error_stats do
    %{
      total_errors: 0,
      errors_by_type: %{},
      last_error: nil,
      recovery_attempts: 0
    }
  end

  defp build_fallback_state do
    %__MODULE__{
      emulator_state: %{width: 80, height: 24, buffer: []},
      error_stats: init_error_stats(),
      recovery_state: :fallback,
      input_buffer: <<>>,
      last_checkpoint: nil,
      config: %{}
    }
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, 30_000)
  end

  defp handle_processing_error(reason, input, state) do
    new_stats = update_error_stats(state.error_stats, :processing_error, reason)
    
    new_state = %{state | 
      error_stats: new_stats,
      recovery_state: :recovering
    }
    
    # Buffer input for retry if configured
    if state.config[:buffer_inputs] do
      buffered_state = %{new_state | input_buffer: state.input_buffer <> input}
      
      # Schedule retry
      Process.send_after(self(), {:retry_processing, input}, @recovery_delay)
      
      buffered_state
    else
      new_state
    end
  end

  defp record_error(state, error_type, reason) do
    new_stats = update_error_stats(state.error_stats, error_type, reason)
    %{state | error_stats: new_stats}
  end

  defp update_error_stats(stats, error_type, reason) do
    %{stats |
      total_errors: stats.total_errors + 1,
      errors_by_type: Map.update(stats.errors_by_type, error_type, 1, &(&1 + 1)),
      last_error: {DateTime.utc_now(), reason}
    }
  end

  defp safe_state_copy(emulator_state) do
    # Create a safe copy of the state
    Map.new(emulator_state)
  rescue
    _ -> %{}
  end

  defp determine_health_status(%{error_stats: %{total_errors: 0}}), do: :healthy

  defp determine_health_status(%{error_stats: %{total_errors: errors}})
       when errors < 10, do: :degraded

  defp determine_health_status(_state), do: :critical

  defp create_checkpoint(emulator_state) do
    # Create a checkpoint of the current state
    Map.new(emulator_state)
  end

  defp perform_restore(checkpoint) do
    # Restore from checkpoint
    {:ok, Map.new(checkpoint)}
  rescue
    e -> {:error, {:restore_error, e}}
  end

  defp perform_health_check(state) do
    health_status = determine_health_status(state)
    Telemetry.record_health_check(health_status, %{total_errors: state.error_stats.total_errors})
    
    # Perform health check and potentially recover
    if state.recovery_state == :recovering and state.error_stats.total_errors > 0 do
      # Try to recover
      case perform_recovery(state) do
        {:ok, recovered_state} -> 
          Telemetry.record_recovery_success()
          recovered_state
        {:error, reason} -> 
          Telemetry.record_recovery_failure(reason)
          state
      end
    else
      state
    end
  end

  defp perform_recovery(state) do
    Telemetry.record_recovery_attempt()
    
    # Attempt to recover from errors
    if state.last_checkpoint do
      {:ok, %{state | 
        emulator_state: state.last_checkpoint,
        recovery_state: :recovered,
        error_stats: Map.update!(state.error_stats, :recovery_attempts, &(&1 + 1))
      }}
    else
      {:error, :no_checkpoint}
    end
  end

  defp process_with_retry(input, state) do
    ErrorRecovery.with_retry(
      fn -> process_input_internal(input, state) end,
      max_attempts: 3,
      backoff: 100
    )
  end

  defp process_input_internal(input, state) do
    with {:ok, chunks} <- perform_input_chunking(input),
         {:ok, new_state} <- process_chunks_safely(chunks, state.emulator_state) do
      {:ok, new_state}
    end
  end
end