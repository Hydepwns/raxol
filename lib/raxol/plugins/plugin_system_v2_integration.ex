defmodule Raxol.Plugins.PluginSystemV2Integration do
  @moduledoc """
  Integration layer for Plugin System v2.0 - brings together all components.

  This module coordinates:
  - Plugin System v2.0 core
  - Dependency Resolution v2.0
  - Plugin Sandbox security
  - Hot-reload capabilities
  - Marketplace integration
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  alias Raxol.Plugins.{
    PluginSystemV2,
    DependencyResolverV2,
    PluginSandbox,
    HotReloadManager,
    MarketplaceClient
  }

  @type integration_config :: %{
          enable_marketplace: boolean(),
          enable_sandbox: boolean(),
          enable_hot_reload: boolean(),
          default_trust_level: :trusted | :sandboxed | :untrusted,
          plugin_directories: [String.t()],
          security_policies: map()
        }

  defstruct config: nil,
            plugin_system: nil,
            sandbox_manager: nil,
            hot_reload_manager: nil,
            marketplace_client: nil,
            active_plugins: %{},
            startup_complete: false

  # Integration API

  @doc """
  Starts the integrated Plugin System v2.0 with all components.
  """
  def start_system(config \\ default_config()) do
    start_link([{:name, __MODULE__}, {:config, config}])
  end

  @doc """
  Installs a plugin from the marketplace with full integration.
  """
  def install_and_enable_plugin(plugin_id, opts \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:install_and_enable_plugin, plugin_id, opts},
      60_000
    )
  end

  @doc """
  Creates a development plugin with hot-reload enabled.
  """
  def create_development_plugin(plugin_path, opts \\ %{}) do
    GenServer.call(__MODULE__, {:create_development_plugin, plugin_path, opts})
  end

  @doc """
  Gets comprehensive status of the plugin system.
  """
  def get_system_status do
    GenServer.call(__MODULE__, :get_system_status)
  end

  @doc """
  Demonstrates the full plugin lifecycle.
  """
  def run_integration_demo do
    GenServer.call(__MODULE__, :run_integration_demo)
  end

  # Default Configuration

  @doc """
  Returns default configuration for Plugin System v2.0.
  """
  def default_config do
    %{
      enable_marketplace: true,
      enable_sandbox: true,
      enable_hot_reload: true,
      default_trust_level: :sandboxed,
      plugin_directories: [
        "plugins/",
        "~/.raxol/plugins/",
        "/usr/local/share/raxol/plugins/"
      ],
      security_policies: %{
        development: :trusted,
        production: :sandboxed,
        untrusted_sources: :untrusted
      }
    }
  end

  # BaseManager Implementation

  @impl true
  def init_manager(opts) do
    config = Keyword.get(opts, :config, default_config())

    state = %__MODULE__{
      config: config,
      active_plugins: %{},
      startup_complete: false
    }

    # Initialize components asynchronously
    send(self(), {:continue, :initialize_components})
    {:ok, state}
  end

  @impl true
  def handle_manager_info({:continue, :initialize_components}, state) do
    case initialize_all_components(state.config) do
      {:ok, initialized_state} ->
        Logger.info(
          "[PluginSystemV2Integration] All components initialized successfully"
        )

        # Run initial plugin discovery
        spawn(fn -> discover_and_load_plugins() end)

        final_state = %{initialized_state | startup_complete: true}
        {:noreply, final_state}

      {:error, reason} ->
        Logger.error(
          "[PluginSystemV2Integration] Failed to initialize: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:install_and_enable_plugin, plugin_id, opts},
        _from,
        state
      ) do
    case install_and_enable_plugin_impl(plugin_id, opts, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:create_development_plugin, plugin_path, opts},
        _from,
        state
      ) do
    case create_development_plugin_impl(plugin_path, opts, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:get_system_status, _from, state) do
    status = get_comprehensive_status(state)
    {:reply, {:ok, status}, state}
  end

  def handle_manager_call(:run_integration_demo, _from, state) do
    case run_integration_demo_impl(state) do
      {:ok, demo_results} ->
        {:reply, {:ok, demo_results}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Implementation

  defp initialize_all_components(config) do
    Logger.info(
      "[PluginSystemV2Integration] Initializing Plugin System v2.0 components..."
    )

    with {:ok, plugin_system} <- start_plugin_system(config),
         {:ok, sandbox_manager} <- start_sandbox_manager(config),
         {:ok, hot_reload_manager} <- start_hot_reload_manager(config),
         {:ok, marketplace_client} <- start_marketplace_client(config) do
      initialized_state = %__MODULE__{
        config: config,
        plugin_system: plugin_system,
        sandbox_manager: sandbox_manager,
        hot_reload_manager: hot_reload_manager,
        marketplace_client: marketplace_client,
        active_plugins: %{},
        startup_complete: false
      }

      {:ok, initialized_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_plugin_system(config) do
    opts = [
      marketplace_enabled: config.enable_marketplace,
      sandbox_enabled: config.enable_sandbox,
      hot_reload_enabled: config.enable_hot_reload
    ]

    case PluginSystemV2.start_link(opts) do
      {:ok, _pid} ->
        Logger.info("[PluginSystemV2Integration] Plugin System v2.0 started")
        {:ok, :started}

      error ->
        Logger.error(
          "[PluginSystemV2Integration] Failed to start Plugin System: #{inspect(error)}"
        )

        error
    end
  end

  defp start_sandbox_manager(config) do
    if config.enable_sandbox do
      case PluginSandbox.start_link([]) do
        {:ok, _pid} ->
          Logger.info("[PluginSystemV2Integration] Plugin Sandbox started")
          {:ok, :started}

        error ->
          Logger.error(
            "[PluginSystemV2Integration] Failed to start Sandbox: #{inspect(error)}"
          )

          error
      end
    else
      {:ok, :disabled}
    end
  end

  defp start_hot_reload_manager(config) do
    if config.enable_hot_reload do
      opts = [
        hot_reload_enabled: true,
        performance_monitoring: true
      ]

      case HotReloadManager.start_link(opts) do
        {:ok, _pid} ->
          Logger.info("[PluginSystemV2Integration] Hot-Reload Manager started")
          {:ok, :started}

        error ->
          Logger.error(
            "[PluginSystemV2Integration] Failed to start Hot-Reload: #{inspect(error)}"
          )

          error
      end
    else
      {:ok, :disabled}
    end
  end

  defp start_marketplace_client(config) do
    if config.enable_marketplace do
      opts = [
        marketplace_url: "https://plugins.raxol.io/api/v1",
        cache_dir: "/tmp/raxol_plugin_cache"
      ]

      case MarketplaceClient.start_link(opts) do
        {:ok, _pid} ->
          Logger.info("[PluginSystemV2Integration] Marketplace Client started")
          {:ok, :started}

        error ->
          Logger.error(
            "[PluginSystemV2Integration] Failed to start Marketplace: #{inspect(error)}"
          )

          error
      end
    else
      {:ok, :disabled}
    end
  end

  defp install_and_enable_plugin_impl(plugin_id, opts, state) do
    Logger.info("[PluginSystemV2Integration] Installing plugin: #{plugin_id}")

    # Full integration workflow:
    # 1. Search marketplace
    # 2. Verify security
    # 3. Resolve dependencies
    # 4. Create sandbox if needed
    # 5. Install and enable
    # 6. Setup hot-reload if development mode

    with {:ok, plugin_info} <- MarketplaceClient.get_plugin_info(plugin_id),
         {:ok, security_result} <-
           MarketplaceClient.verify_plugin_security(
             plugin_id,
             plugin_info.version
           ),
         :ok <- verify_security_policy(security_result, state.config),
         {:ok, dependencies} <-
           resolve_dependencies_with_conflict_resolution(plugin_info),
         :ok <-
           create_sandbox_if_needed(
             plugin_id,
             security_result.trust_level,
             state
           ),
         :ok <-
           MarketplaceClient.install_plugin(
             plugin_id,
             plugin_info.version,
             opts
           ),
         :ok <- PluginSystemV2.load_plugin(plugin_id, opts),
         :ok <- enable_hot_reload_if_requested(plugin_id, opts, state) do
      # Track active plugin
      plugin_state = %{
        plugin_id: plugin_id,
        version: plugin_info.version,
        trust_level: security_result.trust_level,
        dependencies: dependencies,
        installed_at: DateTime.utc_now(),
        hot_reload_enabled: Map.get(opts, :enable_hot_reload, false)
      }

      updated_active = Map.put(state.active_plugins, plugin_id, plugin_state)
      {:ok, %{state | active_plugins: updated_active}}
    else
      {:error, reason} ->
        Logger.error(
          "[PluginSystemV2Integration] Failed to install #{plugin_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp create_development_plugin_impl(plugin_path, opts, state) do
    plugin_id = extract_plugin_id_from_path(plugin_path)

    Logger.info(
      "[PluginSystemV2Integration] Creating development plugin: #{plugin_id}"
    )

    with :ok <- validate_plugin_path(plugin_path),
         :ok <-
           PluginSandbox.create_sandbox(
             plugin_id,
             PluginSandbox.trusted_policy()
           ),
         :ok <-
           HotReloadManager.enable_hot_reload(
             plugin_id,
             plugin_path,
             HotReloadManager.development_options()
           ),
         :ok <-
           PluginSystemV2.load_plugin(
             plugin_id,
             Map.merge(opts, %{development_mode: true})
           ) do
      # Track development plugin
      plugin_state = %{
        plugin_id: plugin_id,
        version: "dev",
        trust_level: :trusted,
        dependencies: [],
        installed_at: DateTime.utc_now(),
        hot_reload_enabled: true,
        development_mode: true,
        path: plugin_path
      }

      updated_active = Map.put(state.active_plugins, plugin_id, plugin_state)
      {:ok, %{state | active_plugins: updated_active}}
    else
      {:error, reason} ->
        Logger.error(
          "[PluginSystemV2Integration] Failed to create development plugin: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp run_integration_demo_impl(_state) do
    Logger.info(
      "[PluginSystemV2Integration] Running comprehensive integration demo..."
    )

    demo_steps = [
      {"Marketplace Search", fn -> demo_marketplace_search() end},
      {"Plugin Installation", fn -> demo_plugin_installation() end},
      {"Dependency Resolution", fn -> demo_dependency_resolution() end},
      {"Sandbox Security", fn -> demo_sandbox_security() end},
      {"Hot-Reload", fn -> demo_hot_reload() end},
      {"Plugin Lifecycle", fn -> demo_plugin_lifecycle() end}
    ]

    results =
      Enum.map(demo_steps, fn {step_name, step_func} ->
        Logger.info("[Demo] Running step: #{step_name}")

        case step_func.() do
          :ok -> {step_name, :success, nil}
          {:ok, result} -> {step_name, :success, result}
          {:error, reason} -> {step_name, :failed, reason}
        end
      end)

    success_count =
      Enum.count(results, fn {_, status, _} -> status == :success end)

    total_steps = length(results)

    demo_summary = %{
      total_steps: total_steps,
      successful_steps: success_count,
      success_rate: success_count / total_steps * 100,
      results: results,
      timestamp: DateTime.utc_now()
    }

    Logger.info(
      "[Demo] Completed #{success_count}/#{total_steps} steps successfully"
    )

    {:ok, demo_summary}
  end

  # Demo Functions

  defp demo_marketplace_search do
    case MarketplaceClient.search_plugins("terminal", %{category: "Appearance"}) do
      {:ok, results} ->
        Logger.info("[Demo] Found #{length(results)} plugins in marketplace")
        {:ok, results}

      error ->
        error
    end
  end

  defp demo_plugin_installation do
    # Demo installing a mock plugin
    case MarketplaceClient.install_plugin("terminal-themes", "latest") do
      :ok ->
        Logger.info("[Demo] Successfully installed terminal-themes plugin")
        :ok

      error ->
        error
    end
  end

  defp demo_dependency_resolution do
    # Demo dependency resolution
    mock_manifest = %{
      name: "complex-plugin",
      dependencies: [
        {"terminal-themes", "^2.0.0"},
        {"git-integration", "~> 1.5"}
      ]
    }

    case DependencyResolverV2.resolve_dependencies(mock_manifest) do
      {:ok, resolved} ->
        Logger.info("[Demo] Resolved #{length(resolved)} dependencies")
        {:ok, resolved}

      error ->
        error
    end
  end

  defp demo_sandbox_security do
    # Demo sandbox creation and execution
    plugin_id = "demo-untrusted-plugin"
    security_policy = PluginSandbox.untrusted_policy()

    case PluginSandbox.create_sandbox(plugin_id, security_policy) do
      :ok ->
        # Try to execute safe code
        case PluginSandbox.execute_in_sandbox(plugin_id, Enum, :map, [
               [1, 2, 3],
               &(&1 * 2)
             ]) do
          {:ok, result} ->
            Logger.info(
              "[Demo] Sandbox execution successful: #{inspect(result)}"
            )

            :ok

          error ->
            error
        end

      error ->
        error
    end
  end

  defp demo_hot_reload do
    # Demo hot-reload functionality
    plugin_id = "demo-dev-plugin"
    plugin_path = "/tmp/demo_plugin"

    case HotReloadManager.enable_hot_reload(plugin_id, plugin_path) do
      :ok ->
        # Simulate hot-reload
        case HotReloadManager.reload_plugin(plugin_id) do
          :ok ->
            Logger.info("[Demo] Hot-reload completed successfully")
            :ok

          error ->
            error
        end

      error ->
        error
    end
  end

  defp demo_plugin_lifecycle do
    # Demo complete plugin lifecycle
    plugin_id = "lifecycle-demo-plugin"

    lifecycle_steps = [
      {"Load", fn -> PluginSystemV2.load_plugin(plugin_id) end},
      {"Get Status", fn -> PluginSystemV2.get_plugin_status(plugin_id) end},
      {"Hot Reload", fn -> PluginSystemV2.hot_reload_plugin(plugin_id) end}
    ]

    results =
      Enum.map(lifecycle_steps, fn {step, func} ->
        case func.() do
          :ok -> {step, :success}
          {:ok, _} -> {step, :success}
          error -> {step, error}
        end
      end)

    success_count =
      Enum.count(results, fn {_, status} -> status == :success end)

    Logger.info(
      "[Demo] Plugin lifecycle: #{success_count}/#{length(results)} steps successful"
    )

    {:ok, results}
  end

  # Helper Functions

  defp discover_and_load_plugins do
    Logger.info(
      "[PluginSystemV2Integration] Discovering plugins in configured directories..."
    )

    # Mock implementation - would scan plugin directories
    :ok
  end

  defp verify_security_policy(security_result, config) do
    case security_result.trust_level do
      level when level in [:trusted, :verified] -> :ok
      :community when config.default_trust_level != :untrusted -> :ok
      :unverified when config.default_trust_level == :untrusted -> :ok
      _ -> {:error, :security_policy_violation}
    end
  end

  defp resolve_dependencies_with_conflict_resolution(plugin_info) do
    case DependencyResolverV2.resolve_dependencies(plugin_info, %{}) do
      {:ok, dependencies} ->
        {:ok, dependencies}

      {:error, conflicts} ->
        # Attempt conflict resolution
        case DependencyResolverV2.resolve_conflicts(conflicts) do
          {:ok, resolved} -> {:ok, resolved}
          error -> error
        end
    end
  end

  defp create_sandbox_if_needed(plugin_id, trust_level, state) do
    if state.config.enable_sandbox and trust_level != :trusted do
      security_policy =
        case trust_level do
          :sandboxed -> PluginSandbox.sandboxed_policy()
          :untrusted -> PluginSandbox.untrusted_policy()
          _ -> PluginSandbox.sandboxed_policy()
        end

      PluginSandbox.create_sandbox(plugin_id, security_policy)
    else
      :ok
    end
  end

  defp enable_hot_reload_if_requested(plugin_id, opts, state) do
    if state.config.enable_hot_reload and
         Map.get(opts, :enable_hot_reload, false) do
      plugin_path = Map.get(opts, :plugin_path, "/plugins/#{plugin_id}")
      HotReloadManager.enable_hot_reload(plugin_id, plugin_path)
    else
      :ok
    end
  end

  defp get_comprehensive_status(state) do
    %{
      startup_complete: state.startup_complete,
      components: %{
        plugin_system: component_status(state.plugin_system),
        sandbox_manager: component_status(state.sandbox_manager),
        hot_reload_manager: component_status(state.hot_reload_manager),
        marketplace_client: component_status(state.marketplace_client)
      },
      active_plugins: Map.keys(state.active_plugins),
      plugin_count: map_size(state.active_plugins),
      configuration: %{
        marketplace_enabled: state.config.enable_marketplace,
        sandbox_enabled: state.config.enable_sandbox,
        hot_reload_enabled: state.config.enable_hot_reload,
        default_trust_level: state.config.default_trust_level
      }
    }
  end

  defp component_status(:started), do: :active
  defp component_status(:disabled), do: :disabled
  defp component_status(nil), do: :not_initialized
  defp component_status(_), do: :unknown

  defp extract_plugin_id_from_path(plugin_path) do
    plugin_path
    |> Path.basename()
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
  end

  defp validate_plugin_path(plugin_path) do
    if File.exists?(plugin_path) do
      :ok
    else
      {:error, :plugin_path_not_found}
    end
  end
end
