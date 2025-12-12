defmodule Raxol.Web.FlowEngine do
  @moduledoc """
  Declarative DSL for complex user interaction flows.

  Enables defining multi-step user interactions as composable
  flow definitions. Uses monadic composition patterns for
  sequencing and error handling.

  ## Features

  - Declarative flow definition DSL
  - Automatic state management
  - Conditional branching
  - Parallel execution
  - Error recovery and retry logic

  ## Example

      defmodule MyApp.LoginFlow do
        use Raxol.Web.FlowEngine

        flow :login do
          step :get_username, fn ctx ->
            prompt(ctx, "Username: ")
          end

          step :get_password, fn ctx ->
            prompt(ctx, "Password: ", echo: false)
          end

          step :authenticate, fn ctx ->
            authenticate(ctx.username, ctx.password)
          end

          on_success :show_welcome
          on_failure :show_error
        end
      end
  """

  @type context :: map()
  @type step_result :: {:ok, context()} | {:error, term()} | {:halt, term()}
  @type step_fn :: (context() -> step_result())

  defmodule Step do
    @moduledoc false
    defstruct [:name, :function, :options]
  end

  defmodule Flow do
    @moduledoc false
    defstruct [
      :name,
      :steps,
      :on_success,
      :on_failure,
      :on_cancel,
      :timeout,
      :retry_policy
    ]
  end

  defmodule Context do
    @moduledoc """
    Execution context for a flow.
    """
    defstruct [
      :flow_name,
      :current_step,
      :data,
      :history,
      :started_at,
      :status
    ]

    @type t :: %__MODULE__{
            flow_name: atom(),
            current_step: atom() | nil,
            data: map(),
            history: [{atom(), term()}],
            started_at: integer(),
            status: :running | :completed | :failed | :cancelled
          }
  end

  # ============================================================================
  # DSL Macros
  # ============================================================================

  @doc """
  Import the flow DSL into a module.

  ## Example

      defmodule MyFlows do
        use Raxol.Web.FlowEngine
      end
  """
  defmacro __using__(_opts) do
    quote do
      import Raxol.Web.FlowEngine,
        only: [
          flow: 2,
          step: 2,
          step: 3,
          on_success: 1,
          on_failure: 1,
          on_cancel: 1
        ]

      Module.register_attribute(__MODULE__, :flows, accumulate: true)
      Module.register_attribute(__MODULE__, :current_flow_steps, [])

      @before_compile Raxol.Web.FlowEngine
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    flows = Module.get_attribute(env.module, :flows, [])

    # Build an index of flows for lookup
    flow_index =
      flows |> Enum.with_index() |> Map.new(fn {f, i} -> {f.name, i} end)

    flow_functions =
      Enum.map(flows, fn flow ->
        idx = flow_index[flow.name]

        quote do
          def get_flow(unquote(flow.name)) do
            Enum.at(@flows, unquote(idx))
          end
        end
      end)

    flow_names = Enum.map(flows, & &1.name)

    quote do
      unquote_splicing(flow_functions)

      def get_flow(_name), do: nil

      def list_flows do
        unquote(flow_names)
      end
    end
  end

  @doc """
  Define a flow with the given name and steps.

  ## Example

      flow :checkout do
        step :cart, &validate_cart/1
        step :payment, &process_payment/1
        step :confirm, &send_confirmation/1
      end
  """
  defmacro flow(name, do: block) do
    quote do
      Module.delete_attribute(__MODULE__, :current_flow_steps)
      Module.register_attribute(__MODULE__, :current_flow_steps, [])
      @current_flow_steps []
      @current_flow_on_success nil
      @current_flow_on_failure nil
      @current_flow_on_cancel nil

      unquote(block)

      @flows %Raxol.Web.FlowEngine.Flow{
        name: unquote(name),
        steps: @current_flow_steps |> List.flatten() |> Enum.reverse(),
        on_success: @current_flow_on_success,
        on_failure: @current_flow_on_failure,
        on_cancel: @current_flow_on_cancel
      }
    end
  end

  @doc """
  Define a step in the current flow.

  ## Example

      step :validate, fn ctx ->
        if valid?(ctx.data), do: {:ok, ctx}, else: {:error, :invalid}
      end

      step :process, &MyModule.process/1, timeout: 5000
  """
  defmacro step(name, function, opts \\ []) do
    quote do
      @current_flow_steps [
        %Raxol.Web.FlowEngine.Step{
          name: unquote(name),
          function: unquote(function),
          options: unquote(opts)
        }
        | @current_flow_steps
      ]
    end
  end

  @doc """
  Set the success handler for the current flow.
  """
  defmacro on_success(handler) do
    quote do
      @current_flow_on_success unquote(handler)
    end
  end

  @doc """
  Set the failure handler for the current flow.
  """
  defmacro on_failure(handler) do
    quote do
      @current_flow_on_failure unquote(handler)
    end
  end

  @doc """
  Set the cancel handler for the current flow.
  """
  defmacro on_cancel(handler) do
    quote do
      @current_flow_on_cancel unquote(handler)
    end
  end

  # ============================================================================
  # Runtime API
  # ============================================================================

  @doc """
  Start executing a flow.

  ## Options

    - `:initial_data` - Initial context data
    - `:timeout` - Overall flow timeout in ms

  ## Example

      {:ok, ctx} = FlowEngine.start(MyFlows, :login, initial_data: %{})
  """
  @spec start(module(), atom(), keyword()) ::
          {:ok, Context.t()} | {:error, term()}
  def start(module, flow_name, opts \\ []) do
    case module.get_flow(flow_name) do
      nil ->
        {:error, :flow_not_found}

      flow ->
        initial_data = Keyword.get(opts, :initial_data, %{})

        ctx = %Context{
          flow_name: flow_name,
          current_step: nil,
          data: initial_data,
          history: [],
          started_at: System.monotonic_time(:millisecond),
          status: :running
        }

        execute_flow(flow, ctx)
    end
  end

  @doc """
  Execute a single step function.

  ## Example

      {:ok, new_ctx} = FlowEngine.execute_step(step_fn, ctx)
  """
  @spec execute_step(step_fn(), context()) :: step_result()
  def execute_step(step_fn, ctx) when is_function(step_fn, 1) do
    try do
      case step_fn.(ctx) do
        {:ok, new_ctx} when is_map(new_ctx) -> {:ok, new_ctx}
        {:error, _} = error -> error
        {:halt, _} = halt -> halt
        other -> {:error, {:invalid_step_result, other}}
      end
    rescue
      e -> {:error, {:step_exception, e}}
    end
  end

  @doc """
  Chain multiple steps together.

  Executes steps in sequence, passing context through.
  Stops on first error.

  ## Example

      {:ok, final_ctx} = FlowEngine.chain([step1, step2, step3], initial_ctx)
  """
  @spec chain([step_fn()], context()) :: step_result()
  def chain(steps, ctx) when is_list(steps) do
    Enum.reduce_while(steps, {:ok, ctx}, fn step_fn, {:ok, current_ctx} ->
      case execute_step(step_fn, current_ctx) do
        {:ok, new_ctx} -> {:cont, {:ok, new_ctx}}
        {:error, _} = error -> {:halt, error}
        {:halt, _} = halt -> {:halt, halt}
      end
    end)
  end

  @doc """
  Execute steps in parallel.

  All steps receive the same initial context.
  Results are merged into a single context.

  ## Example

      {:ok, merged_ctx} = FlowEngine.parallel([step1, step2], ctx)
  """
  @spec parallel([step_fn()], context()) :: step_result()
  def parallel(steps, ctx) when is_list(steps) do
    tasks =
      Enum.map(steps, fn step_fn ->
        Task.async(fn -> execute_step(step_fn, ctx) end)
      end)

    results = Task.await_many(tasks, 30_000)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      merged_data =
        results
        |> Enum.map(fn {:ok, result_ctx} -> result_ctx end)
        |> Enum.reduce(ctx, fn result_ctx, acc ->
          Map.merge(acc, result_ctx)
        end)

      {:ok, merged_data}
    else
      List.first(errors)
    end
  end

  @doc """
  Create a conditional branch in a flow.

  ## Example

      branch_step = FlowEngine.branch(
        fn ctx -> ctx.user_type == :admin end,
        &admin_flow/1,
        &user_flow/1
      )
  """
  @spec branch((context() -> boolean()), step_fn(), step_fn()) :: step_fn()
  def branch(condition_fn, then_step, else_step) do
    fn ctx ->
      if condition_fn.(ctx) do
        execute_step(then_step, ctx)
      else
        execute_step(else_step, ctx)
      end
    end
  end

  @doc """
  Create a retry wrapper around a step.

  ## Options

    - `:max_attempts` - Maximum retry attempts (default: 3)
    - `:delay` - Delay between retries in ms (default: 1000)
    - `:backoff` - Backoff multiplier (default: 2)

  ## Example

      retry_step = FlowEngine.retry(&unreliable_step/1, max_attempts: 5)
  """
  @spec retry(step_fn(), keyword()) :: step_fn()
  def retry(step_fn, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    delay = Keyword.get(opts, :delay, 1000)
    backoff = Keyword.get(opts, :backoff, 2)

    fn ctx ->
      do_retry(step_fn, ctx, max_attempts, delay, backoff, 1)
    end
  end

  @doc """
  Create a timeout wrapper around a step.

  ## Example

      timed_step = FlowEngine.timeout(&slow_step/1, 5000)
  """
  @spec timeout(step_fn(), pos_integer()) :: step_fn()
  def timeout(step_fn, timeout_ms) do
    fn ctx ->
      task = Task.async(fn -> execute_step(step_fn, ctx) end)

      case Task.yield(task, timeout_ms) || Task.shutdown(task) do
        {:ok, result} -> result
        nil -> {:error, :timeout}
      end
    end
  end

  @doc """
  Transform context data within a flow.

  ## Example

      transform_step = FlowEngine.transform(fn ctx ->
        Map.put(ctx, :processed, true)
      end)
  """
  @spec transform((context() -> context())) :: step_fn()
  def transform(transform_fn) when is_function(transform_fn, 1) do
    fn ctx ->
      {:ok, transform_fn.(ctx)}
    end
  end

  @doc """
  Validate context against a schema.

  ## Example

      validate_step = FlowEngine.validate([:username, :password])
  """
  @spec validate([atom()] | (context() -> boolean())) :: step_fn()
  def validate(required_keys) when is_list(required_keys) do
    fn ctx ->
      missing = Enum.reject(required_keys, &Map.has_key?(ctx, &1))

      if Enum.empty?(missing) do
        {:ok, ctx}
      else
        {:error, {:missing_keys, missing}}
      end
    end
  end

  def validate(validator_fn) when is_function(validator_fn, 1) do
    fn ctx ->
      if validator_fn.(ctx) do
        {:ok, ctx}
      else
        {:error, :validation_failed}
      end
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp execute_flow(%Flow{steps: steps} = flow, ctx) do
    result =
      Enum.reduce_while(steps, {:ok, ctx}, fn step, {:ok, current_ctx} ->
        step_ctx = %{current_ctx | current_step: step.name}

        case execute_step_with_options(step, step_ctx) do
          {:ok, new_ctx} ->
            updated_ctx = %{
              new_ctx
              | history: [{step.name, :ok} | new_ctx.history]
            }

            {:cont, {:ok, updated_ctx}}

          {:error, reason} ->
            updated_ctx = %{
              step_ctx
              | history: [{step.name, {:error, reason}} | step_ctx.history],
                status: :failed
            }

            {:halt, {:error, reason, updated_ctx}}

          {:halt, reason} ->
            updated_ctx = %{
              step_ctx
              | history: [{step.name, {:halt, reason}} | step_ctx.history],
                status: :cancelled
            }

            {:halt, {:halt, reason, updated_ctx}}
        end
      end)

    case result do
      {:ok, final_ctx} ->
        completed_ctx = %{final_ctx | status: :completed, current_step: nil}
        handle_completion(flow, completed_ctx, :success)

      {:error, reason, failed_ctx} ->
        handle_completion(flow, failed_ctx, {:failure, reason})

      {:halt, reason, halted_ctx} ->
        handle_completion(flow, halted_ctx, {:cancel, reason})
    end
  end

  defp execute_step_with_options(%Step{function: fun, options: opts}, ctx) do
    step_fn =
      case Keyword.get(opts, :timeout) do
        nil -> fun
        timeout_ms -> timeout(fun, timeout_ms)
      end

    step_fn =
      case Keyword.get(opts, :retry) do
        nil -> step_fn
        retry_opts -> retry(step_fn, retry_opts)
      end

    execute_step(step_fn, ctx)
  end

  defp handle_completion(%Flow{on_success: handler}, ctx, :success)
       when not is_nil(handler) do
    if is_function(handler, 1) do
      handler.(ctx)
    end

    {:ok, ctx}
  end

  defp handle_completion(%Flow{on_failure: handler}, ctx, {:failure, _reason})
       when not is_nil(handler) do
    if is_function(handler, 1) do
      handler.(ctx)
    end

    {:error, ctx}
  end

  defp handle_completion(%Flow{on_cancel: handler}, ctx, {:cancel, _reason})
       when not is_nil(handler) do
    if is_function(handler, 1) do
      handler.(ctx)
    end

    {:halt, ctx}
  end

  defp handle_completion(_flow, ctx, :success), do: {:ok, ctx}
  defp handle_completion(_flow, ctx, {:failure, _}), do: {:error, ctx}
  defp handle_completion(_flow, ctx, {:cancel, _}), do: {:halt, ctx}

  defp do_retry(_step_fn, _ctx, max_attempts, _delay, _backoff, attempt)
       when attempt > max_attempts do
    {:error, {:max_retries_exceeded, attempt - 1}}
  end

  defp do_retry(step_fn, ctx, max_attempts, delay, backoff, attempt) do
    case execute_step(step_fn, ctx) do
      {:ok, _} = success ->
        success

      {:error, _reason} ->
        if attempt < max_attempts do
          Process.sleep(delay)

          do_retry(
            step_fn,
            ctx,
            max_attempts,
            delay * backoff,
            backoff,
            attempt + 1
          )
        else
          {:error, {:max_retries_exceeded, attempt}}
        end

      {:halt, _} = halt ->
        halt
    end
  end
end
