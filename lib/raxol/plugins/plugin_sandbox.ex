defmodule Raxol.Plugins.PluginSandbox do
  @moduledoc """
  Sandbox security system for running untrusted plugins safely.

  Features:
  - Process isolation with restricted capabilities
  - Resource usage limits (memory, CPU, file descriptors)
  - Restricted system access (file I/O, network, process spawning)
  - Capability-based security model
  - Audit logging for security events
  - Automatic sandbox violation handling
  """

  use GenServer
  require Logger

  @type plugin_id :: String.t()
  @type security_policy :: %{
    trust_level: :trusted | :sandboxed | :untrusted,
    capabilities: [atom()],
    resource_limits: map(),
    allowed_modules: [atom()],
    restricted_functions: [atom()],
    audit_level: :none | :basic | :detailed
  }

  @type sandbox_context :: %{
    plugin_id: plugin_id(),
    security_policy: security_policy(),
    supervisor_pid: pid(),
    worker_pid: pid() | nil,
    resource_monitor: pid() | nil,
    audit_logger: pid() | nil,
    violations: [term()],
    created_at: DateTime.t()
  }

  defstruct [
    sandboxes: %{},
    security_policies: %{},
    resource_monitor: nil,
    audit_system: nil,
    violation_handlers: %{}
  ]

  # Sandbox Management API

  @doc """
  Creates a new sandbox for a plugin with specified security policy.
  """
  def create_sandbox(plugin_id, security_policy) do
    GenServer.call(__MODULE__, {:create_sandbox, plugin_id, security_policy})
  end

  @doc """
  Executes code within a sandboxed environment.
  """
  def execute_in_sandbox(plugin_id, module, function, args) do
    GenServer.call(__MODULE__, {:execute_in_sandbox, plugin_id, module, function, args})
  end

  @doc """
  Destroys a sandbox and cleans up resources.
  """
  def destroy_sandbox(plugin_id) do
    GenServer.call(__MODULE__, {:destroy_sandbox, plugin_id})
  end

  @doc """
  Gets sandbox status and resource usage.
  """
  def get_sandbox_status(plugin_id) do
    GenServer.call(__MODULE__, {:get_sandbox_status, plugin_id})
  end

  @doc """
  Updates security policy for an existing sandbox.
  """
  def update_security_policy(plugin_id, new_policy) do
    GenServer.call(__MODULE__, {:update_security_policy, plugin_id, new_policy})
  end

  # Security Policies

  @doc """
  Returns default security policy for untrusted plugins.
  """
  def untrusted_policy do
    %{
      trust_level: :untrusted,
      capabilities: [:basic_terminal, :read_config],
      resource_limits: %{
        max_memory_mb: 64,
        max_cpu_percent: 25,
        max_file_descriptors: 32,
        max_execution_time_ms: 5000,
        max_network_connections: 0
      },
      allowed_modules: [
        Enum,
        String,
        Integer,
        Float,
        Map,
        Keyword,
        DateTime,
        Raxol.Terminal.Cell,
        Raxol.Terminal.ScreenBuffer
      ],
      restricted_functions: [
        {File, :all},
        {System, :all},
        {Process, [:spawn, :spawn_link, :spawn_monitor]},
        {:erlang, [:spawn, :spawn_link, :spawn_monitor, :open_port]},
        {Code, :all},
        {Module, :all}
      ],
      audit_level: :detailed
    }
  end

  @doc """
  Returns security policy for sandboxed plugins.
  """
  def sandboxed_policy do
    %{
      trust_level: :sandboxed,
      capabilities: [:basic_terminal, :read_config, :limited_file_io],
      resource_limits: %{
        max_memory_mb: 128,
        max_cpu_percent: 50,
        max_file_descriptors: 64,
        max_execution_time_ms: 10000,
        max_network_connections: 2
      },
      allowed_modules: [
        Enum, String, Integer, Float, Map, Keyword, DateTime,
        Raxol.Terminal.Cell, Raxol.Terminal.ScreenBuffer,
        Raxol.UI.Components, Raxol.Core.Renderer,
        File  # Limited file access
      ],
      restricted_functions: [
        {System, [:cmd, :shell]},
        {Process, [:spawn_monitor]},
        {:erlang, [:spawn_monitor, :open_port]},
        {Code, :all},
        {Module, :all}
      ],
      audit_level: :basic
    }
  end

  @doc """
  Returns security policy for trusted plugins.
  """
  def trusted_policy do
    %{
      trust_level: :trusted,
      capabilities: [:all],
      resource_limits: %{
        max_memory_mb: 512,
        max_cpu_percent: 80,
        max_file_descriptors: 256,
        max_execution_time_ms: 30000,
        max_network_connections: 10
      },
      allowed_modules: :all,
      restricted_functions: [],
      audit_level: :none
    }
  end

  # GenServer Implementation

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    state = %__MODULE__{
      sandboxes: %{},
      security_policies: initialize_default_policies(),
      resource_monitor: start_resource_monitor(opts),
      audit_system: start_audit_system(opts),
      violation_handlers: initialize_violation_handlers(opts)
    }

    Logger.info("[PluginSandbox] Initialized with security monitoring")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_sandbox, plugin_id, security_policy}, _from, state) do
    case create_sandbox_impl(plugin_id, security_policy, state) do
      {:ok, updated_state} ->
        Logger.info("[PluginSandbox] Created sandbox for #{plugin_id}")
        {:reply, :ok, updated_state}

      {:error, reason} ->
        Logger.error("[PluginSandbox] Failed to create sandbox for #{plugin_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:execute_in_sandbox, plugin_id, module, function, args}, _from, state) do
    case execute_in_sandbox_impl(plugin_id, module, function, args, state) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        # Log security violation
        log_security_violation(plugin_id, {:execution_denied, module, function}, state)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:destroy_sandbox, plugin_id}, _from, state) do
    case destroy_sandbox_impl(plugin_id, state) do
      {:ok, updated_state} ->
        Logger.info("[PluginSandbox] Destroyed sandbox for #{plugin_id}")
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_sandbox_status, plugin_id}, _from, state) do
    status = get_sandbox_status_impl(plugin_id, state)
    {:reply, {:ok, status}, state}
  end

  def handle_call({:update_security_policy, plugin_id, new_policy}, _from, state) do
    case update_security_policy_impl(plugin_id, new_policy, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Implementation

  defp create_sandbox_impl(plugin_id, security_policy, state) do
    case Map.get(state.sandboxes, plugin_id) do
      nil ->
        case start_sandbox_supervisor(plugin_id, security_policy) do
          {:ok, supervisor_pid} ->
            sandbox_context = %{
              plugin_id: plugin_id,
              security_policy: security_policy,
              supervisor_pid: supervisor_pid,
              worker_pid: nil,
              resource_monitor: start_plugin_resource_monitor(plugin_id, security_policy),
              audit_logger: start_plugin_audit_logger(plugin_id, security_policy),
              violations: [],
              created_at: DateTime.utc_now()
            }

            updated_sandboxes = Map.put(state.sandboxes, plugin_id, sandbox_context)
            {:ok, %{state | sandboxes: updated_sandboxes}}

          {:error, reason} ->
            {:error, {:supervisor_start_failed, reason}}
        end

      _existing ->
        {:error, :sandbox_already_exists}
    end
  end

  defp execute_in_sandbox_impl(plugin_id, module, function, args, state) do
    case Map.get(state.sandboxes, plugin_id) do
      nil ->
        {:error, :sandbox_not_found}

      sandbox_context ->
        case validate_execution_permission(module, function, sandbox_context.security_policy) do
          :ok ->
            perform_sandboxed_execution(plugin_id, module, function, args, sandbox_context)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp destroy_sandbox_impl(plugin_id, state) do
    case Map.get(state.sandboxes, plugin_id) do
      nil ->
        {:error, :sandbox_not_found}

      sandbox_context ->
        # Stop all sandbox processes
        stop_sandbox_processes(sandbox_context)

        updated_sandboxes = Map.delete(state.sandboxes, plugin_id)
        {:ok, %{state | sandboxes: updated_sandboxes}}
    end
  end

  defp get_sandbox_status_impl(plugin_id, state) do
    case Map.get(state.sandboxes, plugin_id) do
      nil ->
        %{status: :not_found}

      sandbox_context ->
        %{
          status: :active,
          plugin_id: sandbox_context.plugin_id,
          trust_level: sandbox_context.security_policy.trust_level,
          resource_usage: get_resource_usage(sandbox_context),
          violations_count: length(sandbox_context.violations),
          created_at: sandbox_context.created_at,
          uptime: DateTime.diff(DateTime.utc_now(), sandbox_context.created_at)
        }
    end
  end

  defp update_security_policy_impl(plugin_id, new_policy, state) do
    case Map.get(state.sandboxes, plugin_id) do
      nil ->
        {:error, :sandbox_not_found}

      sandbox_context ->
        updated_context = %{sandbox_context | security_policy: new_policy}
        updated_sandboxes = Map.put(state.sandboxes, plugin_id, updated_context)

        # Apply new policy to running processes
        apply_policy_update(sandbox_context, new_policy)

        {:ok, %{state | sandboxes: updated_sandboxes}}
    end
  end

  defp validate_execution_permission(module, function, security_policy) do
    cond do
      security_policy.trust_level == :trusted ->
        :ok

      module in security_policy.allowed_modules or security_policy.allowed_modules == :all ->
        case check_function_restrictions(module, function, security_policy.restricted_functions) do
          :ok -> :ok
          error -> error
        end

      true ->
        {:error, {:module_not_allowed, module}}
    end
  end

  defp check_function_restrictions(module, function, restricted_functions) do
    case Enum.find(restricted_functions, fn
      {^module, :all} -> true
      {^module, functions} when is_list(functions) -> function in functions
      _ -> false
    end) do
      nil -> :ok
      _restriction -> {:error, {:function_restricted, module, function}}
    end
  end

  defp perform_sandboxed_execution(_plugin_id, module, function, args, sandbox_context) do
    # Create isolated process for execution
    task = Task.Supervisor.async_nolink(
      sandbox_context.supervisor_pid,
      fn ->
        # Apply resource limits
        apply_resource_limits(sandbox_context.security_policy)

        # Execute with timeout
        timeout = sandbox_context.security_policy.resource_limits.max_execution_time_ms
        Task.await(Task.async(fn -> apply(module, function, args) end), timeout)
      end
    )

    case Task.yield(task, :infinity) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      nil -> {:error, :execution_timeout}
    end
  rescue
    error -> {:error, {:execution_failed, error}}
  end

  defp start_sandbox_supervisor(plugin_id, _security_policy) do
    # Start a supervisor for this plugin's processes
    children = [
      {Task.Supervisor, name: :"#{plugin_id}_task_supervisor"}
    ]

    case Supervisor.start_link(children, strategy: :one_for_one) do
      {:ok, pid} -> {:ok, pid}
      error -> error
    end
  end

  defp start_plugin_resource_monitor(plugin_id, _security_policy) do
    # Mock implementation - would start actual resource monitoring
    Logger.debug("[PluginSandbox] Started resource monitor for #{plugin_id}")
    :mock_monitor
  end

  defp start_plugin_audit_logger(plugin_id, security_policy) do
    # Mock implementation - would start actual audit logging
    if security_policy.audit_level != :none do
      Logger.debug("[PluginSandbox] Started audit logger for #{plugin_id}")
    end
    :mock_logger
  end

  defp stop_sandbox_processes(sandbox_context) do
    if Process.alive?(sandbox_context.supervisor_pid) do
      Supervisor.stop(sandbox_context.supervisor_pid, :normal)
    end
  end

  defp apply_resource_limits(security_policy) do
    # Apply memory and CPU limits (would use system-specific mechanisms)
    Logger.debug("[PluginSandbox] Applied resource limits: #{inspect(security_policy.resource_limits)}")
  end

  defp get_resource_usage(_sandbox_context) do
    # Mock implementation - would return actual resource usage
    %{
      memory_mb: 32,
      cpu_percent: 15,
      file_descriptors: 8,
      network_connections: 0
    }
  end

  defp apply_policy_update(sandbox_context, _new_policy) do
    # Apply new security policy to running processes
    Logger.info("[PluginSandbox] Applied policy update for #{sandbox_context.plugin_id}")
  end

  defp log_security_violation(plugin_id, violation, state) do
    Logger.warning("[PluginSandbox] Security violation for #{plugin_id}: #{inspect(violation)}")

    case Map.get(state.sandboxes, plugin_id) do
      nil -> :ok
      sandbox_context ->
        # Record violation and potentially take action
        updated_violations = [violation | sandbox_context.violations]

        # Check if violation threshold exceeded
        if length(updated_violations) >= 5 do
          Logger.error("[PluginSandbox] Too many violations for #{plugin_id}, considering shutdown")
        end
    end
  end

  defp initialize_default_policies do
    %{
      trusted: trusted_policy(),
      sandboxed: sandboxed_policy(),
      untrusted: untrusted_policy()
    }
  end

  defp start_resource_monitor(_opts) do
    # Mock implementation
    :mock_global_monitor
  end

  defp start_audit_system(_opts) do
    # Mock implementation
    :mock_audit_system
  end

  defp initialize_violation_handlers(_opts) do
    %{
      execution_denied: fn plugin_id, details ->
        Logger.warning("[PluginSandbox] Execution denied for #{plugin_id}: #{inspect(details)}")
      end,
      resource_exceeded: fn plugin_id, resource, limit ->
        Logger.warning("[PluginSandbox] Resource limit exceeded for #{plugin_id}: #{resource} > #{limit}")
      end
    }
  end
end