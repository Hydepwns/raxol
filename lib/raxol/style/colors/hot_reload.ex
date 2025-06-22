defmodule Raxol.Style.Colors.HotReload do
  import Raxol.Guards

  @moduledoc """
  Provides hot-reloading capabilities for color themes.

  This module watches for changes to theme files and automatically
  reloads them when they change. It also provides a way to subscribe
  to theme change events.
  """

  use GenServer
  @behaviour GenServer

  alias Raxol.Style.Colors.Persistence

  # Check for changes every second
  @check_interval 1000

  defstruct [
    :watched_paths,
    :last_modified,
    :subscribers
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Subscribe to theme change events.

  ## Examples

      iex> HotReload.subscribe()
      :ok
  """
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  @doc """
  Unsubscribe from theme change events.

  ## Examples

      iex> HotReload.unsubscribe()
      :ok
  """
  def unsubscribe do
    GenServer.call(__MODULE__, :unsubscribe)
  end

  @doc """
  Add a path to watch for theme changes.

  ## Parameters

  - `path` - The path to watch

  ## Examples

      iex> HotReload.watch_path("/path/to/themes")
      :ok
  """
  def watch_path(path) do
    GenServer.call(__MODULE__, {:watch_path, path})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Get theme paths from config
    theme_paths = get_theme_paths()

    # Initialize state
    state = %__MODULE__{
      watched_paths: theme_paths,
      last_modified: %{},
      subscribers: []
    }

    # Start watching paths
    Enum.each(theme_paths, &init_path_watch(&1, state))

    {:ok, state}
  end

  @impl true
  def handle_call(:subscribe, _from, state) do
    {:reply, :ok, %{state | subscribers: [self() | state.subscribers]}}
  end

  @impl true
  def handle_call(:unsubscribe, _from, state) do
    {:reply, :ok,
     %{state | subscribers: List.delete(state.subscribers, self())}}
  end

  @impl true
  def handle_call({:watch_path, path}, _from, state) do
    new_state = init_path_watch(path, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:check_changes, state) do
    new_state = check_for_changes(state)
    schedule_check()
    {:noreply, new_state}
  end

  # Private Functions

  defp get_theme_paths do
    # Get paths from config or use defaults
    config_paths = Application.get_env(:raxol, :theme_paths, [])

    if Enum.empty?(config_paths) do
      # Use default paths
      [
        Path.expand("~/.config/raxol/themes"),
        Path.join(:code.priv_dir(:raxol), "themes")
      ]
    else
      config_paths
    end
  end

  defp init_path_watch(path, state) do
    # Create directory if it doesn't exist
    File.mkdir_p!(path)

    # Get initial modification times
    last_modified = get_path_modification_times(path)

    # Update state
    %{state | last_modified: Map.merge(state.last_modified, last_modified)}
  end

  defp get_path_modification_times(path) do
    case File.ls(path) do
      {:ok, files} -> process_theme_files(path, files)
      _ -> %{}
    end
  end

  defp process_theme_files(path, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(&get_file_mtime(path, &1))
    |> Enum.reject(&nil?/1)
    |> Map.new()
  end

  defp get_file_mtime(path, file) do
    full_path = Path.join(path, file)

    case File.stat(full_path) do
      {:ok, %{mtime: mtime}} -> {full_path, mtime}
      _ -> nil
    end
  end

  defp check_for_changes(state) do
    current_times = get_current_times(state.watched_paths)
    changed_files = find_changed_files(current_times, state.last_modified)

    Enum.each(changed_files, &handle_theme_change(&1, state.subscribers))

    %{state | last_modified: current_times}
  end

  defp get_current_times(paths) do
    Enum.reduce(paths, %{}, fn path, acc ->
      Map.merge(acc, get_path_modification_times(path))
    end)
  end

  defp find_changed_files(current_times, last_modified) do
    Enum.filter(current_times, fn {path, mtime} ->
      case Map.get(last_modified, path) do
        nil -> true
        old_time -> old_time != mtime
      end
    end)
  end

  defp handle_theme_change({path, _mtime}, subscribers) do
    theme_name = Path.basename(path, ".json") |> String.to_atom()

    case Persistence.load_theme(theme_name) do
      {:ok, theme} ->
        Raxol.set_theme(theme)
        notify_subscribers(subscribers, theme)

      _ ->
        :ok
    end
  end

  defp notify_subscribers(subscribers, theme) do
    Enum.each(subscribers, fn pid -> send(pid, {:theme_reloaded, theme}) end)
  end

  defp schedule_check do
    _timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:check_changes, _timer_id}, @check_interval)
  end
end
