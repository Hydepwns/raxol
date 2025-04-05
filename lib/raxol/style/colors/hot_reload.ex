defmodule Raxol.Style.Colors.HotReload do
  @moduledoc """
  Provides hot-reloading functionality for color themes.
  
  This module monitors theme files for changes and automatically reloads them
  when modifications are detected. It supports both file-based and database-backed
  themes, with configurable polling intervals and change detection strategies.
  """
  
  alias Raxol.Style.Colors.{Theme, Persistence}
  
  use GenServer
  
  @default_poll_interval 1000  # 1 second
  
  defstruct [
    :theme_path,
    :last_modified,
    :poll_interval,
    :subscribers
  ]
  
  @doc """
  Starts the hot-reload server.
  
  ## Parameters
  
  - `opts` - Configuration options
  
  ## Options
  
  - `:theme_path` - Path to the theme file to monitor (default: from Persistence)
  - `:poll_interval` - How often to check for changes (default: 1000ms)
  
  ## Examples
  
      iex> HotReload.start_link(theme_path: "/path/to/theme.json")
      {:ok, #PID<0.123.0>}
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Stops the hot-reload server.
  
  ## Examples
  
      iex> HotReload.stop()
      :ok
  """
  def stop do
    GenServer.stop(__MODULE__)
  end
  
  @doc """
  Subscribes to theme change notifications.
  
  ## Examples
  
      iex> HotReload.subscribe()
      :ok
  """
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end
  
  @doc """
  Unsubscribes from theme change notifications.
  
  ## Examples
  
      iex> HotReload.unsubscribe()
      :ok
  """
  def unsubscribe do
    GenServer.call(__MODULE__, :unsubscribe)
  end
  
  @doc """
  Forces a theme reload.
  
  ## Examples
  
      iex> HotReload.reload()
      :ok
  """
  def reload do
    GenServer.cast(__MODULE__, :reload)
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    theme_path = Keyword.get(opts, :theme_path, Persistence.default_theme_path())
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    
    # Get initial modification time
    last_modified = get_last_modified(theme_path)
    
    state = %__MODULE__{
      theme_path: theme_path,
      last_modified: last_modified,
      poll_interval: poll_interval,
      subscribers: []
    }
    
    # Start polling
    schedule_poll(poll_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:subscribe, _from, state) do
    {:reply, :ok, %{state | subscribers: [self() | state.subscribers]}}
  end
  
  @impl true
  def handle_call(:unsubscribe, _from, state) do
    {:reply, :ok, %{state | subscribers: List.delete(state.subscribers, self())}}
  end
  
  @impl true
  def handle_cast(:reload, state) do
    case load_and_notify(state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:poll, state) do
    # Schedule next poll
    schedule_poll(state.poll_interval)
    
    # Check for changes
    case check_for_changes(state) do
      {:changed, new_state} -> {:noreply, new_state}
      {:unchanged, state} -> {:noreply, state}
    end
  end
  
  # Private functions
  
  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end
  
  defp check_for_changes(state) do
    current_modified = get_last_modified(state.theme_path)
    
    if current_modified != state.last_modified do
      case load_and_notify(%{state | last_modified: current_modified}) do
        {:ok, new_state} -> {:changed, new_state}
        {:error, _reason} -> {:unchanged, state}
      end
    else
      {:unchanged, state}
    end
  end
  
  defp load_and_notify(state) do
    case Persistence.load_theme(state.theme_path) do
      {:ok, theme} ->
        # Notify all subscribers
        Enum.each(state.subscribers, fn pid ->
          send(pid, {:theme_changed, theme})
        end)
        
        {:ok, state}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp get_last_modified(path) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} -> mtime
      {:error, _} -> nil
    end
  end
end 