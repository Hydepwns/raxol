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
      {Raxol.Core.I18n.Server, 
       name: Raxol.Core.I18n.Server, 
       config: i18n_config},
      
      # UX Refinement Server - handles UX features
      {Raxol.Core.UXRefinement.Server, 
       name: Raxol.Core.UXRefinement.Server,
       config: ux_config},
      
      # Focus Manager Server - handles focus management
      {Raxol.Core.FocusManager.Server, 
       name: Raxol.Core.FocusManager.Server},
      
      # Animation State Server - handles animation state management  
      {Raxol.Animation.StateServer,
       name: Raxol.Animation.StateServer},
      
      # Events Manager Server - handles event management with PubSub pattern
      {Raxol.Core.Events.Manager.Server,
       name: Raxol.Core.Events.Manager.Server},
      
      # Terminal Window Manager Server - handles window state management
      {Raxol.Terminal.Window.Manager.Server,
       name: Raxol.Terminal.Window.Manager.Server},
      
      # Keyboard Navigator Server - handles keyboard navigation
      {Raxol.Core.KeyboardNavigator.Server,
       name: Raxol.Core.KeyboardNavigator.Server},
      
      # Accessibility Server - unified accessibility features
      {Raxol.Core.Accessibility.Server,
       name: Raxol.Core.Accessibility.Server},
      
      # Keyboard Shortcuts Server - handles keyboard shortcuts
      {Raxol.Core.KeyboardShortcuts.Server,
       name: Raxol.Core.KeyboardShortcuts.Server},
      
      # Edge Computing Server - handles edge computing cache, queue, and sync
      {Raxol.Cloud.EdgeComputing.Server,
       name: Raxol.Cloud.EdgeComputing.Server},
      
      # Color System Server - handles theme and color management
      {Raxol.Style.Colors.System.Server,
       name: Raxol.Style.Colors.System.Server},
      
      # System Updater State Server - handles update state management
      {Raxol.System.Updater.State.Server,
       name: Raxol.System.Updater.State.Server},
      
      # Cloud Monitoring Server - unified monitoring system
      {Raxol.Cloud.Monitoring.Server,
       name: Raxol.Cloud.Monitoring.Server},
      
      # AI Performance Optimization Server - AI-driven optimizations
      {Raxol.AI.PerformanceOptimization.Server,
       name: Raxol.AI.PerformanceOptimization.Server},
      
      # Security User Context Server - manages user context for security operations
      {Raxol.Security.UserContext.Server,
       name: Raxol.Security.UserContext.Server},
      
      # Performance Memoization Server - manages function memoization cache
      {Raxol.Core.Performance.Memoization.Server,
       name: Raxol.Core.Performance.Memoization.Server},
      
      # UI State Management Server - handles store and hooks state
      {Raxol.UI.State.Management.Server,
       name: Raxol.UI.State.Management.Server},
      
      # Svelte Component State Server - manages component slots
      {Raxol.Svelte.ComponentState.Server,
       name: Raxol.Svelte.ComponentState.Server},
      
      # Animation Gestures Server - manages gesture state and animations
      {Raxol.Animation.Gestures.Server,
       name: Raxol.Animation.Gestures.Server},
      
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
      Raxol.Core.I18n.Server,
      Raxol.Core.UXRefinement.Server,
      Raxol.Core.FocusManager.Server,
      Raxol.Animation.StateServer,
      Raxol.Core.Events.Manager.Server,
      Raxol.Terminal.Window.Manager.Server,
      Raxol.Core.KeyboardNavigator.Server,
      Raxol.Core.Accessibility.Server,
      Raxol.Core.KeyboardShortcuts.Server,
      Raxol.Cloud.EdgeComputing.Server,
      Raxol.Style.Colors.System.Server,
      Raxol.System.Updater.State.Server,
      Raxol.Cloud.Monitoring.Server,
      Raxol.AI.PerformanceOptimization.Server,
      Raxol.Security.UserContext.Server,
      Raxol.Core.Performance.Memoization.Server,
      Raxol.UI.State.Management.Server,
      Raxol.Svelte.ComponentState.Server,
      Raxol.Animation.Gestures.Server
    ]
    
    results = Enum.map(servers, fn server ->
      case Process.whereis(server) do
        nil -> {:error, {server, :not_started}}
        pid when is_pid(pid) -> 
          if Process.alive?(pid) do
            {:ok, server}
          else
            {:error, {server, :not_alive}}
          end
      end
    end)
    
    errors = Enum.filter(results, fn
      {:error, _} -> true
      _ -> false
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, errors}
    end
  end
  
  @doc """
  Get the status of all refactored servers.
  """
  def status do
    servers = [
      {Raxol.Core.I18n.Server, "I18n"},
      {Raxol.Core.UXRefinement.Server, "UX Refinement"},
      {Raxol.Core.FocusManager.Server, "Focus Manager"},
      {Raxol.Animation.StateServer, "Animation State"},
      {Raxol.Core.Events.Manager.Server, "Events Manager"},
      {Raxol.Terminal.Window.Manager.Server, "Window Manager"},
      {Raxol.Core.KeyboardNavigator.Server, "Keyboard Navigator"},
      {Raxol.Core.Accessibility.Server, "Accessibility"},
      {Raxol.Core.KeyboardShortcuts.Server, "Keyboard Shortcuts"},
      {Raxol.Cloud.EdgeComputing.Server, "Edge Computing"},
      {Raxol.Style.Colors.System.Server, "Color System"},
      {Raxol.System.Updater.State.Server, "Updater State"},
      {Raxol.Cloud.Monitoring.Server, "Cloud Monitoring"},
      {Raxol.AI.PerformanceOptimization.Server, "AI Performance Optimization"},
      {Raxol.Security.UserContext.Server, "Security User Context"},
      {Raxol.Core.Performance.Memoization.Server, "Performance Memoization"},
      {Raxol.UI.State.Management.Server, "UI State Management"},
      {Raxol.Svelte.ComponentState.Server, "Svelte Component State"},
      {Raxol.Animation.Gestures.Server, "Animation Gestures"}
    ]
    
    Enum.map(servers, fn {server, name} ->
      status = case Process.whereis(server) do
        nil -> :not_started
        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            :running
          else
            :dead
          end
      end
      
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
        Supervisor.terminate_child(__MODULE__, server_name)
        Supervisor.restart_child(__MODULE__, server_name)
    end
  end
end