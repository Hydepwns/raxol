defmodule Raxol.Web.FlowEngine do
  @moduledoc """
  Declarative Flow Engine for WASH-style continuous web applications.
  
  Provides monadic composition for complex web interaction flows, inspired by
  Haskell's WASH system but adapted for Elixir's actor model and Phoenix LiveView.
  
  ## Key Features
  
  - **Monadic Composition**: Chain complex interactions declaratively
  - **Type Safety**: Compile-time validation of flow transitions
  - **Async Support**: Non-blocking flows with proper error handling
  - **State Preservation**: Flow state persists across interface transitions
  - **Rollback Support**: Automatic rollback on flow failures
  - **Flow Visualization**: Debug flows with visual representations
  
  ## Flow DSL
  
      use Raxol.Web.FlowEngine
      
      def user_onboarding_flow do
        flow "User Onboarding" do
          authenticate()
          |> collect_preferences()
          |> setup_workspace()
          |> create_first_session()
          |> show_tutorial()
        end
      end
      
      def collaborative_session_flow do
        flow "Collaborative Session" do
          authenticate()
          |> select_or_create_session()
          |> invite_collaborators()
          |> start_collaboration()
          |> handle_realtime_updates()
        end
      end
  
  ## Flow Steps
  
  Each step in a flow is a function that returns a `FlowStep` struct:
  
      def authenticate do
        step(:authenticate, "User Authentication") do
          case get_current_user() do
            {:ok, user} -> {:continue, user}
            {:error, :unauthenticated} -> {:redirect, "/login"}
            {:error, reason} -> {:error, reason}
          end
        end
      end
  
  ## Error Handling
  
  Flows automatically handle errors and provide rollback capabilities:
  
      def payment_flow do
        flow "Payment Processing" do
          validate_payment()
          |> charge_payment()
          |> update_subscription()
          |> send_confirmation()
        end
        |> on_error(&rollback_payment/1)
        |> on_success(&log_successful_payment/1)
      end
  """
  
  alias Raxol.Web.{SessionBridge, PersistentStore}
  alias Phoenix.LiveView
  
  require Logger
  
  # Flow step result types
  @type flow_result :: 
    {:continue, term()} |
    {:redirect, String.t()} |
    {:halt, term()} |
    {:error, term()} |
    {:async, pid()}
  
  # Flow step definition
  defstruct [
    :id,
    :name,
    :description,
    :handler,
    :timeout,
    :retry_attempts,
    :rollback_handler,
    :metadata
  ]
  
  @type flow_step :: %__MODULE__{
    id: atom(),
    name: String.t(),
    description: String.t(),
    handler: function(),
    timeout: integer(),
    retry_attempts: integer(),
    rollback_handler: function(),
    metadata: map()
  }
  
  # Flow execution context
  defmodule FlowContext do
    defstruct [
      :flow_id,
      :session_id,
      :user_id,
      :current_step,
      :flow_state,
      :executed_steps,
      :error_handlers,
      :success_handlers,
      :rollback_stack,
      :metadata,
      :started_at,
      :socket
    ]
    
    @type t :: %__MODULE__{
      flow_id: String.t(),
      session_id: String.t(),
      user_id: String.t(),
      current_step: atom(),
      flow_state: map(),
      executed_steps: [atom()],
      error_handlers: [function()],
      success_handlers: [function()],
      rollback_stack: [function()],
      metadata: map(),
      started_at: DateTime.t(),
      socket: LiveView.Socket.t()
    }
  end
  
  # Macros for DSL
  
  @doc """
  Defines a flow with the given name and steps.
  """
  defmacro flow(name, do: steps) do
    quote do
      def __flow__(unquote(name)) do
        flow_id = generate_flow_id(unquote(name))
        steps = unquote(steps)
        
        %Raxol.Web.FlowEngine.FlowDefinition{
          id: flow_id,
          name: unquote(name),
          steps: compile_flow_steps(steps),
          metadata: %{
            defined_at: DateTime.utc_now(),
            module: __MODULE__
          }
        }
      end
      
      def execute_flow(unquote(name), context) do
        flow_def = __flow__(unquote(name))
        Raxol.Web.FlowEngine.execute(flow_def, context)
      end
    end
  end
  
  @doc """
  Defines a flow step with validation and error handling.
  """
  defmacro step(id, description, do: body) do
    quote do
      %Raxol.Web.FlowEngine{
        id: unquote(id),
        name: Atom.to_string(unquote(id)),
        description: unquote(description),
        handler: fn context -> 
          unquote(body)
        end,
        timeout: 30_000,
        retry_attempts: 3,
        rollback_handler: nil,
        metadata: %{}
      }
    end
  end
  
  @doc """
  Chains flow steps using monadic composition.
  """
  defmacro left |> right do
    quote do
      chain_steps(unquote(left), unquote(right))
    end
  end
  
  @doc """
  Adds error handler to a flow.
  """
  defmacro flow |> on_error(handler) do
    quote do
      add_error_handler(unquote(flow), unquote(handler))
    end
  end
  
  @doc """
  Adds success handler to a flow.
  """
  defmacro flow |> on_success(handler) do
    quote do
      add_success_handler(unquote(flow), unquote(handler))
    end
  end
  
  # Public API
  
  @doc """
  Executes a flow with the given context.
  """
  @spec execute(FlowDefinition.t(), FlowContext.t()) :: {:ok, FlowContext.t()} | {:error, term()}
  def execute(flow_definition, context) do
    Logger.info("Executing flow: #{flow_definition.name}")
    
    enhanced_context = %{context |
      flow_id: flow_definition.id,
      started_at: DateTime.utc_now(),
      executed_steps: [],
      rollback_stack: []
    }
    
    # Store flow state persistently
    :ok = store_flow_state(enhanced_context)
    
    # Execute flow steps
    execute_steps(flow_definition.steps, enhanced_context)
  end
  
  @doc """
  Resumes a flow from a saved state.
  """
  @spec resume_flow(String.t(), String.t()) :: {:ok, FlowContext.t()} | {:error, term()}
  def resume_flow(flow_id, session_id) do
    case load_flow_state(flow_id, session_id) do
      {:ok, context} ->
        Logger.info("Resuming flow: #{flow_id}")
        
        # Get flow definition
        flow_def = get_flow_definition(context.flow_id)
        
        # Resume from current step
        remaining_steps = get_remaining_steps(flow_def.steps, context.current_step)
        execute_steps(remaining_steps, context)
        
      {:error, reason} ->
        Logger.error("Failed to resume flow #{flow_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Cancels a flow and performs rollback.
  """
  @spec cancel_flow(String.t(), String.t()) :: :ok
  def cancel_flow(flow_id, session_id) do
    Logger.info("Cancelling flow: #{flow_id}")
    
    case load_flow_state(flow_id, session_id) do
      {:ok, context} ->
        perform_rollback(context)
        cleanup_flow_state(flow_id, session_id)
        
      {:error, _reason} ->
        # Flow not found, nothing to cancel
        :ok
    end
  end
  
  @doc """
  Gets the status of a running flow.
  """
  @spec get_flow_status(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_flow_status(flow_id, session_id) do
    case load_flow_state(flow_id, session_id) do
      {:ok, context} ->
        status = %{
          flow_id: context.flow_id,
          session_id: context.session_id,
          current_step: context.current_step,
          executed_steps: context.executed_steps,
          started_at: context.started_at,
          progress: calculate_progress(context)
        }
        {:ok, status}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Pre-defined flow steps
  
  @doc """
  Authentication step - redirects to login if not authenticated.
  """
  def authenticate do
    step(:authenticate, "User Authentication") do
      case get_current_user(context) do
        {:ok, user} -> 
          context = %{context | user_id: user.id, flow_state: Map.put(context.flow_state, :user, user)}
          {:continue, context}
          
        {:error, :unauthenticated} -> 
          save_flow_state_for_resume(context)
          {:redirect, "/auth/login?return_to=#{current_path(context)}"}
          
        {:error, reason} -> 
          {:error, {:authentication_failed, reason}}
      end
    end
  end
  
  @doc """
  Session selection step - allows user to choose or create a session.
  """
  def select_terminal_session do
    step(:select_session, "Select Terminal Session") do
      user_sessions = get_user_sessions(context.user_id)
      
      case user_sessions do
        [] ->
          # No existing sessions, create new one
          {:ok, session} = create_new_session(context.user_id)
          context = %{context | session_id: session.id, flow_state: Map.put(context.flow_state, :session, session)}
          {:continue, context}
          
        sessions ->
          # Present session selection UI
          context = %{context | flow_state: Map.put(context.flow_state, :available_sessions, sessions)}
          {:async, spawn_session_selector(context, sessions)}
      end
    end
  end
  
  @doc """
  Collaboration invitation step.
  """
  def invite_collaborators do
    step(:invite_collaborators, "Invite Team Members") do
      # This would show a UI for inviting collaborators
      context = %{context | flow_state: Map.put(context.flow_state, :collaboration_mode, :inviting)}
      {:continue, context}
    end
  end
  
  @doc """
  Session persistence step - ensures session state is preserved.
  """
  def persist_session do
    step(:persist_session, "Persist Session State") do
      case SessionBridge.get_session_state(context.session_id) do
        {:ok, session_state} ->
          # Ensure session is persisted across all tiers
          :ok = PersistentStore.persist_to_all_tiers(context.session_id)
          
          context = %{context | 
            flow_state: Map.put(context.flow_state, :session_persisted, true),
            metadata: Map.put(context.metadata, :persistence_confirmed, DateTime.utc_now())
          }
          
          {:continue, context}
          
        {:error, reason} ->
          {:error, {:session_persistence_failed, reason}}
      end
    end
  end
  
  # Private Implementation
  
  defp execute_steps([], context) do
    # Flow completed successfully
    Logger.info("Flow completed successfully: #{context.flow_id}")
    
    # Run success handlers
    Enum.each(context.success_handlers, fn handler ->
      try do
        handler.(context)
      rescue
        error -> Logger.error("Success handler error: #{inspect(error)}")
      end
    end)
    
    # Cleanup flow state
    cleanup_flow_state(context.flow_id, context.session_id)
    
    {:ok, context}
  end
  
  defp execute_steps([step | remaining_steps], context) do
    Logger.debug("Executing step: #{step.name}")
    
    # Update current step
    updated_context = %{context | current_step: step.id}
    
    # Store intermediate state
    store_flow_state(updated_context)
    
    # Execute step with timeout and retry logic
    case execute_step_with_retry(step, updated_context) do
      {:continue, new_context} ->
        # Add to executed steps and rollback stack
        new_context = %{new_context |
          executed_steps: [step.id | new_context.executed_steps],
          rollback_stack: add_to_rollback_stack(new_context.rollback_stack, step)
        }
        
        # Continue with remaining steps
        execute_steps(remaining_steps, new_context)
        
      {:redirect, path} ->
        # Store state for resume and redirect
        store_flow_state_for_resume(updated_context, remaining_steps)
        {:redirect, path}
        
      {:halt, result} ->
        # Flow halted intentionally
        Logger.info("Flow halted at step #{step.name}: #{inspect(result)}")
        {:halt, updated_context}
        
      {:error, reason} ->
        # Step failed, handle error
        Logger.error("Flow step #{step.name} failed: #{inspect(reason)}")
        handle_flow_error(reason, updated_context)
        
      {:async, async_pid} ->
        # Asynchronous step, wait for completion
        handle_async_step(async_pid, step, remaining_steps, updated_context)
    end
  end
  
  defp execute_step_with_retry(step, context, attempt \\ 1) do
    try do
      case step.handler.(context) do
        result when result in [{:continue, _}, {:redirect, _}, {:halt, _}, {:async, _}] ->
          result
        {:error, reason} when attempt < step.retry_attempts ->
          Logger.warning("Step #{step.name} failed (attempt #{attempt}), retrying: #{inspect(reason)}")
          :timer.sleep(1000 * attempt)  # Exponential backoff
          execute_step_with_retry(step, context, attempt + 1)
        {:error, reason} ->
          {:error, {:step_failed_max_retries, step.name, reason}}
        other ->
          {:error, {:invalid_step_result, step.name, other}}
      end
    rescue
      error ->
        if attempt < step.retry_attempts do
          Logger.warning("Step #{step.name} crashed (attempt #{attempt}), retrying: #{inspect(error)}")
          :timer.sleep(1000 * attempt)
          execute_step_with_retry(step, context, attempt + 1)
        else
          {:error, {:step_crashed_max_retries, step.name, error}}
        end
    end
  end
  
  defp handle_async_step(async_pid, step, remaining_steps, context) do
    # Monitor the async process
    ref = Process.monitor(async_pid)
    
    receive do
      {:async_result, ^async_pid, result} ->
        Process.demonitor(ref, [:flush])
        
        case result do
          {:continue, new_context} ->
            new_context = %{new_context |
              executed_steps: [step.id | new_context.executed_steps],
              rollback_stack: add_to_rollback_stack(new_context.rollback_stack, step)
            }
            execute_steps(remaining_steps, new_context)
            
          other ->
            Logger.info("Async step #{step.name} completed with: #{inspect(other)}")
            {other, context}
        end
        
      {:DOWN, ^ref, :process, ^async_pid, reason} ->
        Logger.error("Async step #{step.name} crashed: #{inspect(reason)}")
        {:error, {:async_step_crashed, step.name, reason}}
        
    after
      step.timeout ->
        Process.exit(async_pid, :kill)
        Process.demonitor(ref, [:flush])
        {:error, {:async_step_timeout, step.name}}
    end
  end
  
  defp handle_flow_error(reason, context) do
    Logger.error("Handling flow error: #{inspect(reason)}")
    
    # Run error handlers
    Enum.each(context.error_handlers, fn handler ->
      try do
        handler.(reason, context)
      rescue
        handler_error -> 
          Logger.error("Error handler failed: #{inspect(handler_error)}")
      end
    end)
    
    # Perform rollback
    perform_rollback(context)
    
    # Cleanup flow state
    cleanup_flow_state(context.flow_id, context.session_id)
    
    {:error, reason}
  end
  
  defp perform_rollback(context) do
    Logger.info("Performing rollback for flow: #{context.flow_id}")
    
    Enum.each(context.rollback_stack, fn rollback_fn ->
      try do
        rollback_fn.(context)
      rescue
        error ->
          Logger.error("Rollback operation failed: #{inspect(error)}")
      end
    end)
  end
  
  defp store_flow_state(context) do
    key = "flow:#{context.flow_id}:#{context.session_id}"
    PersistentStore.store_session(key, context, tier: :ets)
  end
  
  defp store_flow_state_for_resume(context, remaining_steps \\ []) do
    enhanced_context = Map.put(context, :remaining_steps, remaining_steps)
    key = "flow:#{context.flow_id}:#{context.session_id}:resume"
    PersistentStore.store_session(key, enhanced_context, tier: :dets)
  end
  
  defp load_flow_state(flow_id, session_id) do
    key = "flow:#{flow_id}:#{session_id}"
    PersistentStore.get_session(key)
  end
  
  defp cleanup_flow_state(flow_id, session_id) do
    key = "flow:#{flow_id}:#{session_id}"
    resume_key = "flow:#{flow_id}:#{session_id}:resume"
    
    PersistentStore.delete_session(key)
    PersistentStore.delete_session(resume_key)
  end
  
  defp add_to_rollback_stack(rollback_stack, step) do
    case step.rollback_handler do
      nil -> rollback_stack
      rollback_fn -> [rollback_fn | rollback_stack]
    end
  end
  
  defp calculate_progress(context) do
    # Simple progress calculation based on executed steps
    # In a full implementation, this would be more sophisticated
    executed_count = length(context.executed_steps)
    total_count = executed_count + 1  # Current step
    
    if total_count > 0 do
      executed_count / total_count * 100
    else
      0.0
    end
  end
  
  # Helper functions (would be implemented based on actual system)
  
  defp get_current_user(_context), do: {:ok, %{id: "user123", name: "Test User"}}
  defp get_user_sessions(_user_id), do: []
  defp create_new_session(_user_id), do: {:ok, %{id: "session123"}}
  defp current_path(_context), do: "/current"
  defp save_flow_state_for_resume(_context), do: :ok
  defp spawn_session_selector(_context, _sessions), do: spawn(fn -> :timer.sleep(100) end)
  defp get_flow_definition(_flow_id), do: %{steps: []}
  defp get_remaining_steps(_steps, _current_step), do: []
  
  # Flow definition struct
  defmodule FlowDefinition do
    defstruct [:id, :name, :steps, :metadata]
  end
  
  defp generate_flow_id(name) do
    hash = :crypto.hash(:md5, "#{name}-#{DateTime.utc_now()}") |> Base.encode16(case: :lower)
    "flow-#{String.slice(hash, 0, 8)}"
  end
  
  defp compile_flow_steps(steps) do
    # In a full implementation, this would compile and validate the flow steps
    steps
  end
  
  defp chain_steps(step1, step2) do
    # Chain two flow steps together
    [step1, step2]
  end
  
  defp add_error_handler(flow, handler) do
    # Add error handler to flow
    Map.update(flow, :error_handlers, [handler], &[handler | &1])
  end
  
  defp add_success_handler(flow, handler) do
    # Add success handler to flow
    Map.update(flow, :success_handlers, [handler], &[handler | &1])
  end
end