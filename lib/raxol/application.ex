defmodule Raxol.Application do
  @moduledoc """
  Main application module for Raxol terminal emulator.

  Handles application startup, supervision tree initialization,
  core system configuration, and runtime feature management.

  ## Environment-based Configuration

  The application adapts its behavior based on the environment:
  - `:test` - Minimal supervision tree for testing
  - `:minimal` - Ultra-fast startup with core features only
  - `:dev` - Full feature set with development tools
  - `:prod` - Production configuration with optimizations

  ## Feature Flags

  Features can be enabled/disabled via configuration:

      config :raxol, :features,
        web_interface: true,
        terminal_driver: true,
        plugins: false,
        telemetry: true

  ## Health Monitoring

  The application includes built-in health checks:
  - Supervision tree health
  - Memory usage monitoring
  - Process count tracking
  - Telemetry event monitoring
  """

  use Application
  require Logger
  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Utils.TimerManager

  @type feature_flag :: atom()
  @type start_mode :: :full | :minimal | :custom
  @type child_spec :: Supervisor.child_spec() | {module(), term()} | module()

  @impl Application
  def start(_type, args) do
    start_time = System.monotonic_time(:microsecond)

    # Determine startup mode
    mode = determine_startup_mode(args)

    # Log startup
    log_startup_info(mode)

    # Get children based on mode and configuration
    children = get_children_for_mode(mode)

    # Configure supervisor
    opts = [
      strategy: :one_for_one,
      name: Raxol.Supervisor,
      max_restarts: 10,
      max_seconds: 60
    ]

    # Start supervision tree with error handling
    result = start_supervisor(children, opts)

    # Record startup metrics
    record_startup_metrics(start_time, mode, result)

    # Schedule health checks if enabled
    _health_check_ref = schedule_health_checks(mode)

    result
  end

  @impl Application
  def stop(_state) do
    Logger.info("[Raxol.Application] Shutting down...")
    :ok
  end

  # Startup Mode Detection

  defp determine_startup_mode(args) do
    cond do
      args[:mode] ->
        args[:mode]

      System.get_env("RAXOL_MODE") == "minimal" ->
        :minimal

      Application.get_env(:raxol, :startup_mode) ->
        Application.get_env(:raxol, :startup_mode)

      Mix.env() == :test ->
        :test

      true ->
        :full
    end
  end

  defp log_startup_info(mode) do
    preferences_path = Application.get_env(:raxol, :preferences_path)

    if preferences_path && File.exists?(preferences_path) do
      Raxol.Core.Runtime.Log.info_with_context(
        "Loading preferences from #{preferences_path}",
        %{mode: mode}
      )
    else
      Raxol.Core.Runtime.Log.info_with_context(
        "No preferences file found, using defaults.",
        %{mode: mode}
      )
    end

    Logger.info("[Raxol.Application] Starting in #{mode} mode")
  end

  # Children Configuration

  defp get_children_for_mode(:test) do
    # Minimal children for test environment
    # Tests can start their own processes as needed
    [
      # ETSCacheManager for performance tests
      {Raxol.Performance.ETSCacheManager, []}
    ]
  end

  defp get_children_for_mode(:minimal) do
    # Ultra-minimal for quick startup
    [
      # Core error recovery only
      {Raxol.Core.ErrorRecovery, [mode: :minimal]},
      # Minimal terminal supervisor
      {Raxol.Terminal.Supervisor, [mode: :minimal]},
      # Basic telemetry if enabled
      maybe_add_telemetry(:minimal)
    ]
    |> List.flatten()
    |> Enum.filter(& &1)
  end

  defp get_children_for_mode(:full) do
    # Full feature set
    core_children = get_core_children()
    optional_children = get_optional_children()
    feature_children = get_feature_based_children()

    (core_children ++ optional_children ++ feature_children)
    |> List.flatten()
    |> Enum.filter(& &1)
  end

  defp get_children_for_mode(mode) do
    # Custom mode - read from configuration
    config = Application.get_env(:raxol, :startup_children, %{})

    config
    |> Map.get(mode, [])
    |> validate_children()
  end

  defp get_core_children do
    [
      # Essential services that should always run
      {Raxol.Core.ErrorRecovery, []},
      {Raxol.Core.UserPreferences, []},
      {Raxol.DynamicSupervisor, []},
      {Raxol.Terminal.Supervisor, []},

      # Configuration and Debug services
      {Raxol.Config, []},
      {Raxol.Debug, []},

      # Conditional core services
      maybe_add_repo(),
      maybe_add_pubsub(),
      maybe_add_endpoint()
    ]
  end

  defp get_optional_children do
    [
      # Performance monitoring
      maybe_add_performance_monitoring(),
      # Terminal sync
      maybe_add_terminal_sync(),
      # Rate limiting
      maybe_add_rate_limiting(),
      # Development performance tools
      maybe_add_dev_performance_tools()
    ]
  end

  defp get_feature_based_children do
    features = Application.get_env(:raxol, :features, %{})

    [
      if(features[:terminal_driver], do: get_terminal_driver_children()),
      if(features[:plugins], do: {Raxol.Plugin.Supervisor, []}),
      if(features[:audit], do: {Raxol.Audit.Supervisor, []})
    ]
  end

  # Conditional Child Specifications

  defp maybe_add_repo do
    if feature_enabled?(:database) && module_available?(Raxol.Repo) do
      Raxol.Repo
    else
      if feature_enabled?(:database) do
        Logger.debug(
          "[Raxol.Application] Database feature enabled but Raxol.Repo module not available - continuing without database"
        )
      end

      nil
    end
  end

  defp maybe_add_pubsub do
    if feature_enabled?(:pubsub) do
      {Phoenix.PubSub, name: Raxol.PubSub}
    end
  end

  defp maybe_add_endpoint do
    if feature_enabled?(:web_interface) && module_available?(RaxolWeb.Endpoint) do
      endpoints = [RaxolWeb.Endpoint]

      endpoints =
        if module_available?(RaxolWeb.Telemetry),
          do: [RaxolWeb.Telemetry | endpoints] |> Enum.reverse(),
          else: endpoints

      endpoints
    else
      if feature_enabled?(:web_interface) do
        Logger.debug(
          "[Raxol.Application] Web interface feature enabled but RaxolWeb.Endpoint module not available - continuing without web interface"
        )
      end

      []
    end
  end

  defp maybe_add_performance_monitoring do
    if feature_enabled?(:performance_monitoring) do
      [
        {Raxol.Performance.ETSCacheManager, [hibernate_after: 30_000]},
        {Raxol.Core.Performance.Profiler, [hibernate_after: 30_000]},
        {Raxol.Core.Performance.Monitor, [hibernate_after: 60_000]}
      ]
    end
  end

  defp maybe_add_terminal_sync do
    if feature_enabled?(:terminal_sync) do
      {Raxol.Terminal.Sync.System, []}
    end
  end

  defp maybe_add_rate_limiting do
    if feature_enabled?(:rate_limiting) && feature_enabled?(:web_interface) do
      RaxolWeb.RateLimitManager
    end
  end

  defp maybe_add_telemetry(mode) do
    if feature_enabled?(:telemetry) &&
         module_available?(Raxol.Core.Telemetry.Supervisor) do
      {Raxol.Core.Telemetry.Supervisor, [mode: mode]}
    else
      if feature_enabled?(:telemetry) do
        Logger.debug(
          "[Raxol.Application] Telemetry feature enabled but Raxol.Core.Telemetry.Supervisor module not available - continuing without telemetry"
        )
      end

      nil
    end
  end

  defp maybe_add_dev_performance_tools do
    if Mix.env() == :dev and feature_enabled?(:performance_monitoring) do
      [
        {Raxol.Performance.DevHints, []}
      ]
    else
      []
    end
  end

  defp get_terminal_driver_children do
    case {IO.ANSI.enabled?(), System.get_env("FLY_APP_NAME"),
          System.get_env("RAXOL_MODE"),
          System.get_env("RAXOL_FORCE_TERMINAL")} do
      # Skip terminal driver in minimal mode
      {_, _, "minimal", _} ->
        Logger.info(
          "[Raxol.Application] Minimal mode - terminal driver disabled"
        )

        []

      # Skip terminal driver on Fly.io
      {_, fly_app, _, _} when is_binary(fly_app) ->
        Logger.info(
          "[Raxol.Application] Running on Fly.io (#{fly_app}) - terminal driver disabled"
        )

        []

      # Start terminal driver if TTY is available
      {true, _, _, _} ->
        [{Raxol.Terminal.Driver, nil}]

      # Force terminal driver if explicitly requested
      {false, _, _, "true"} ->
        Logger.warning(
          "[Raxol.Application] Forcing terminal driver despite no TTY"
        )

        [{Raxol.Terminal.Driver, nil}]

      # No TTY and not forced
      {false, _, _, _} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Raxol.Application] Not attached to a TTY. Terminal driver will not be started.",
          %{}
        )

        []
    end
  end

  # Feature Flag Management

  defp feature_enabled?(feature) do
    features = Application.get_env(:raxol, :features, default_features())
    Map.get(features, feature, false)
  end

  defp default_features do
    %{
      # Changed to false for graceful development
      database: false,
      pubsub: true,
      # Changed to false for graceful development
      web_interface: false,
      terminal_driver: true,
      performance_monitoring: true,
      terminal_sync: true,
      rate_limiting: true,
      telemetry: true,
      plugins: false,
      audit: false,
      dev_performance_hints: Mix.env() == :dev
    }
  end

  # Module Availability Checks

  defp module_available?(module) do
    Code.ensure_loaded?(module) && function_exported?(module, :child_spec, 1)
  end

  # Supervisor Starting with Error Handling

  defp start_supervisor(children, opts) do
    try do
      case Supervisor.start_link(children, opts) do
        {:ok, pid} = success ->
          Logger.info(
            "[Raxol.Application] Supervisor started successfully: #{inspect(pid)}"
          )

          success

        {:error, {:shutdown, {:failed_to_start_child, child, reason}}} = error ->
          handle_child_start_failure(child, reason)
          error

        {:error, reason} = error ->
          Logger.error(
            "[Raxol.Application] Failed to start supervisor: #{inspect(reason)}"
          )

          error
      end
    rescue
      exception ->
        Logger.error("""
        [Raxol.Application] Exception during startup:
        #{Exception.format(:error, exception, __STACKTRACE__)}
        """)

        {:error, exception}
    end
  end

  defp handle_child_start_failure(child, reason) do
    Logger.error("""
    [Raxol.Application] Failed to start child: #{inspect(child)}
    Reason: #{inspect(reason)}
    """)

    # Attempt graceful degradation for non-critical services
    if optional_child?(child) do
      Logger.warning(
        "[Raxol.Application] Continuing without optional service: #{inspect(child)}"
      )
    end
  end

  defp optional_child?(child) when is_atom(child) do
    optional_modules = [
      # Added for graceful database degradation
      Raxol.Repo,
      # Added for graceful telemetry degradation
      Raxol.Core.Telemetry.Supervisor,
      # Added for graceful web interface degradation
      RaxolWeb.Endpoint,
      # Added for graceful web telemetry degradation
      RaxolWeb.Telemetry,
      Raxol.Plugin.Supervisor,
      Raxol.Audit.Supervisor,
      RaxolWeb.RateLimitManager,
      Raxol.Terminal.Driver
    ]

    child in optional_modules
  end

  defp optional_child?({child, _}), do: optional_child?(child)
  defp optional_child?(_), do: false

  # Health Monitoring

  defp schedule_health_checks(mode) when mode in [:test, :minimal], do: :ok

  defp schedule_health_checks(_mode) do
    if feature_enabled?(:health_checks) do
      TimerManager.send_after(:perform_health_check, 30_000)
    end
  end

  def handle_info(:perform_health_check, state) do
    perform_health_check()
    _health_check_ref = schedule_health_checks(:full)
    {:noreply, state}
  end

  defp perform_health_check do
    health_data = %{
      supervisor_alive: Process.alive?(Process.whereis(Raxol.Supervisor)),
      child_count: count_children(),
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      timestamp: System.system_time(:second)
    }

    :telemetry.execute(
      [:raxol, :application, :health_check],
      health_data,
      %{}
    )

    check_memory_threshold(health_data.memory_usage)
    check_process_threshold(health_data.process_count)
  end

  defp count_children do
    case Process.whereis(Raxol.Supervisor) do
      nil -> 0
      pid -> Supervisor.count_children(pid).active
    end
  end

  defp check_memory_threshold(memory_bytes) do
    max_memory = Application.get_env(:raxol, :max_memory_mb, 500) * 1_048_576

    if memory_bytes > max_memory do
      Logger.warning("""
      [Raxol.Application] Memory usage exceeds threshold:
      Current: #{div(memory_bytes, 1_048_576)}MB
      Max: #{div(max_memory, 1_048_576)}MB
      """)

      # Trigger garbage collection on all processes
      :erlang.garbage_collect()
    end
  end

  defp check_process_threshold(process_count) do
    max_processes = Application.get_env(:raxol, :max_processes, 10_000)

    if process_count > max_processes do
      Logger.warning("""
      [Raxol.Application] Process count exceeds threshold:
      Current: #{process_count}
      Max: #{max_processes}
      """)
    end
  end

  # Startup Metrics

  defp record_startup_metrics(start_time, mode, result) do
    duration = System.monotonic_time(:microsecond) - start_time
    success = match?({:ok, _}, result)

    :telemetry.execute(
      [:raxol, :application, :startup],
      %{duration: duration},
      %{mode: mode, success: success}
    )

    if success do
      Logger.info("[Raxol.Application] Started in #{duration}μs (#{mode} mode)")
    end
  end

  # Child Validation

  defp validate_children(children) do
    children
    |> Enum.filter(&valid_child_spec?/1)
    |> Enum.map(&normalize_child_spec/1)
  end

  defp valid_child_spec?(spec) when is_atom(spec), do: Code.ensure_loaded?(spec)

  defp valid_child_spec?({module, _args}) when is_atom(module),
    do: Code.ensure_loaded?(module)

  defp valid_child_spec?(%{id: _, start: _}), do: true
  defp valid_child_spec?(_), do: false

  defp normalize_child_spec(module) when is_atom(module), do: module

  defp normalize_child_spec({module, args}) when is_atom(module),
    do: {module, args}

  defp normalize_child_spec(spec), do: spec

  # Memory Optimization Helpers

  @doc false
  def configure_process_flags do
    # Set process flags for memory optimization
    Process.flag(:trap_exit, true)
    Process.flag(:message_queue_data, :off_heap)
    :ok
  end

  @doc """
  Dynamically add a child to the supervision tree.
  """
  @spec add_child(child_spec()) :: {:ok, pid()} | {:error, term()}
  def add_child(child_spec) do
    case Process.whereis(Raxol.DynamicSupervisor) do
      nil ->
        {:error, :dynamic_supervisor_not_started}

      pid ->
        DynamicSupervisor.start_child(pid, child_spec)
    end
  end

  @doc """
  Dynamically remove a child from the supervision tree.
  """
  @spec remove_child(pid() | atom()) ::
          :ok | {:error, :dynamic_supervisor_not_started | :not_found}
  def remove_child(child_id) when is_atom(child_id) do
    case Process.whereis(child_id) do
      nil -> {:error, :not_found}
      pid -> remove_child(pid)
    end
  end

  def remove_child(child_pid) when is_pid(child_pid) do
    case Process.whereis(Raxol.DynamicSupervisor) do
      nil ->
        {:error, :dynamic_supervisor_not_started}

      supervisor_pid ->
        DynamicSupervisor.terminate_child(supervisor_pid, child_pid)
    end
  end

  @doc """
  Get current application health status.
  """
  @spec health_status() :: %{
          mode: atom(),
          supervisor_alive: boolean(),
          children: non_neg_integer(),
          memory_mb: non_neg_integer(),
          process_count: non_neg_integer(),
          features: map(),
          uptime_seconds: integer()
        }
  def health_status do
    %{
      mode: determine_startup_mode([]),
      supervisor_alive:
        Process.alive?(Process.whereis(Raxol.Supervisor) || self()),
      children: count_children(),
      memory_mb: div(:erlang.memory(:total), 1_048_576),
      process_count: :erlang.system_info(:process_count),
      features: Application.get_env(:raxol, :features, default_features()),
      uptime_seconds: System.monotonic_time(:second)
    }
  end

  @doc """
  Toggle a feature flag at runtime.
  Some features require application restart to take effect.
  """
  @spec toggle_feature(feature_flag(), boolean()) ::
          :ok | {:error, :restart_required}
  def toggle_feature(feature, enabled)
      when is_atom(feature) and is_boolean(enabled) do
    current_features =
      Application.get_env(:raxol, :features, default_features())

    new_features = Map.put(current_features, feature, enabled)
    Application.put_env(:raxol, :features, new_features)

    if feature in [:web_interface, :database, :pubsub] do
      {:error, :restart_required}
    else
      :ok
    end
  end
end
