defmodule Raxol.Terminal.Emulator.SafeEmulator do
  @moduledoc """
  Enhanced terminal emulator with comprehensive error handling.

  Provides fault-tolerant terminal emulation with automatic recovery,
  graceful degradation, and detailed error tracking.
  """

  use GenServer
  require Logger

  import Raxol.Core.ErrorHandler
  alias Raxol.Core.ErrorRecovery
  alias Raxol.Terminal.Emulator

  alias Raxol.Terminal.Emulator.{
    TextOperations,
    Dimensions
  }

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
    with_error_handling :process_input do
      # Validate input size
      if byte_size(input) > @max_input_size do
        {:error, :input_too_large}
      else
        GenServer.call(pid, {:process_input, input}, @processing_timeout)
      end
    end
  catch
    :exit, {:timeout, _} ->
      Logger.error("Input processing timeout")
      {:error, :timeout}
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
    with_error_handling :resize do
      cond do
        width <= 0 or height <= 0 ->
          {:error, :invalid_dimensions}

        width > 10_000 or height > 10_000 ->
          {:error, :dimensions_too_large}

        true ->
          GenServer.call(pid, {:resize, width, height})
      end
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
  Creates a checkpoint for recovery.
  """
  def checkpoint(pid \\ __MODULE__) do
    GenServer.cast(pid, :checkpoint)
  end

  @doc """
  Recovers from the last checkpoint.
  """
  def recover(pid \\ __MODULE__) do
    GenServer.call(pid, :recover)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    result =
      with_error_handling :init do
        # Initialize emulator with defaults
        width = Keyword.get(opts, :width, 80)
        height = Keyword.get(opts, :height, 24)

        emulator_state =
          case Emulator.new(width, height) do
            {:ok, emulator} -> emulator
            _ -> create_default_emulator()
          end

        %__MODULE__{
          emulator_state: emulator_state,
          error_stats: %{
            total_errors: 0,
            errors_by_type: %{},
            last_error: nil,
            recovery_attempts: 0
          },
          recovery_state: :normal,
          input_buffer: <<>>,
          last_checkpoint: emulator_state,
          config: %{
            auto_recovery: Keyword.get(opts, :auto_recovery, true),
            max_recovery_attempts: Keyword.get(opts, :max_recovery_attempts, 3),
            checkpoint_interval: Keyword.get(opts, :checkpoint_interval, 60_000)
          }
        }
      end

    # Extract the state from the result tuple
    state =
      case result do
        {:ok, s} -> s
        s -> s
      end

    # Schedule periodic checkpoints
    if state.config.checkpoint_interval > 0 do
      schedule_checkpoint(state.config.checkpoint_interval)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:process_input, input}, _from, state) do
    case safe_process_input(input, state) do
      {:ok, new_emulator_state} ->
        new_state = %{
          state
          | emulator_state: new_emulator_state,
            input_buffer: <<>>
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = handle_processing_error(reason, input, state)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:handle_sequence, sequence}, _from, state) do
    case safe_handle_sequence(sequence, state) do
      {:ok, new_emulator_state} ->
        {:reply, :ok, %{state | emulator_state: new_emulator_state}}

      {:error, reason} ->
        new_state = record_error(:sequence_error, reason, state)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state) do
    case safe_resize(width, height, state) do
      {:ok, new_emulator_state} ->
        # Create checkpoint after resize
        new_state = %{
          state
          | emulator_state: new_emulator_state,
            last_checkpoint: new_emulator_state
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = record_error(:resize_error, reason, state)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Return sanitized state
    safe_state = %{
      dimensions: get_dimensions(state.emulator_state),
      cursor: get_cursor_position(state.emulator_state),
      recovery_state: state.recovery_state,
      buffer_size: byte_size(state.input_buffer)
    }

    {:reply, {:ok, safe_state}, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health = %{
      status: determine_health_status(state),
      error_stats: state.error_stats,
      recovery_state: state.recovery_state,
      uptime: calculate_uptime(state)
    }

    {:reply, {:ok, health}, state}
  end

  @impl true
  def handle_call(:recover, _from, state) do
    case perform_recovery(state) do
      {:ok, recovered_state} ->
        {:reply, :ok, recovered_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast(:checkpoint, state) do
    new_state = %{state | last_checkpoint: state.emulator_state}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:scheduled_checkpoint, state) do
    # Create checkpoint
    new_state = %{state | last_checkpoint: state.emulator_state}

    # Schedule next checkpoint
    schedule_checkpoint(state.config.checkpoint_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:retry_processing, input}, state) do
    case safe_process_input(input, state) do
      {:ok, new_emulator_state} ->
        Logger.info("Retry successful for buffered input")

        new_state = %{
          state
          | emulator_state: new_emulator_state,
            input_buffer: <<>>,
            recovery_state: :normal
        }

        {:noreply, new_state}

      {:error, _reason} ->
        # Give up on this input
        Logger.error("Retry failed, discarding input")
        new_state = %{state | input_buffer: <<>>, recovery_state: :normal}
        {:noreply, new_state}
    end
  end

  # Private functions

  defp safe_process_input(input, state) do
    ErrorRecovery.with_retry(
      fn ->
        try do
          # Split input into manageable chunks
          chunks = chunk_input(input)

          # Process each chunk
          final_state =
            Enum.reduce_while(chunks, state.emulator_state, fn chunk, acc ->
              case process_chunk(chunk, acc) do
                {:ok, new_state} -> {:cont, new_state}
                {:error, reason} -> {:halt, {:error, reason}}
              end
            end)

          case final_state do
            {:error, reason} -> {:error, reason}
            emulator_state -> {:ok, emulator_state}
          end
        rescue
          e ->
            Logger.error("Exception in input processing: #{inspect(e)}")
            {:error, {:exception, e}}
        end
      end,
      max_attempts: 3,
      backoff: 100
    )
  end

  defp process_chunk(chunk, emulator_state) do
    case Raxol.Terminal.Operations.TextOperations.write_text(
           emulator_state,
           chunk
         ) do
      {:ok, new_state} -> {:ok, new_state}
      error -> error
    end
  catch
    _, reason -> {:error, {:caught, reason}}
  end

  defp safe_handle_sequence(sequence, state) do
    try do
      # Validate sequence first
      case validate_sequence(sequence) do
        :ok ->
          # Process sequence with fallback
          case apply_sequence(sequence, state.emulator_state) do
            {:ok, new_state} -> {:ok, new_state}
            error -> error
          end

        {:error, reason} ->
          {:error, {:invalid_sequence, reason}}
      end
    rescue
      e ->
        Logger.error("Exception handling sequence: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  defp safe_resize(width, height, state) do
    try do
      case Dimensions.resize(state.emulator_state, width, height) do
        {:ok, new_state} -> {:ok, new_state}
        error -> error
      end
    rescue
      e ->
        Logger.error("Exception during resize: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  defp handle_processing_error(reason, input, state) do
    Logger.warning("Processing error: #{inspect(reason)}")

    new_state = record_error(:processing_error, reason, state)

    # Buffer input for retry if configured
    if state.config.auto_recovery and
         byte_size(new_state.input_buffer) < @max_input_size do
      buffered_state = %{
        new_state
        | input_buffer: new_state.input_buffer <> input,
          recovery_state: :buffering
      }

      # Schedule retry
      Process.send_after(self(), {:retry_processing, input}, @recovery_delay)

      buffered_state
    else
      new_state
    end
  end

  defp record_error(type, reason, state) do
    error_stats =
      state.error_stats
      |> Map.update(:total_errors, 1, &(&1 + 1))
      |> Map.update(:errors_by_type, %{type => 1}, fn types ->
        Map.update(types, type, 1, &(&1 + 1))
      end)
      |> Map.put(:last_error, {DateTime.utc_now(), reason})

    %{state | error_stats: error_stats}
  end

  defp perform_recovery(state) do
    if state.error_stats.recovery_attempts < state.config.max_recovery_attempts do
      # Attempt recovery from checkpoint
      new_stats =
        Map.update(state.error_stats, :recovery_attempts, 1, &(&1 + 1))

      {:ok,
       %{
         state
         | emulator_state: state.last_checkpoint,
           error_stats: new_stats,
           recovery_state: :recovered,
           input_buffer: <<>>
       }}
    else
      {:error, :max_recovery_attempts_exceeded}
    end
  end

  defp chunk_input(input) do
    # Split input into 4KB chunks for processing
    chunk_size = 4096

    (for <<chunk::binary-size(chunk_size) <- input>> do
       chunk
     end ++
       [
         # Handle remaining bytes
         case input do
           <<_::binary-size(
               byte_size(input) - rem(byte_size(input), chunk_size)
             ), rest::binary>> ->
             rest

           _ ->
             <<>>
         end
       ])
    |> Enum.filter(&(&1 != <<>>))
  end

  defp validate_sequence(sequence) do
    # Basic sequence validation
    cond do
      not is_tuple(sequence) -> {:error, :invalid_format}
      tuple_size(sequence) < 2 -> {:error, :insufficient_params}
      true -> :ok
    end
  end

  defp apply_sequence(_sequence, emulator_state) do
    # Apply sequence with error handling
    try do
      # This would call the appropriate operation module
      {:ok, emulator_state}
    catch
      _, reason -> {:error, {:sequence_application_failed, reason}}
    end
  end

  defp get_dimensions(emulator_state) do
    try do
      {emulator_state.width, emulator_state.height}
    catch
      # Default dimensions
      _, _ -> {80, 24}
    end
  end

  defp get_cursor_position(emulator_state) do
    try do
      {emulator_state.cursor_x, emulator_state.cursor_y}
    catch
      # Default position
      _, _ -> {0, 0}
    end
  end

  defp determine_health_status(state) do
    error_rate = calculate_error_rate(state)

    cond do
      state.recovery_state != :normal -> :degraded
      error_rate > 0.5 -> :unhealthy
      error_rate > 0.1 -> :degraded
      true -> :healthy
    end
  end

  defp calculate_error_rate(state) do
    # Simple error rate calculation
    if state.error_stats.total_errors > 0 do
      # Would need to track total operations for accurate rate
      min(state.error_stats.total_errors / 100.0, 1.0)
    else
      0.0
    end
  end

  defp calculate_uptime(_state) do
    # Would track actual start time
    0
  end

  defp create_default_emulator do
    # Create a minimal emulator state
    %{
      width: 80,
      height: 24,
      cursor_x: 0,
      cursor_y: 0,
      buffer: [],
      style: %{}
    }
  end

  defp schedule_checkpoint(interval) when interval > 0 do
    Process.send_after(self(), :scheduled_checkpoint, interval)
  end

  defp schedule_checkpoint(_), do: :ok
end
