defmodule Raxol.Style.Colors.HotReload do
  @moduledoc """
  Provides hot-reloading capabilities for color themes.

  This module watches for changes to theme files and automatically
  reloads them when they change. It also provides a way to subscribe
  to theme change events.
  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Style.Colors.Persistence
  alias Raxol.Core.Runtime.Log

  # Check for changes every 100ms (faster for tests)
  @check_interval 100

  defstruct [
    :watched_paths,
    :last_modified,
    :subscribers
  ]

  # Client API

  #  def start_link(opts \\ []) do
  #    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  #  end

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
  def init_manager(_opts) do
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

    # Schedule the initial check
    schedule_check()

    {:ok, state}
  end

  @impl true
  def handle_manager_call(:subscribe, {from_pid, _ref}, state) do
    {:reply, :ok, %{state | subscribers: [from_pid | state.subscribers]}}
  end

  @impl true
  def handle_manager_call(:unsubscribe, {from_pid, _ref}, state) do
    {:reply, :ok,
     %{state | subscribers: List.delete(state.subscribers, from_pid)}}
  end

  @impl true
  def handle_manager_call({:watch_path, path}, _from, state) do
    new_state = init_path_watch(path, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_info({:check_changes, _timer_id}, state) do
    new_state = check_for_changes(state)
    schedule_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:theme_reloaded, _theme}, state) do
    # Ignore theme_reloaded messages sent to self
    {:noreply, state}
  end

  # Private Functions

  defp get_theme_paths do
    # Get paths from config or use defaults
    config_paths = Application.get_env(:raxol, :theme_paths, [])
    get_paths_or_defaults(Enum.empty?(config_paths), config_paths)
  end

  defp get_paths_or_defaults(true, _config_paths) do
    # Use default paths
    [
      Path.expand("~/.config/raxol/themes"),
      Path.join(:code.priv_dir(:raxol), "themes")
    ]
  end

  defp get_paths_or_defaults(false, config_paths), do: config_paths

  defp init_path_watch(path, state) do
    # Create directory if it doesn't exist
    File.mkdir_p!(path)

    # Get initial modification times
    last_modified = get_path_modification_times(path)

    # Add path to watched_paths if not already present
    watched_paths =
      update_watched_paths(
        path in state.watched_paths,
        path,
        state.watched_paths
      )

    %{
      state
      | watched_paths: watched_paths,
        last_modified: Map.merge(state.last_modified, last_modified)
    }
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
    |> Enum.reject(&is_nil/1)
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
    Log.info(
      "[HotReload DEBUG] check_for_changes called. Watched paths: #{inspect(state.watched_paths)}"
    )

    current_times = get_current_times(state.watched_paths)
    changed_files = find_changed_files(current_times, state.last_modified)
    # Log.info("[HotReload DEBUG] changed_files: #{inspect(changed_files)}")

    Enum.each(changed_files, &handle_theme_change(&1, state.subscribers))

    %{state | last_modified: current_times}
  end

  defp get_current_times(paths) do
    Enum.reduce(paths, %{}, fn path, acc ->
      Map.merge(acc, get_path_modification_times(path))
    end)
  end

  defp find_changed_files(current_times, last_modified) do
    # Log.info(
    #   "[HotReload DEBUG] Comparing times - current: #{inspect(current_times)}"
    # )
    # 
    # Log.info(
    #   "[HotReload DEBUG] Comparing times - last: #{inspect(last_modified)}"
    # )

    changed =
      Enum.filter(current_times, fn {path, mtime} ->
        case Map.get(last_modified, path) do
          nil ->
            # Log.info("[HotReload DEBUG] New file detected: #{path}")
            true

          old_time ->
            changed = old_time != mtime

            # Log.info(
            #   "[HotReload DEBUG] File #{path}: old=#{inspect(old_time)}, new=#{inspect(mtime)}, changed=#{changed}"
            # )

            changed
        end
      end)

    # Log.info("[HotReload DEBUG] Found changed files: #{inspect(changed)}")
    changed
  end

  defp handle_theme_change({path, _mtime}, subscribers) do
    # Log.info(
    #   "[HotReload DEBUG] handle_theme_change: path=#{inspect(path)} subscribers=#{inspect(subscribers)}"
    # )

    theme_name = Path.basename(path, ".json") |> String.to_atom()

    case Persistence.load_theme(theme_name) do
      {:ok, theme} ->
        # Log.info(
        #   "[HotReload DEBUG] Loaded theme: #{inspect(theme.name)}. Notifying subscribers..."
        # )

        Enum.each(subscribers, fn pid ->
          # Don't send message to self
          send_theme_to_pid(pid != self(), pid, theme)
        end)

      {:error, _reason} ->
        # Try loading by full path if loading by name fails
        case File.read(path) do
          {:ok, theme_json} ->
            case Jason.decode(theme_json) do
              {:ok, theme_map} ->
                theme_struct = Persistence.map_to_theme_struct(theme_map)

                # Log.info(
                #   "[HotReload DEBUG] Loaded theme by path: #{inspect(theme_struct.name)}. Notifying subscribers..."
                # )

                Enum.each(subscribers, fn pid ->
                  # Don't send message to self
                  send_theme_to_pid(pid != self(), pid, theme_struct)
                end)

              _ ->
                # Log.info(
                #   "[HotReload DEBUG] Failed to decode theme JSON at #{path}"
                # )
                :ok
            end

          _ ->
            # Log.info("[HotReload DEBUG] Failed to load theme: #{theme_name}")
            Log.module_debug("Failed to load theme: #{theme_name}")
        end
    end
  end

  defp schedule_check do
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:check_changes, timer_id}, @check_interval)
  end

  defp update_watched_paths(true, _path, watched_paths), do: watched_paths

  defp update_watched_paths(false, path, watched_paths),
    do: [path | watched_paths]

  defp send_theme_to_pid(true, pid, theme),
    do: send(pid, {:theme_reloaded, theme})

  defp send_theme_to_pid(false, _pid, _theme), do: :ok
end
