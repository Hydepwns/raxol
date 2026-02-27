defmodule Raxol.Core.Supervisor do
  @moduledoc """
  Supervisor for all refactored GenServer-based modules.

  This supervisor manages the lifecycle of refactored modules that have
  been converted from Process dictionary usage to proper OTP patterns.

  ## Usage

  Add this supervisor to your application's supervision tree:

      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            # Other children...
            {Raxol.Core.Supervisor, []}
          ]

          opts = [strategy: :one_for_one, name: MyApp.Supervisor]
          Supervisor.start_link(children, opts)
        end
      end

  ## Configuration

  You can configure the refactored modules through application config:

      config :raxol,
        i18n_config: %{
          default_locale: "en",
          available_locales: ["en", "fr", "es", "ar"],
          fallback_locale: "en"
        },
        ux_refinement_config: %{
          # UX refinement configuration
        }
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Get configurations from application env
    i18n_config = Application.get_env(:raxol, :i18n_config, %{})
    ux_config = Application.get_env(:raxol, :ux_refinement_config, %{})

    children = [
      # I18n Server - handles all internationalization
      {Raxol.Core.I18n.I18nServer,
       name: Raxol.Core.I18n.I18nServer, config: i18n_config},

      # UX Refinement Server - handles UX features
      {Raxol.Core.UXRefinement.UxServer,
       name: Raxol.Core.UXRefinement.UxServer, config: ux_config},

      # Focus Manager Server - handles focus management
      {Raxol.Core.FocusManager.FocusServer,
       name: Raxol.Core.FocusManager.FocusServer},

      # Animation State Server - handles animation state management
      {Raxol.Animation.StateServer, name: Raxol.Animation.StateServer},

      # Events Manager Server - handles event management with PubSub pattern
      {Raxol.Core.Events.EventManager.EventManagerServer,
       name: Raxol.Core.Events.EventManager.EventManagerServer},

      # Terminal Window Manager Server - handles window state management
      {Raxol.Terminal.Window.Manager.WindowManagerServer,
       name: Raxol.Terminal.Window.Manager.WindowManagerServer},

      # Keyboard Navigator Server - handles keyboard navigation
      {Raxol.Core.KeyboardNavigator.NavigatorServer,
       name: Raxol.Core.KeyboardNavigator.NavigatorServer},

      # Accessibility Server - unified accessibility features
      {Raxol.Core.Accessibility.AccessibilityServer,
       name: Raxol.Core.Accessibility.AccessibilityServer},

      # Keyboard Shortcuts Server - handles keyboard shortcuts
      {Raxol.Core.KeyboardShortcuts.ShortcutsServer,
       name: Raxol.Core.KeyboardShortcuts.ShortcutsServer},

      # Edge Computing Server - handles edge computing cache, queue, and sync
      {Raxol.Cloud.EdgeComputing.EdgeServer,
       name: Raxol.Cloud.EdgeComputing.EdgeServer},

      # Color System Server - handles theme and color management
      {Raxol.Style.Colors.System.ColorSystemServer,
       name: Raxol.Style.Colors.System.ColorSystemServer},

      # System Updater State Server - handles update state management
      {Raxol.System.Updater.State.UpdaterServer,
       name: Raxol.System.Updater.State.UpdaterServer},

      # Cloud Monitoring Server - unified monitoring system
      {Raxol.Cloud.Monitoring.MonitoringServer,
       name: Raxol.Cloud.Monitoring.MonitoringServer},

      # AI Performance Optimization Server - AI-driven optimizations
      {Raxol.AI.PerformanceOptimization.OptimizationServer,
       name: Raxol.AI.PerformanceOptimization.OptimizationServer},

      # Security User Context Server - manages user context for security operations
      {Raxol.Security.UserContext.ContextServer,
       name: Raxol.Security.UserContext.ContextServer},

      # Performance Memoization Server - manages function memoization cache
      {Raxol.Performance.Memoization.MemoizationServer,
       name: Raxol.Performance.Memoization.MemoizationServer},

      # UI State Management Server - handles store and hooks state
      {Raxol.UI.State.Management.StateManagementServer,
       name: Raxol.UI.State.Management.StateManagementServer},

      # Animation Gestures Server - manages gesture state and animations
      {Raxol.Animation.Gestures.GestureServer,
       name: Raxol.Animation.Gestures.GestureServer}

      # Add more refactored servers as they're created:
    ]

    # Restart strategy:
    # - :one_for_one - If a child process terminates, only that process is restarted
    # - This is appropriate since these services are independent
    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Ensures all refactored servers are running.
  Returns :ok if all are running, or {:error, reasons} if any failed to start.
  """
  def ensure_all_started do
    servers = [
      Raxol.Core.I18n.I18nServer,
      Raxol.Core.UXRefinement.UxServer,
      Raxol.Core.FocusManager.FocusServer,
      Raxol.Animation.StateServer,
      Raxol.Core.Events.EventManager.EventManagerServer,
      Raxol.Terminal.Window.Manager.WindowManagerServer,
      Raxol.Core.KeyboardNavigator.NavigatorServer,
      Raxol.Core.Accessibility.AccessibilityServer,
      Raxol.Core.KeyboardShortcuts.ShortcutsServer,
      # Removed experimental servers: EdgeComputing, CloudMonitoring, AI, Svelte
      Raxol.Style.Colors.System.ColorSystemServer,
      Raxol.System.Updater.State.UpdaterServer,
      Raxol.Security.UserContext.ContextServer,
      Raxol.Performance.Memoization.MemoizationServer,
      Raxol.UI.State.Management.StateManagementServer,
      Raxol.Animation.Gestures.GestureServer
    ]

    results =
      Enum.map(servers, fn server ->
        check_server_health(server)
      end)

    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    case length(errors) do
      0 -> :ok
      _ -> {:error, errors}
    end
  end

  @doc """
  Get the status of all refactored servers.
  """
  def status do
    servers = [
      {Raxol.Core.I18n.I18nServer, "I18n"},
      {Raxol.Core.UXRefinement.UxServer, "UX Refinement"},
      {Raxol.Core.FocusManager.FocusServer, "Focus Manager"},
      {Raxol.Animation.StateServer, "Animation State"},
      {Raxol.Core.Events.EventManager.EventManagerServer, "Events Manager"},
      {Raxol.Terminal.Window.Manager.WindowManagerServer, "Window Manager"},
      {Raxol.Core.KeyboardNavigator.NavigatorServer, "Keyboard Navigator"},
      {Raxol.Core.Accessibility.AccessibilityServer, "Accessibility"},
      {Raxol.Core.KeyboardShortcuts.ShortcutsServer, "Keyboard Shortcuts"},
      # Removed experimental servers: EdgeComputing, CloudMonitoring, AI, Svelte
      {Raxol.Style.Colors.System.ColorSystemServer, "Color System"},
      {Raxol.System.Updater.State.UpdaterServer, "Updater State"},
      {Raxol.Security.UserContext.ContextServer, "Security User Context"},
      {Raxol.Performance.Memoization.MemoizationServer,
       "Performance Memoization"},
      {Raxol.UI.State.Management.StateManagementServer, "UI State Management"},
      {Raxol.Animation.Gestures.GestureServer, "Animation Gestures"}
    ]

    Enum.map(servers, fn {server, name} ->
      status = get_server_status(server)
      {name, status}
    end)
  end

  @doc """
  Restart a specific refactored server.
  """
  def restart_server(server_name) when is_atom(server_name) do
    case Process.whereis(server_name) do
      nil ->
        {:error, :not_found}

      _pid ->
        _ = Supervisor.terminate_child(__MODULE__, server_name)
        Supervisor.restart_child(__MODULE__, server_name)
    end
  end

  defp check_server_health(server) do
    case Process.whereis(server) do
      nil ->
        {:error, {server, :not_started}}

      pid when is_pid(pid) ->
        check_pid_alive(server, pid)
    end
  end

  defp check_pid_alive(server, pid) do
    case Process.alive?(pid) do
      true -> {:ok, server}
      false -> {:error, {server, :not_alive}}
    end
  end

  defp get_server_status(server) do
    case Process.whereis(server) do
      nil ->
        :not_started

      pid when is_pid(pid) ->
        get_pid_status(pid)
    end
  end

  defp get_pid_status(pid) do
    case Process.alive?(pid) do
      true -> :running
      false -> :dead
    end
  end
end
