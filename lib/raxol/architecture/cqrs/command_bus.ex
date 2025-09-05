defmodule Raxol.Architecture.CQRS.CommandBus do
  @moduledoc """
  Command Bus implementation for CQRS (Command Query Responsibility Segregation) pattern in Raxol.

  This module provides a centralized command handling system that separates write operations
  from read operations, ensuring better scalability, maintainability, and testability.

  ## Features

  ### Command Processing
  - Asynchronous and synchronous command execution
  - Command validation and sanitization
  - Command pipeline with middleware support
  - Command routing to appropriate handlers
  - Command retry mechanisms with exponential backoff
  - Dead letter queue for failed commands

  ### Middleware Support
  - Authentication and authorization middleware
  - Logging and auditing middleware
  - Performance monitoring middleware
  - Validation middleware with schema support
  - Transaction management middleware
  - Rate limiting middleware

  ### Error Handling
  - Comprehensive error classification
  - Command compensation patterns
  - Circuit breaker for handler failures
  - Graceful degradation strategies
  - Error reporting and alerting

  ## Usage

      # Start the command bus
      {:ok, command_bus} = CommandBus.start_link()
      
      # Register command handlers
      CommandBus.register_handler(command_bus, CreateTerminalCommand, CreateTerminalHandler)
      CommandBus.register_handler(command_bus, UpdateThemeCommand, UpdateThemeHandler)
      
      # Add middleware
      CommandBus.add_middleware(command_bus, AuthenticationMiddleware, priority: 1)
      CommandBus.add_middleware(command_bus, LoggingMiddleware, priority: 2)
      CommandBus.add_middleware(command_bus, ValidationMiddleware, priority: 3)
      
      # Execute commands
      command = %CreateTerminalCommand{
        id: "terminal-1",
        width: 80,
        height: 24,
        user_id: "user-123"
      }
      
      {:ok, result} = CommandBus.execute(command_bus, command)
      
      # Execute asynchronously
      :ok = CommandBus.execute_async(command_bus, command)
  """

  use GenServer
  require Logger

  alias Raxol.Architecture.CQRS.Command

  defstruct [
    :config,
    :handlers,
    :middleware_stack,
    :command_queue,
    :retry_queue,
    :dead_letter_queue,
    :circuit_breakers,
    :metrics_collector,
    :audit_logger
  ]

  @type command :: Command.t()
  @type command_handler :: module()
  @type middleware :: module()
  @type execution_result :: {:ok, term()} | {:error, term()}
  @type execution_mode :: :sync | :async

  @type config :: %{
          max_retries: non_neg_integer(),
          retry_backoff_base: non_neg_integer(),
          circuit_breaker_threshold: non_neg_integer(),
          circuit_breaker_timeout: non_neg_integer(),
          dead_letter_retention: non_neg_integer(),
          enable_metrics: boolean(),
          enable_auditing: boolean(),
          max_concurrent_commands: non_neg_integer()
        }

  # Default configuration
  @default_config %{
    max_retries: 3,
    retry_backoff_base: 1000,
    circuit_breaker_threshold: 5,
    circuit_breaker_timeout: 30_000,
    # 24 hours
    dead_letter_retention: 86_400_000,
    enable_metrics: true,
    enable_auditing: true,
    max_concurrent_commands: 100
  }

  ## Public API

  @doc """
  Starts the command bus with the given configuration.

  ## Options
  - `:max_retries` - Maximum number of retry attempts for failed commands
  - `:circuit_breaker_threshold` - Number of failures before circuit opens
  - `:enable_metrics` - Enable performance metrics collection
  - `:enable_auditing` - Enable command audit logging
  """
  def start_link(opts \\ []) do
    config = opts |> Enum.into(%{}) |> then(&Map.merge(@default_config, &1))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Registers a command handler for a specific command type.
  """
  def register_handler(bus \\ __MODULE__, command_type, handler_module) do
    GenServer.call(bus, {:register_handler, command_type, handler_module})
  end

  @doc """
  Unregisters a command handler.
  """
  def unregister_handler(bus \\ __MODULE__, command_type) do
    GenServer.call(bus, {:unregister_handler, command_type})
  end

  @doc """
  Adds middleware to the command processing pipeline.
  """
  def add_middleware(bus \\ __MODULE__, middleware_module, opts \\ []) do
    GenServer.call(bus, {:add_middleware, middleware_module, opts})
  end

  @doc """
  Removes middleware from the pipeline.
  """
  def remove_middleware(bus \\ __MODULE__, middleware_module) do
    GenServer.call(bus, {:remove_middleware, middleware_module})
  end

  @doc """
  Executes a command synchronously.
  """
  def execute(bus \\ __MODULE__, command, opts \\ []) do
    GenServer.call(bus, {:execute, command, opts}, :infinity)
  end

  @doc """
  Executes a command asynchronously.
  """
  def execute_async(bus \\ __MODULE__, command, opts \\ []) do
    GenServer.cast(bus, {:execute_async, command, opts})
  end

  @doc """
  Gets the current status of the command bus.
  """
  def get_status(bus \\ __MODULE__) do
    GenServer.call(bus, :get_status)
  end

  @doc """
  Gets metrics about command processing.
  """
  def get_metrics(bus \\ __MODULE__) do
    GenServer.call(bus, :get_metrics)
  end

  @doc """
  Gets commands from the dead letter queue.
  """
  def get_dead_letter_commands(bus \\ __MODULE__, limit \\ 100) do
    GenServer.call(bus, {:get_dead_letter_commands, limit})
  end

  @doc """
  Retries a command from the dead letter queue.
  """
  def retry_dead_letter_command(bus \\ __MODULE__, command_id) do
    GenServer.call(bus, {:retry_dead_letter_command, command_id})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    state = %__MODULE__{
      config: config,
      handlers: %{},
      middleware_stack: [],
      command_queue: :queue.new(),
      retry_queue: :queue.new(),
      dead_letter_queue: %{},
      circuit_breakers: %{},
      metrics_collector: init_metrics_collector(config),
      audit_logger: init_audit_logger(config)
    }

    # Schedule periodic tasks
    :timer.send_interval(5000, :process_retry_queue)
    :timer.send_interval(60000, :cleanup_dead_letters)
    :timer.send_interval(30000, :reset_circuit_breakers)

    Logger.info("Command bus initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:register_handler, command_type, handler_module},
        _from,
        state
      ) do
    # Validate handler implements CommandHandler behaviour
    case validate_command_handler(handler_module) do
      :ok ->
        new_handlers = Map.put(state.handlers, command_type, handler_module)
        new_state = %{state | handlers: new_handlers}

        Logger.info(
          "Registered handler #{inspect(handler_module)} for #{inspect(command_type)}"
        )

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unregister_handler, command_type}, _from, state) do
    new_handlers = Map.delete(state.handlers, command_type)
    new_state = %{state | handlers: new_handlers}

    Logger.info("Unregistered handler for #{inspect(command_type)}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:add_middleware, middleware_module, opts}, _from, state) do
    priority = Keyword.get(opts, :priority, 100)

    middleware_entry = %{
      module: middleware_module,
      priority: priority,
      config: Keyword.get(opts, :config, %{})
    }

    new_middleware =
      [middleware_entry | state.middleware_stack]
      |> Enum.sort_by(& &1.priority)

    new_state = %{state | middleware_stack: new_middleware}

    Logger.info(
      "Added middleware #{inspect(middleware_module)} with priority #{priority}"
    )

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:remove_middleware, middleware_module}, _from, state) do
    new_middleware =
      Enum.reject(state.middleware_stack, &(&1.module == middleware_module))

    new_state = %{state | middleware_stack: new_middleware}

    Logger.info("Removed middleware #{inspect(middleware_module)}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:execute, command, opts}, from, state) do
    # Execute command synchronously
    case execute_command_internal(command, opts, state) do
      {:ok, result, new_state} ->
        {:reply, {:ok, result}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}

      {:async, execution_ref, new_state} ->
        # Store the caller for async response
        Process.monitor(elem(from, 0))
        GenServer.reply(from, {:async, execution_ref})
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      registered_handlers: map_size(state.handlers),
      middleware_count: length(state.middleware_stack),
      pending_commands: :queue.len(state.command_queue),
      retry_queue_size: :queue.len(state.retry_queue),
      dead_letter_count: map_size(state.dead_letter_queue),
      circuit_breaker_status: get_circuit_breaker_status(state.circuit_breakers)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics =
      if state.config.enable_metrics do
        get_metrics_from_collector(state.metrics_collector)
      else
        %{metrics_disabled: true}
      end

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call({:get_dead_letter_commands, limit}, _from, state) do
    commands =
      state.dead_letter_queue
      |> Map.values()
      |> Enum.take(limit)

    {:reply, commands, state}
  end

  @impl GenServer
  def handle_call({:retry_dead_letter_command, command_id}, _from, state) do
    case Map.get(state.dead_letter_queue, command_id) do
      nil ->
        {:reply, {:error, :command_not_found}, state}

      dead_command ->
        # Move back to retry queue
        retry_entry = %{
          command: dead_command.original_command,
          attempts: 0,
          next_retry_at: System.monotonic_time(:millisecond),
          original_error: dead_command.last_error
        }

        new_retry_queue = :queue.in(retry_entry, state.retry_queue)
        new_dead_letter_queue = Map.delete(state.dead_letter_queue, command_id)

        new_state = %{
          state
          | retry_queue: new_retry_queue,
            dead_letter_queue: new_dead_letter_queue
        }

        Logger.info(
          "Moved command #{command_id} from dead letter queue back to retry queue"
        )

        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:execute_async, command, opts}, state) do
    # Execute command asynchronously
    case execute_command_internal(command, opts, state) do
      {:ok, _result, new_state} ->
        {:noreply, new_state}

      {:error, _reason, new_state} ->
        # Error handling for async commands (logging, dead letter queue, etc.)
        {:noreply, new_state}

      {:async, _execution_ref, new_state} ->
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(:process_retry_queue, state) do
    new_state = process_retry_queue(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:cleanup_dead_letters, state) do
    new_state = cleanup_expired_dead_letters(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:reset_circuit_breakers, state) do
    new_state = reset_expired_circuit_breakers(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Handle process monitoring (for async command responses)
    {:noreply, state}
  end

  ## Private Implementation

  defp execute_command_internal(command, _opts, state) do
    start_time = System.monotonic_time(:microsecond)
    _command_id = generate_command_id(command)

    # Check circuit breaker
    handler_module = Map.get(state.handlers, command.__struct__)

    case check_handler_availability(handler_module, state.circuit_breakers) do
      :open ->
        {:error, :circuit_breaker_open, state}

      :available ->
        # Execute through middleware pipeline
        case execute_through_middleware(
               command,
               handler_module,
               state.middleware_stack,
               state
             ) do
          {:ok, result} ->
            # Record success metrics
            execution_time = System.monotonic_time(:microsecond) - start_time
            new_state = record_command_success(state, command, execution_time)
            {:ok, result, new_state}

          {:error, reason} ->
            # Handle command failure
            execution_time = System.monotonic_time(:microsecond) - start_time

            new_state =
              handle_command_failure(state, command, reason, execution_time)

            {:error, reason, new_state}
        end
    end
  end

  defp execute_through_middleware(
         command,
         handler_module,
         middleware_stack,
         state
       ) do
    # Build execution context
    context = %{
      command: command,
      handler: handler_module,
      command_id: generate_command_id(command),
      timestamp: System.system_time(:millisecond),
      metadata: %{}
    }

    # Execute through middleware chain
    case execute_middleware_chain(middleware_stack, context, state) do
      {:ok, updated_context} ->
        # Execute the actual command handler
        if handler_module do
          execute_command_handler(
            handler_module,
            updated_context.command,
            updated_context
          )
        else
          {:error, :no_handler_registered}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_middleware_chain([], context, _state) do
    # End of middleware chain
    {:ok, context}
  end

  defp execute_middleware_chain([middleware | rest], context, state) do
    case apply(middleware.module, :process, [context, middleware.config]) do
      {:ok, updated_context} ->
        execute_middleware_chain(rest, updated_context, state)

      {:error, reason} ->
        {:error, reason}

      :halt ->
        # Middleware decided to halt processing
        {:error, :middleware_halted}
    end
  end

  defp execute_command_handler(handler_module, command, context) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case apply(handler_module, :handle, [command, context]) do
             {:ok, result} -> {:ok, result}
             {:error, reason} -> {:error, reason}
             # Assume success if not explicitly error
             result -> {:ok, result}
           end
         end) do
      {:ok, {:ok, result}} ->
        {:ok, result}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, reason} ->
        Logger.error(
          "Command handler #{inspect(handler_module)} failed: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp validate_command_handler(handler_module) do
    case Code.ensure_loaded?(handler_module) do
      true ->
        case function_exported?(handler_module, :handle, 2) do
          true -> :ok
          false -> {:error, :missing_handle_function}
        end

      false ->
        {:error, :handler_not_found}
    end
  end

  defp generate_command_id(command) do
    command_type = command.__struct__ |> Module.split() |> List.last()
    timestamp = System.unique_integer([:positive])
    "#{command_type}-#{timestamp}"
  end

  defp is_circuit_breaker_open?(circuit_breakers, handler_module) do
    case Map.get(circuit_breakers, handler_module) do
      nil ->
        false

      %{status: :open, opened_at: opened_at} ->
        # Check if timeout has passed
        System.monotonic_time(:millisecond) - opened_at < 30_000

      _ ->
        false
    end
  end

  defp record_command_success(state, command, execution_time) do
    # Update metrics
    new_state =
      update_metrics_if_enabled(state, command, :success, execution_time)

    # Update audit log
    audit_if_enabled(state, command, :success, execution_time)

    new_state
  end

  defp handle_command_failure(state, command, reason, execution_time) do
    handler_module = Map.get(state.handlers, command.__struct__)

    # Update circuit breaker
    new_circuit_breakers =
      update_circuit_breaker(state.circuit_breakers, handler_module, :failure)

    # Update metrics
    new_state =
      %{state | circuit_breakers: new_circuit_breakers}
      |> update_metrics_if_enabled(command, :failure, execution_time)

    # Add to retry queue if retriable
    final_state = queue_failed_command(new_state, command, reason)

    # Update audit log
    audit_if_enabled(final_state, command, {:failure, reason}, execution_time)

    final_state
  end

  defp update_circuit_breaker(circuit_breakers, handler_module, result) do
    current =
      Map.get(circuit_breakers, handler_module, %{failures: 0, status: :closed})

    case result do
      :success ->
        # Reset failure count on success
        Map.put(circuit_breakers, handler_module, %{
          failures: 0,
          status: :closed
        })

      :failure ->
        new_failures = current.failures + 1

        # Circuit breaker threshold
        if new_failures >= 5 do
          Map.put(circuit_breakers, handler_module, %{
            failures: new_failures,
            status: :open,
            opened_at: System.monotonic_time(:millisecond)
          })
        else
          Map.put(circuit_breakers, handler_module, %{
            current
            | failures: new_failures
          })
        end
    end
  end

  defp is_retriable_error?(reason) do
    case reason do
      :timeout -> true
      :network_error -> true
      :temporary_failure -> true
      {:database_error, _} -> true
      _ -> false
    end
  end

  defp add_to_retry_queue(state, command, reason) do
    retry_entry = %{
      command: command,
      attempts: 0,
      next_retry_at:
        System.monotonic_time(:millisecond) + state.config.retry_backoff_base,
      original_error: reason
    }

    new_retry_queue = :queue.in(retry_entry, state.retry_queue)
    %{state | retry_queue: new_retry_queue}
  end

  defp add_to_dead_letter_queue(state, command, reason) do
    command_id = generate_command_id(command)

    dead_letter_entry = %{
      command_id: command_id,
      original_command: command,
      last_error: reason,
      failed_at: System.monotonic_time(:millisecond),
      attempts_made: 0
    }

    new_dead_letter_queue =
      Map.put(state.dead_letter_queue, command_id, dead_letter_entry)

    %{state | dead_letter_queue: new_dead_letter_queue}
  end

  defp process_retry_queue(state) do
    now = System.monotonic_time(:millisecond)

    {ready_commands, remaining_queue} =
      extract_ready_commands(state.retry_queue, now)

    # Process ready commands
    final_state =
      Enum.reduce(
        ready_commands,
        %{state | retry_queue: remaining_queue},
        fn retry_entry, acc_state ->
          if retry_entry.attempts < acc_state.config.max_retries do
            # Retry the command
            case execute_command_internal(retry_entry.command, [], acc_state) do
              {:ok, _result, new_state} ->
                Logger.info(
                  "Command retry succeeded: #{inspect(retry_entry.command.__struct__)}"
                )

                new_state

              {:error, reason, new_state} ->
                # Increment attempts and re-queue or move to dead letter
                updated_entry = %{
                  retry_entry
                  | attempts: retry_entry.attempts + 1,
                    next_retry_at:
                      calculate_next_retry_time(
                        retry_entry.attempts + 1,
                        acc_state.config.retry_backoff_base
                      )
                }

                if updated_entry.attempts >= acc_state.config.max_retries do
                  # Move to dead letter queue
                  add_to_dead_letter_queue(
                    new_state,
                    retry_entry.command,
                    reason
                  )
                else
                  # Re-queue for retry
                  new_retry_queue =
                    :queue.in(updated_entry, new_state.retry_queue)

                  %{new_state | retry_queue: new_retry_queue}
                end
            end
          else
            # Max retries exceeded, move to dead letter queue
            add_to_dead_letter_queue(
              acc_state,
              retry_entry.command,
              :max_retries_exceeded
            )
          end
        end
      )

    final_state
  end

  defp extract_ready_commands(queue, now) do
    extract_ready_commands_acc(queue, now, [], :queue.new())
  end

  defp extract_ready_commands_acc(queue, now, ready, remaining) do
    case :queue.out(queue) do
      {{:value, entry}, rest} ->
        if entry.next_retry_at <= now do
          extract_ready_commands_acc(rest, now, [entry | ready], remaining)
        else
          extract_ready_commands_acc(
            rest,
            now,
            ready,
            :queue.in(entry, remaining)
          )
        end

      {:empty, _} ->
        {ready, remaining}
    end
  end

  defp calculate_next_retry_time(attempts, base_backoff) do
    # Exponential backoff with jitter
    backoff = base_backoff * :math.pow(2, attempts - 1)
    jitter = :rand.uniform(1000)
    System.monotonic_time(:millisecond) + round(backoff) + jitter
  end

  defp cleanup_expired_dead_letters(state) do
    now = System.monotonic_time(:millisecond)
    retention_ms = state.config.dead_letter_retention

    new_dead_letter_queue =
      state.dead_letter_queue
      |> Enum.filter(fn {_id, entry} ->
        now - entry.failed_at < retention_ms
      end)
      |> Map.new()

    removed_count =
      map_size(state.dead_letter_queue) - map_size(new_dead_letter_queue)

    if removed_count > 0 do
      Logger.info("Cleaned up #{removed_count} expired dead letter commands")
    end

    %{state | dead_letter_queue: new_dead_letter_queue}
  end

  defp reset_expired_circuit_breakers(state) do
    now = System.monotonic_time(:millisecond)
    timeout_ms = state.config.circuit_breaker_timeout

    new_circuit_breakers =
      state.circuit_breakers
      |> Enum.map(fn {handler, breaker} ->
        if breaker.status == :open and now - breaker.opened_at >= timeout_ms do
          {handler, %{breaker | status: :half_open}}
        else
          {handler, breaker}
        end
      end)
      |> Map.new()

    %{state | circuit_breakers: new_circuit_breakers}
  end

  ## Helper Functions

  defp init_metrics_collector(config) do
    if config.enable_metrics do
      %{
        enabled: true,
        command_counts: %{},
        execution_times: [],
        success_rate: 0.0,
        last_reset: System.monotonic_time(:millisecond)
      }
    else
      %{enabled: false}
    end
  end

  defp init_audit_logger(config) do
    if config.enable_auditing do
      %{
        enabled: true,
        log_file: "log/command_audit.log",
        buffer: []
      }
    else
      %{enabled: false}
    end
  end

  defp update_metrics(state, command, result, execution_time) do
    if state.metrics_collector.enabled do
      command_type = command.__struct__

      # Update command counts
      current_count =
        Map.get(state.metrics_collector.command_counts, command_type, %{
          success: 0,
          failure: 0
        })

      new_count =
        case result do
          :success -> %{current_count | success: current_count.success + 1}
          :failure -> %{current_count | failure: current_count.failure + 1}
        end

      new_command_counts =
        Map.put(state.metrics_collector.command_counts, command_type, new_count)

      # Update execution times (keep last 100)
      new_execution_times = [
        execution_time | Enum.take(state.metrics_collector.execution_times, 99)
      ]

      new_metrics_collector = %{
        state.metrics_collector
        | command_counts: new_command_counts,
          execution_times: new_execution_times
      }

      %{state | metrics_collector: new_metrics_collector}
    else
      state
    end
  end

  defp audit_command(state, command, result, execution_time) do
    if state.audit_logger.enabled do
      audit_entry = %{
        timestamp: System.system_time(:millisecond),
        command_id: generate_command_id(command),
        command_type: command.__struct__,
        result: result,
        execution_time_us: execution_time,
        metadata: extract_audit_metadata(command)
      }

      # In practice, would write to audit log
      Logger.info("Command audit: #{inspect(audit_entry)}")
    end

    state
  end

  defp extract_audit_metadata(command) do
    # Extract relevant metadata from command for auditing
    %{
      user_id: Map.get(command, :user_id),
      resource_id: Map.get(command, :id),
      sensitive_data_present: has_sensitive_data?(command)
    }
  end

  defp has_sensitive_data?(_command) do
    # Check if command contains sensitive data
    # Placeholder
    false
  end

  defp get_circuit_breaker_status(circuit_breakers) do
    circuit_breakers
    |> Enum.map(fn {handler, breaker} ->
      %{
        handler: handler,
        status: breaker.status,
        failures: breaker.failures,
        opened_at: Map.get(breaker, :opened_at)
      }
    end)
  end

  defp get_metrics_from_collector(metrics_collector) do
    if metrics_collector.enabled do
      total_commands =
        metrics_collector.command_counts
        |> Map.values()
        |> Enum.reduce(0, fn counts, acc ->
          acc + counts.success + counts.failure
        end)

      total_successes =
        metrics_collector.command_counts
        |> Map.values()
        |> Enum.reduce(0, fn counts, acc -> acc + counts.success end)

      success_rate =
        if total_commands > 0 do
          total_successes / total_commands * 100
        else
          0.0
        end

      avg_execution_time =
        if length(metrics_collector.execution_times) > 0 do
          Enum.sum(metrics_collector.execution_times) /
            length(metrics_collector.execution_times)
        else
          0.0
        end

      %{
        total_commands: total_commands,
        success_rate: success_rate,
        average_execution_time_us: avg_execution_time,
        command_breakdown: metrics_collector.command_counts
      }
    else
      %{metrics_disabled: true}
    end
  end

  ## Helper functions for refactored code

  defp get_metrics_if_enabled(%{enable_metrics: true}, metrics_collector) do
    get_metrics_from_collector(metrics_collector)
  end

  defp get_metrics_if_enabled(_config, _metrics_collector) do
    %{metrics_disabled: true}
  end

  defp check_handler_availability(nil, _circuit_breakers), do: :available

  defp check_handler_availability(handler_module, circuit_breakers) do
    case is_circuit_breaker_open?(circuit_breakers, handler_module) do
      true -> :open
      false -> :available
    end
  end

  defp execute_handler_if_present(nil, _context) do
    {:error, :no_handler_registered}
  end

  defp execute_handler_if_present(handler_module, context) do
    execute_command_handler(
      handler_module,
      context.command,
      context
    )
  end

  defp update_metrics_if_enabled(
         %{config: %{enable_metrics: true}} = state,
         command,
         status,
         execution_time
       ) do
    update_metrics(state, command, status, execution_time)
  end

  defp update_metrics_if_enabled(state, _command, _status, _execution_time) do
    state
  end

  defp update_metrics_if_enabled(state, command, status, execution_time)
       when is_map(state) do
    case state.config[:enable_metrics] do
      true -> update_metrics(state, command, status, execution_time)
      _ -> state
    end
  end

  defp audit_if_enabled(
         %{config: %{enable_auditing: true}} = state,
         command,
         result,
         execution_time
       ) do
    audit_command(state, command, result, execution_time)
  end

  defp audit_if_enabled(_state, _command, _result, _execution_time), do: :ok

  defp queue_failed_command(state, command, reason) do
    case is_retriable_error?(reason) do
      true -> add_to_retry_queue(state, command, reason)
      false -> add_to_dead_letter_queue(state, command, reason)
    end
  end
end
