defmodule Raxol.Architecture.CQRS.CommandDispatcher do
  @moduledoc """
  Command dispatcher for the CQRS pattern in Raxol.

  The dispatcher routes commands to their appropriate handlers and manages
  the command execution pipeline, including validation, authorization,
  logging, and error handling.

  ## Features

  - Command routing to registered handlers
  - Command validation and authorization
  - Retry logic with exponential backoff
  - Circuit breaker pattern for fault tolerance
  - Command execution metrics and logging
  - Dead letter queue for failed commands
  - Batch command processing
  - Command correlation and tracing

  ## Usage

      # Start the dispatcher
      {:ok, dispatcher} = CommandDispatcher.start_link()
      
      # Register command handlers
      :ok = CommandDispatcher.register_handler(CreateTerminalCommand, CreateTerminalHandler)
      :ok = CommandDispatcher.register_handler(UpdateTerminalCommand, UpdateTerminalHandler)
      
      # Dispatch a command
      command = CreateTerminalCommand.new(%{user_id: "user_1", width: 80, height: 24})
      {:ok, result} = CommandDispatcher.dispatch(command)
      
      # Batch dispatch multiple commands
      commands = [command1, command2, command3]
      {:ok, results} = CommandDispatcher.dispatch_batch(commands)
  """

  use GenServer
  require Logger

  alias Raxol.Architecture.CQRS.{Command, CommandHandler}

  defstruct [
    :handlers,
    :middleware,
    :config,
    :metrics_collector,
    :circuit_breakers,
    :dead_letter_queue,
    :retry_policies
  ]

  @type command :: Command.t()
  @type handler :: module()
  @type context :: CommandHandler.context()
  @type result :: CommandHandler.result()

  @type config :: %{
          max_retries: non_neg_integer(),
          retry_base_delay_ms: pos_integer(),
          circuit_breaker_threshold: pos_integer(),
          circuit_breaker_timeout_ms: pos_integer(),
          enable_dead_letter_queue: boolean(),
          batch_size_limit: pos_integer()
        }

  @default_config %{
    max_retries: 3,
    retry_base_delay_ms: 1000,
    circuit_breaker_threshold: 5,
    circuit_breaker_timeout_ms: 30_000,
    enable_dead_letter_queue: true,
    batch_size_limit: 100
  }

  ## Client API

  @doc """
  Starts the command dispatcher.
  """
  def start_link(opts \\ []) do
    config = opts |> Enum.into(%{}) |> then(&Map.merge(@default_config, &1))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Registers a command handler for a specific command type.
  """
  def register_handler(dispatcher \\ __MODULE__, command_type, handler_module) do
    GenServer.call(
      dispatcher,
      {:register_handler, command_type, handler_module}
    )
  end

  @doc """
  Unregisters a command handler.
  """
  def unregister_handler(dispatcher \\ __MODULE__, command_type) do
    GenServer.call(dispatcher, {:unregister_handler, command_type})
  end

  @doc """
  Dispatches a single command to its registered handler.
  """
  def dispatch(dispatcher \\ __MODULE__, command, opts \\ []) do
    GenServer.call(dispatcher, {:dispatch, command, opts}, 30_000)
  end

  @doc """
  Dispatches multiple commands as a batch.
  """
  def dispatch_batch(dispatcher \\ __MODULE__, commands, opts \\ []) do
    GenServer.call(dispatcher, {:dispatch_batch, commands, opts}, 60_000)
  end

  @doc """
  Adds middleware to the command processing pipeline.
  """
  def add_middleware(dispatcher \\ __MODULE__, middleware_module) do
    GenServer.call(dispatcher, {:add_middleware, middleware_module})
  end

  @doc """
  Gets dispatcher statistics.
  """
  def get_statistics(dispatcher \\ __MODULE__) do
    GenServer.call(dispatcher, :get_statistics)
  end

  @doc """
  Gets the list of registered handlers.
  """
  def list_handlers(dispatcher \\ __MODULE__) do
    GenServer.call(dispatcher, :list_handlers)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    state = %__MODULE__{
      handlers: %{},
      middleware: [],
      config: config,
      metrics_collector: init_metrics_collector(),
      circuit_breakers: %{},
      dead_letter_queue: :queue.new(),
      retry_policies: %{}
    }

    # Register default handlers
    register_default_handlers(state)

    Logger.info(
      "Command dispatcher initialized with config: #{inspect(config)}"
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:register_handler, command_type, handler_module},
        _from,
        state
      ) do
    case CommandHandler.validate_handler(handler_module) do
      :ok ->
        new_handlers = Map.put(state.handlers, command_type, handler_module)
        new_state = %{state | handlers: new_handlers}

        Logger.info(
          "Registered handler #{inspect(handler_module)} for command #{inspect(command_type)}"
        )

        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.warning(
          "Failed to register handler #{inspect(handler_module)}: #{inspect(reason)}"
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unregister_handler, command_type}, _from, state) do
    new_handlers = Map.delete(state.handlers, command_type)
    new_state = %{state | handlers: new_handlers}

    Logger.info("Unregistered handler for command #{inspect(command_type)}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:dispatch, command, opts}, _from, state) do
    case do_dispatch_command(command, opts, state) do
      {:ok, result, new_state} ->
        {:reply, {:ok, result}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:dispatch_batch, commands, opts}, _from, state) do
    case do_dispatch_batch(commands, opts, state) do
      {:ok, results, new_state} ->
        {:reply, {:ok, results}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:add_middleware, middleware_module}, _from, state) do
    new_middleware = [middleware_module | state.middleware]
    new_state = %{state | middleware: new_middleware}

    Logger.info("Added middleware: #{inspect(middleware_module)}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    stats = %{
      registered_handlers: map_size(state.handlers),
      middleware_count: length(state.middleware),
      circuit_breakers: map_size(state.circuit_breakers),
      dead_letter_queue_size: :queue.len(state.dead_letter_queue),
      metrics: state.metrics_collector
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:list_handlers, _from, state) do
    handlers =
      Enum.map(state.handlers, fn {command_type, handler} ->
        %{command_type: command_type, handler: handler}
      end)

    {:reply, handlers, state}
  end

  ## Private Implementation

  defp do_dispatch_command(command, opts, state) do
    command_type = command.__struct__

    with {:ok, handler} <- get_handler(command_type, state.handlers),
         {:ok, context} <- create_command_context(command, opts),
         {:ok, _} <-
           check_circuit_breaker(command_type, state.circuit_breakers),
         {:ok, result} <-
           execute_command_with_retries(command, handler, context, state) do
      # Update metrics
      new_state =
        update_metrics(state, :command_executed, %{
          command_type: command_type,
          success: true
        })

      # Reset circuit breaker on success
      final_state = reset_circuit_breaker(command_type, new_state)

      {:ok, result, final_state}
    else
      {:error, :handler_not_found} ->
        Logger.warning(
          "No handler registered for command #{inspect(command_type)}"
        )

        error_state =
          update_metrics(state, :command_failed, %{
            command_type: command_type,
            reason: :handler_not_found
          })

        {:error, :handler_not_found, error_state}

      {:error, :circuit_breaker_open} ->
        Logger.warning(
          "Circuit breaker open for command #{inspect(command_type)}"
        )

        error_state =
          update_metrics(state, :command_rejected, %{
            command_type: command_type,
            reason: :circuit_breaker_open
          })

        {:error, :circuit_breaker_open, error_state}

      {:error, reason} ->
        Logger.error(
          "Command dispatch failed for #{inspect(command_type)}: #{inspect(reason)}"
        )

        # Update circuit breaker
        updated_state = update_circuit_breaker(command_type, state)

        # Add to dead letter queue if enabled
        final_state =
          if state.config.enable_dead_letter_queue do
            add_to_dead_letter_queue(command, reason, updated_state)
          else
            updated_state
          end

        # Update metrics
        error_state =
          update_metrics(final_state, :command_failed, %{
            command_type: command_type,
            reason: reason
          })

        {:error, reason, error_state}
    end
  end

  defp do_dispatch_batch(commands, opts, state) do
    if length(commands) > state.config.batch_size_limit do
      {:error, :batch_too_large, state}
    else
      batch_start_time = System.monotonic_time(:microsecond)

      {results, final_state} =
        Enum.reduce(commands, {[], state}, fn command,
                                              {acc_results, acc_state} ->
          case do_dispatch_command(command, opts, acc_state) do
            {:ok, result, new_state} ->
              {[{:ok, result} | acc_results], new_state}

            {:error, reason, new_state} ->
              {[{:error, reason} | acc_results], new_state}
          end
        end)

      batch_time = System.monotonic_time(:microsecond) - batch_start_time

      # Update batch metrics
      metrics_state =
        update_metrics(final_state, :batch_executed, %{
          batch_size: length(commands),
          execution_time_us: batch_time
        })

      {:ok, Enum.reverse(results), metrics_state}
    end
  end

  defp get_handler(command_type, handlers) do
    case Map.get(handlers, command_type) do
      nil -> {:error, :handler_not_found}
      handler -> {:ok, handler}
    end
  end

  defp create_command_context(command, opts) do
    context = CommandHandler.create_context(command, opts)
    {:ok, context}
  end

  defp execute_command_with_retries(command, handler, context, state) do
    max_retries = state.config.max_retries
    execute_with_retry(command, handler, context, state, 0, max_retries)
  end

  defp execute_with_retry(
         command,
         handler,
         context,
         state,
         attempt,
         max_retries
       ) do
    case apply_middleware_and_execute(command, handler, context, state) do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when attempt < max_retries ->
        # Calculate delay with exponential backoff
        delay_ms =
          (state.config.retry_base_delay_ms * :math.pow(2, attempt)) |> round()

        Logger.info(
          "Retrying command after #{delay_ms}ms (attempt #{attempt + 1}/#{max_retries})"
        )

        :timer.sleep(delay_ms)

        execute_with_retry(
          command,
          handler,
          context,
          state,
          attempt + 1,
          max_retries
        )

      {:error, reason} ->
        Logger.error(
          "Command failed after #{max_retries} retries: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp apply_middleware_and_execute(command, handler, context, state) do
    # Build middleware pipeline
    final_handler =
      build_middleware_pipeline(state.middleware, fn cmd, ctx ->
        handler.handle(cmd, ctx)
      end)

    # Execute with the complete pipeline
    final_handler.(command, context)
  end

  defp build_middleware_pipeline(middleware_list, base_handler) do
    Enum.reduce(middleware_list, base_handler, fn middleware, acc_handler ->
      fn command, context ->
        middleware.call(command, context, acc_handler)
      end
    end)
  end

  defp check_circuit_breaker(command_type, circuit_breakers) do
    case Map.get(circuit_breakers, command_type) do
      nil ->
        {:ok, :not_configured}

      %{state: :closed} ->
        {:ok, :closed}

      %{state: :open, opened_at: opened_at, timeout_ms: timeout_ms} ->
        if System.system_time(:millisecond) - opened_at > timeout_ms do
          {:ok, :half_open}
        else
          {:error, :circuit_breaker_open}
        end

      %{state: :half_open} ->
        {:ok, :half_open}
    end
  end

  defp update_circuit_breaker(command_type, state) do
    current_breaker =
      Map.get(state.circuit_breakers, command_type, %{
        state: :closed,
        failure_count: 0,
        threshold: state.config.circuit_breaker_threshold,
        timeout_ms: state.config.circuit_breaker_timeout_ms
      })

    new_failure_count = current_breaker.failure_count + 1

    updated_breaker =
      if new_failure_count >= current_breaker.threshold do
        %{
          current_breaker
          | state: :open,
            failure_count: new_failure_count,
            opened_at: System.system_time(:millisecond)
        }
      else
        %{current_breaker | failure_count: new_failure_count}
      end

    new_circuit_breakers =
      Map.put(state.circuit_breakers, command_type, updated_breaker)

    %{state | circuit_breakers: new_circuit_breakers}
  end

  defp reset_circuit_breaker(command_type, state) do
    case Map.get(state.circuit_breakers, command_type) do
      nil ->
        state

      breaker ->
        reset_breaker = %{breaker | state: :closed, failure_count: 0}

        new_circuit_breakers =
          Map.put(state.circuit_breakers, command_type, reset_breaker)

        %{state | circuit_breakers: new_circuit_breakers}
    end
  end

  defp add_to_dead_letter_queue(command, reason, state) do
    dead_letter_entry = %{
      command: command,
      reason: reason,
      timestamp: System.system_time(:millisecond),
      attempts: 1
    }

    new_queue = :queue.in(dead_letter_entry, state.dead_letter_queue)
    %{state | dead_letter_queue: new_queue}
  end

  defp update_metrics(state, metric_type, _metadata) do
    new_metrics =
      case metric_type do
        :command_executed ->
          %{
            state.metrics_collector
            | commands_executed: state.metrics_collector.commands_executed + 1,
              successful_commands:
                state.metrics_collector.successful_commands + 1
          }

        :command_failed ->
          %{
            state.metrics_collector
            | commands_executed: state.metrics_collector.commands_executed + 1,
              failed_commands: state.metrics_collector.failed_commands + 1
          }

        :command_rejected ->
          %{
            state.metrics_collector
            | rejected_commands: state.metrics_collector.rejected_commands + 1
          }

        :batch_executed ->
          %{
            state.metrics_collector
            | batches_executed: state.metrics_collector.batches_executed + 1
          }
      end

    %{state | metrics_collector: new_metrics}
  end

  defp init_metrics_collector do
    %{
      commands_executed: 0,
      successful_commands: 0,
      failed_commands: 0,
      rejected_commands: 0,
      batches_executed: 0,
      start_time: System.system_time(:millisecond)
    }
  end

  defp register_default_handlers(_state) do
    # This would register the default handlers for terminal commands
    # In a real implementation, this might be done via configuration
    # or dependency injection
    Logger.debug(
      "Default handlers registration skipped - will be done via configuration"
    )

    :ok
  end
end

defmodule Raxol.Architecture.CQRS.CommandMiddleware do
  @moduledoc """
  Base behavior for command middleware.
  """

  @callback call(command :: struct(), context :: map(), next :: function()) ::
              {:ok, term()} | {:error, term()}
end

defmodule Raxol.Architecture.CQRS.Middleware.ValidationMiddleware do
  @moduledoc """
  Middleware for command validation.
  """

  @behaviour Raxol.Architecture.CQRS.CommandMiddleware

  require Logger

  @impl true
  def call(command, context, next) do
    case validate_command(command) do
      :ok ->
        next.(command, context)

      {:error, reason} ->
        Logger.warning("Command validation failed: #{inspect(reason)}")
        {:error, {:validation_failed, reason}}
    end
  end

  defp validate_command(command) do
    # Use the command's own validation if it has one
    if function_exported?(command.__struct__, :validate, 1) do
      command.__struct__.validate(command)
    else
      :ok
    end
  end
end

defmodule Raxol.Architecture.CQRS.Middleware.AuthorizationMiddleware do
  @moduledoc """
  Middleware for command authorization.
  """

  @behaviour Raxol.Architecture.CQRS.CommandMiddleware

  require Logger

  @impl true
  def call(command, context, next) do
    case authorize_command(command, context) do
      :ok ->
        next.(command, context)

      {:error, reason} ->
        Logger.warning("Command authorization failed: #{inspect(reason)}")
        {:error, {:authorization_failed, reason}}
    end
  end

  defp authorize_command(command, context) do
    # Basic authorization check
    user_id = Map.get(context, :user_id)
    command_user_id = Map.get(command, :user_id)

    cond do
      is_nil(user_id) ->
        {:error, :user_not_authenticated}

      user_id != command_user_id ->
        {:error, :user_not_authorized}

      true ->
        :ok
    end
  end
end

defmodule Raxol.Architecture.CQRS.Middleware.LoggingMiddleware do
  @moduledoc """
  Middleware for command execution logging.
  """

  @behaviour Raxol.Architecture.CQRS.CommandMiddleware

  require Logger

  @impl true
  def call(command, context, next) do
    command_type = command.__struct__
    correlation_id = Map.get(context, :correlation_id, "unknown")

    Logger.info(
      "Executing command: #{inspect(command_type)} [#{correlation_id}]"
    )

    start_time = System.monotonic_time(:microsecond)

    case next.(command, context) do
      {:ok, result} ->
        execution_time = System.monotonic_time(:microsecond) - start_time

        Logger.info(
          "Command completed: #{inspect(command_type)} in #{execution_time}μs [#{correlation_id}]"
        )

        {:ok, result}

      {:error, reason} ->
        execution_time = System.monotonic_time(:microsecond) - start_time

        Logger.error(
          "Command failed: #{inspect(command_type)} after #{execution_time}μs - #{inspect(reason)} [#{correlation_id}]"
        )

        {:error, reason}
    end
  end
end
