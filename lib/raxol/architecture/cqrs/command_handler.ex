defmodule Raxol.Architecture.CQRS.CommandHandler do
  @moduledoc """
  Command handler behaviour for CQRS pattern implementation in Raxol.

  Command handlers are responsible for processing commands and executing
  the business logic associated with write operations. Each handler
  should focus on a single command type and maintain consistency.

  ## Handler Design Principles

  1. **Single Responsibility**: One handler per command type
  2. **Business Logic Focus**: Contain domain logic, not infrastructure concerns
  3. **Idempotent**: Handlers should be safe to retry
  4. **Event Generation**: Generate domain events for state changes
  5. **Error Handling**: Provide meaningful error messages

  ## Usage

      defmodule MyApp.Handlers.CreateUserHandler do
        use Raxol.Architecture.CQRS.CommandHandler

        alias MyApp.Commands.CreateUserCommand
        alias MyApp.Events.UserCreatedEvent
        alias MyApp.Repositories.UserRepository

        @impl true
        def handle(%CreateUserCommand{} = command, context) do
          with {:ok, user} <- UserRepository.create(command),
               {:ok, event} <- create_user_created_event(user, command),
               :ok <- publish_event(event, context) do
            {:ok, %{user_id: user.id, status: :created}}
          else
            {:error, :user_already_exists} ->
              {:error, :user_already_exists}
            {:error, reason} ->
              {:error, {:user_creation_failed, reason}}
          end
        end

        defp create_user_created_event(user, command) do
          event = %UserCreatedEvent{
            user_id: user.id,
            name: user.name,
            email: user.email,
            created_by: command.created_by,
            correlation_id: command.correlation_id
          }
          {:ok, event}
        end
      end
  """

  alias Raxol.Architecture.EventSourcing.EventStore
  alias Raxol.Core.Runtime.Log

  @type command :: struct()
  @type context :: map()
  @type result :: {:ok, term()} | {:error, term()}

  @callback handle(command(), context()) :: result()

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Architecture.CQRS.CommandHandler

      import Raxol.Architecture.CQRS.CommandHandler

      @doc """
      Publishes a domain event through the event store.
      """
      def publish_event(event, context) do
        case EventStore.append_event(event, get_stream_name(event), context) do
          {:ok, _event_id} ->
            :ok

          {:error, reason} ->
            Log.error(
              "Failed to publish event #{inspect(event.__struct__)}: #{inspect(reason)}"
            )

            {:error, :event_publication_failed}
        end
      end

      @doc """
      Publishes multiple domain events as a batch.
      """
      def publish_events(events, context) when is_list(events) do
        case EventStore.append_events(
               EventStore,
               events,
               get_batch_stream_name(events),
               context
             ) do
          {:ok, _event_ids} ->
            :ok

          {:error, reason} ->
            Log.error("Failed to publish events batch: #{inspect(reason)}")

            {:error, :events_publication_failed}
        end
      end

      @doc """
      Validates business rules before processing command.
      """
      def validate_business_rules(command, rules) when is_list(rules) do
        case Enum.find(rules, fn rule -> not rule.(command) end) do
          nil -> :ok
          _failed_rule -> {:error, :business_rule_violation}
        end
      end

      @doc """
      Executes a command handler with error handling and logging.
      """
      def execute_with_handling(command, context, handler_fn) do
        start_time = System.monotonic_time(:microsecond)
        command_type = command.__struct__

        Log.info("Processing command: #{inspect(command_type)}")

        case Raxol.Core.ErrorHandling.safe_call(fn ->
               handler_fn.(command, context)
             end) do
          {:ok, result} ->
            execution_time = System.monotonic_time(:microsecond) - start_time

            case result do
              {:ok, data} ->
                Log.info(
                  "Command processed successfully: #{inspect(command_type)} in #{execution_time}μs"
                )

                {:ok, data}

              {:error, reason} ->
                Log.warning(
                  "Command failed: #{inspect(command_type)} - #{inspect(reason)}"
                )

                {:error, reason}
            end

          {:error, error} ->
            execution_time = System.monotonic_time(:microsecond) - start_time

            Log.error(
              "Command handler crashed: #{inspect(command_type)} after #{execution_time}μs - #{inspect(error)}"
            )

            {:error, {:handler_crashed, error}}
        end
      end

      # Default stream name generation
      defp get_stream_name(event) do
        event.__struct__
        |> Module.split()
        |> List.last()
        |> String.replace("Event", "")
        |> Macro.underscore()
      end

      defp get_batch_stream_name(events) when is_list(events) do
        case events do
          [first_event | _] -> get_stream_name(first_event)
          [] -> "empty_batch"
        end
      end
    end
  end

  @doc """
  Creates a command handler context with metadata.
  """
  def create_context(command, opts \\ []) do
    %{
      command_id: Map.get(command, :command_id),
      correlation_id: Map.get(command, :correlation_id),
      user_id: Map.get(command, :user_id) || Map.get(command, :created_by),
      timestamp: System.system_time(:millisecond),
      metadata: Map.get(command, :metadata, %{}),
      trace_id: Keyword.get(opts, :trace_id, generate_trace_id()),
      span_id: Keyword.get(opts, :span_id, generate_span_id()),
      retry_count: Keyword.get(opts, :retry_count, 0)
    }
  end

  @doc """
  Validates command handler requirements.
  """
  def validate_handler(handler_module) do
    with true <- Code.ensure_loaded?(handler_module),
         true <- function_exported?(handler_module, :handle, 2) do
      :ok
    else
      false ->
        validate_handler_error(Code.ensure_loaded?(handler_module))
    end
  end

  @doc """
  Creates a standardized error response.
  """
  def error_response(error_type, details \\ nil) do
    %{
      error: error_type,
      details: details,
      timestamp: System.system_time(:millisecond),
      error_id: generate_error_id()
    }
  end

  @doc """
  Creates a standardized success response.
  """
  def success_response(data \\ nil) do
    %{
      status: :success,
      data: data,
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  Wraps a function with transaction support.
  """
  def with_transaction(repo, fun) when is_function(fun, 0) do
    repo.transaction(fun)
  end

  def with_transaction(repo, fun) when is_function(fun, 1) do
    repo.transaction(fn ->
      fun.(repo)
    end)
  end

  @doc """
  Applies optimistic locking to prevent concurrent modifications.
  """
  def with_optimistic_lock(resource, expected_version, update_fn) do
    handle_version_check(
      resource.version == expected_version,
      resource,
      update_fn
    )
  end

  @doc """
  Validates command preconditions.
  """
  def validate_preconditions(command, preconditions)
      when is_list(preconditions) do
    failed_preconditions =
      Enum.filter(preconditions, fn {_name, check_fn} ->
        case check_fn.(command) do
          true -> false
          false -> true
          {:error, _} -> true
        end
      end)

    handle_precondition_validation(
      Enum.empty?(failed_preconditions),
      failed_preconditions
    )
  end

  @doc """
  Executes compensating actions for command failures.
  """
  def execute_compensation(compensations, context)
      when is_list(compensations) do
    Enum.reduce_while(compensations, :ok, fn compensation_fn, _acc ->
      case compensation_fn.(context) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          Log.error("Compensation failed: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Creates a command handling pipeline.
  """
  def create_pipeline(steps) when is_list(steps) do
    fn command, context ->
      Enum.reduce_while(steps, {:ok, command, context}, fn step,
                                                           {_status, cmd, ctx} ->
        process_pipeline_step(step, cmd, ctx)
      end)
    end
  end

  @doc """
  Adds command handling middleware.
  """
  def add_middleware(handler_fn, middleware_fns) when is_list(middleware_fns) do
    Enum.reduce(middleware_fns, handler_fn, fn middleware_fn, acc_handler ->
      fn command, context ->
        middleware_fn.(command, context, acc_handler)
      end
    end)
  end

  ## Private Helper Functions

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)
  end

  defp generate_error_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  ## Common Command Handler Patterns

  @doc """
  Creates a CRUD command handler pattern.
  """
  def crud_handler(repo, entity_module) do
    %{
      create: fn command, _context ->
        case repo.insert(struct(entity_module, Map.from_struct(command))) do
          {:ok, entity} -> {:ok, entity}
          {:error, changeset} -> {:error, {:validation_failed, changeset}}
        end
      end,
      update: fn command, _context ->
        with {:ok, entity} <- repo.get(entity_module, command.id),
             {:ok, updated} <- repo.update(entity, Map.from_struct(command)) do
          {:ok, updated}
        else
          {:error, :not_found} -> {:error, :entity_not_found}
          {:error, changeset} -> {:error, {:validation_failed, changeset}}
        end
      end,
      delete: fn command, _context ->
        case repo.delete(entity_module, command.id) do
          {:ok, entity} -> {:ok, entity}
          {:error, :not_found} -> {:error, :entity_not_found}
          {:error, reason} -> {:error, reason}
        end
      end
    }
  end

  @doc """
  Creates a saga command handler for distributed transactions.
  """
  def saga_handler(saga_steps) when is_list(saga_steps) do
    fn command, context ->
      execute_saga(saga_steps, command, context, [])
    end
  end

  defp execute_saga([], _command, _context, completed_steps) do
    {:ok, %{saga_completed: true, steps: length(completed_steps)}}
  end

  defp execute_saga([step | remaining_steps], command, context, completed_steps) do
    case step.(command, context) do
      {:ok, result} ->
        execute_saga(remaining_steps, command, context, [
          result | completed_steps
        ])

      {:error, reason} ->
        # Execute compensations for completed steps
        compensate_saga_steps(completed_steps)
        {:error, {:saga_failed, reason}}
    end
  end

  defp compensate_saga_steps(completed_steps) do
    Enum.each(completed_steps, fn step_result ->
      case Map.get(step_result, :compensation) do
        nil -> :ok
        compensation_fn -> compensation_fn.()
      end
    end)
  end

  # Helper functions to eliminate if statements

  defp validate_handler_error(true), do: {:error, :missing_handle_function}

  defp validate_handler_error(false), do: {:error, :handler_not_loaded}

  defp handle_version_check(false, _resource, _update_fn) do
    {:error, :version_mismatch}
  end

  defp handle_version_check(true, resource, update_fn) do
    case update_fn.(resource) do
      {:ok, updated_resource} ->
        {:ok, %{updated_resource | version: resource.version + 1}}

      error ->
        error
    end
  end

  defp handle_precondition_validation(true, _failed_preconditions), do: :ok

  defp handle_precondition_validation(false, failed_preconditions) do
    failed_names = Enum.map(failed_preconditions, &elem(&1, 0))
    {:error, {:precondition_failed, failed_names}}
  end

  defp process_pipeline_step(step, cmd, ctx) do
    case step.(cmd, ctx) do
      {:ok, updated_cmd, updated_ctx} ->
        {:cont, {:ok, updated_cmd, updated_ctx}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end
end
