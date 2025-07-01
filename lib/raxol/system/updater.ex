defmodule Raxol.System.Updater do
  use GenServer
  import Raxol.Guards
  require Logger

  @moduledoc """
  Provides version management and self-update functionality for Raxol.

  This module handles:
  - Checking for updates from GitHub releases
  - Comparing versions to determine if updates are available
  - Self-updating the application when running as a compiled binary
  - Managing update settings and configurations
  """

  alias Raxol.System.DeltaUpdater
  # alias Raxol.Plugins.PluginManager # Unused
  alias Raxol.UI.Terminal
  alias Raxol.Style.Colors.Color
  # alias Raxol.System.Version # Seems unavailable
  # alias Raxol.System.Downloader # Unused
  # alias Raxol.Utils.HTTPClient # Unused

  @github_repo "username/raxol"
  @version Mix.Project.config()[:version]
  # 24 hours in seconds
  @update_check_interval 86_400
  @update_settings_file "~/.raxol/update_settings.json"

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_update_settings do
    case Application.get_env(:raxol, :update_settings) do
      nil -> default_update_settings()
      settings -> settings
    end
  end

  def set_update_settings(settings) do
    Application.put_env(:raxol, :update_settings, settings)
  end

  def check_for_updates do
    settings = get_update_settings()

    if settings.auto_update do
      with {:ok, %{version: latest_version}} <- fetch_latest_version(),
           current_version = get_current_version(),
           true <- latest_version != current_version do
        {:ok, latest_version}
      else
        {:error, reason} -> {:error, reason}
        false -> {:no_update, get_current_version()}
      end
    else
      {:error, :auto_update_disabled}
    end
  end

  def download_update(version) do
    settings = get_update_settings()
    platform = get_platform()
    ext = if platform == "windows", do: "zip", else: "tar.gz"

    url =
      "https://github.com/#{@github_repo}/releases/download/v#{version}/raxol-#{version}-#{platform}.#{ext}"

    case download_file(url, Path.join(settings.download_path, "update.#{ext}")) do
      :ok -> {:ok, version}
      {:error, reason} -> {:error, reason}
    end
  end

  def install_update(context, version) do
    settings = get_update_settings()
    platform = get_platform()
    ext = if platform == "windows", do: "zip", else: "tar.gz"
    update_path = Path.join(settings.download_path, "update.#{ext}")

    with :ok <- extract_archive(update_path, settings.download_path, ext),
         {:ok, new_exe} <- find_executable(settings.download_path, platform),
         :ok <- apply_update(context.current_exe, new_exe, platform) do
      {:ok, version}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_no_update(_context, {:no_update, _current_version}) do
    :ok
  end

  def rollback_update do
    settings = get_update_settings()
    backup_path = Path.join(settings.backup_path, "previous_version")

    if File.exists?(backup_path) do
      _platform = get_platform()

      current_exe =
        System.get_env("BURRITO_EXECUTABLE_PATH") ||
          System.argv() |> List.first()

      case File.cp(backup_path, current_exe) do
        :ok -> {:ok, get_current_version()}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :no_backup_found}
    end
  end

  def get_current_version do
    Application.spec(:raxol)[:vsn]
  end

  def get_available_versions do
    case fetch_github_releases() do
      {:ok, releases} -> {:ok, releases}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_update_history do
    settings = get_update_settings()
    history_file = Path.join(settings.download_path, "update_history.json")

    case File.read(history_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, history} -> {:ok, history}
          _ -> {:ok, []}
        end

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def clear_update_history do
    settings = get_update_settings()
    history_file = Path.join(settings.download_path, "update_history.json")

    case File.write(history_file, Jason.encode!([])) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def get_update_progress do
    case Process.get(:update_progress) do
      nil -> 0
      progress -> progress
    end
  end

  def cancel_update do
    case Process.get(:update_pid) do
      nil ->
        {:error, :no_update_in_progress}

      pid ->
        Process.put(:update_progress, 0)
        Process.exit(pid, :normal)
        :ok
    end
  end

  def get_update_error do
    Process.get(:update_error)
  end

  def clear_update_error do
    Process.delete(:update_error)
    :ok
  end

  def get_update_log do
    settings = get_update_settings()
    log_file = Path.join(settings.download_path, "update.log")

    case File.read(log_file) do
      {:ok, content} -> {:ok, String.split(content, "\n", trim: true)}
      {:error, :enoent} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def clear_update_log do
    settings = get_update_settings()
    log_file = Path.join(settings.download_path, "update.log")

    case File.write(log_file, "") do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def get_update_stats do
    settings = get_update_settings()
    stats_file = Path.join(settings.download_path, "update_stats.json")

    case File.read(stats_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, stats} -> {:ok, stats}
          _ -> {:ok, default_stats()}
        end

      {:error, :enoent} ->
        {:ok, default_stats()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def clear_update_stats do
    settings = get_update_settings()
    stats_file = Path.join(settings.download_path, "update_stats.json")

    case File.write(stats_file, Jason.encode!(default_stats())) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def update(opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
    force = Keyword.get(opts, :force, false)
    use_delta = Keyword.get(opts, :use_delta, true)
    version = Keyword.get(opts, :version)

    try do
      with {:ok, target_version} <- get_target_version(version, force) do
        apply_target_update(target_version, use_delta)
      end
    catch
      {:no_update, v} -> {:no_update, v}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_call({:install_update, version}, _from, state) do
    case perform_install_update(version, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(_opts) do
    state = %{
      settings: default_settings(),
      status: :idle,
      current_version: current_version(),
      available_updates: [],
      last_check: nil,
      error: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:install_update, version}, _from, state) do
    case perform_install_update(version, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_update_settings, _from, state) do
    {:reply, state.settings, state}
  end

  @impl GenServer
  def handle_call({:set_update_settings, settings}, _from, state) do
    state = %{state | settings: settings}
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:check_for_updates, _from, state) do
    case check_updates(state) do
      {:ok, updates} ->
        state = %{
          state
          | status: :updates_available,
            available_updates: updates,
            last_check: DateTime.utc_now(),
            error: nil
        }

        {:reply, {:ok, updates}, state}

      {:error, reason} ->
        state = %{state | status: :error, error: reason}
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_update_status, _from, state) do
    status = %{
      current_version: state.current_version,
      available_updates: state.available_updates,
      last_check: state.last_check,
      error: state.error
    }

    {:reply, status, state}
  end

  # --- Private Functions ---

  @doc """
  Returns the default update settings.
  """
  @spec default_update_settings() :: map()
  def default_update_settings do
    %{
      auto_update: true,
      # 24 hours in seconds
      check_interval: 24 * 60 * 60,
      update_channel: :stable,
      notify_on_update: true,
      download_path: System.get_env("HOME") <> "/.raxol/downloads",
      backup_path: System.get_env("HOME") <> "/.raxol/backups",
      max_backups: 5,
      retry_count: 3,
      # seconds
      retry_delay: 5,
      # seconds
      timeout: 300,
      verify_checksums: true,
      require_confirmation: true
    }
  end

  defp current_version do
    Application.spec(:raxol)[:vsn]
  end

  defp check_updates(state) do
    case fetch_latest_version() do
      {:ok, %{version: latest_version}} ->
        if latest_version != state.current_version do
          {:ok,
           [
             %{
               version: latest_version,
               url:
                 "https://github.com/#{@github_repo}/releases/tag/v#{latest_version}"
             }
           ]}
        else
          {:ok, []}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_install_update(version, state) do
    case self_update(version, use_delta: true) do
      :ok ->
        _new_state = %{
          state
          | status: :installed,
            current_version: version,
            error: nil
        }

        {:ok, state}

      {:error, reason} ->
        _new_state = %{state | status: :error, error: reason}
        {:error, reason}

      {:no_update, _current_version} ->
        {:ok, state}
    end
  end

  @doc """
  Checks if a newer version of Raxol is available.

  Returns a tuple with the check result and the latest version if available:
  - `{:no_update, current_version}` - No update available
  - `{:update_available, latest_version}` - Update available
  - `{:error, reason}` - Error occurred during check

  ## Parameters

  - `force`: When set to `true`, bypasses the update check interval. Defaults to `false`.

  ## Examples

      iex> Raxol.System.Updater.check_for_updates()
      {:no_update, "0.1.0"}

      iex> Raxol.System.Updater.check_for_updates(force: true)
      {:update_available, "0.2.0"}
  """
  def check_for_updates(opts \\ []) do
    force = Keyword.get(opts, :force, false)

    with {:ok, settings} <- get_update_settings(),
         true <- force || should_check_for_update?(settings),
         {:ok, latest_version} <- fetch_latest_version() do
      _ = update_last_check(settings)
      {:ok, latest_version} |> compare_versions()
    else
      {:error, reason} -> {:error, reason}
      false -> {:no_update, @version}
    end
  end

  defp compare_versions({:ok, latest_version}) do
    case @version == latest_version[:version] do
      true -> {:no_update, @version}
      false -> {:update_available, latest_version[:version]}
    end
  end

  @doc """
  Performs a self-update of the application if running as a compiled binary.

  Returns:
  - `:ok` - Update successfully completed
  - `{:error, reason}` - Error occurred during update
  - `{:no_update, current_version}` - No update needed

  ## Parameters

  - `version`: The version to update to. If not provided, updates to the latest version.
  - `opts`: Options for the update process:
    - `:use_delta`: Whether to try using delta updates (default: true)

  ## Examples

      iex> Raxol.System.Updater.self_update()
      :ok

      iex> Raxol.System.Updater.self_update("0.2.0")
      {:error, "Not running as a compiled binary"}
  """
  defp do_version_update(version, use_delta) do
    if use_delta do
      try_delta_update(version)
    else
      do_self_update(version)
    end
  end

  defp get_update_version(version) do
    if nil?(version) do
      case fetch_latest_version() do
        {:ok, latest} -> {:ok, latest}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, version}
    end
  end

  def self_update(version \\ nil, opts \\ []) do
    use_delta = Keyword.get(opts, :use_delta, true)

    if binary?(version) do
      with {:ok, target_version} <- get_update_version(version) do
        case @version == target_version do
          false -> do_version_update(target_version, use_delta)
          true -> {:no_update, @version}
        end
      end
    else
      {:error, "Not running as a compiled binary"}
    end
  catch
    {:error, reason} -> {:error, reason}
  end

  @doc """
  Displays update information to the user, if an update is available.

  This function checks for updates (respecting the check interval) and
  outputs a message to the user if an update is available.

  ## Examples

      iex> Raxol.System.Updater.notify_if_update_available()
      :ok
  """
  def notify_if_update_available do
    case check_for_updates() do
      {:update_available, version} ->
        # Use bright green on black for the update notification
        fg = {0, 255, 0}
        bg = {0, 0, 0}

        fg_hex =
          Color.from_rgb(elem(fg, 0), elem(fg, 1), elem(fg, 2))
          |> Color.to_hex()

        bg_hex =
          Color.from_rgb(elem(bg, 0), elem(bg, 1), elem(bg, 2))
          |> Color.to_hex()

        Terminal.println("Update Available!", color: fg_hex, background: bg_hex)

        IO.puts("Version #{version} is available.")
        IO.puts("Run \"raxol update\" to install.")
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Enables or disables automatic update checks.

  ## Parameters

  - `enabled`: Whether to enable or disable automatic update checks

  ## Examples

      iex> Raxol.System.Updater.set_auto_check(true)
      :ok

      iex> Raxol.System.Updater.set_auto_check(false)
      :ok
  """
  def set_auto_check(enabled) when boolean?(enabled) do
    with {:ok, settings} <- get_update_settings() do
      settings = Map.put(settings, "auto_check", enabled)
      save_update_settings(settings)
    end
  end

  # Private functions

  defp save_update_settings(settings) do
    file_path = Path.expand(@update_settings_file)

    case Jason.encode(settings) do
      {:ok, json} ->
        File.write(file_path, json)

      error ->
        error
    end
  end

  defp should_check_for_update?(settings) do
    auto_check = Map.get(settings, "auto_check", true)
    last_check = Map.get(settings, "last_check", 0)

    current_time = :os.system_time(:second)
    time_since_last_check = current_time - last_check

    auto_check && time_since_last_check >= @update_check_interval
  end

  defp fetch_latest_version do
    url = "https://api.github.com/repos/#{@github_repo}/releases/latest"

    case :httpc.request(
           :get,
           {String.to_charlist(url),
            [
              {~c"User-Agent", ~c"Raxol-Updater"}
            ]},
           [],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        body_str = List.to_string(body)

        case Jason.decode(body_str) do
          {:ok, release_data} ->
            version = release_data["tag_name"]
            url = release_data["html_url"]
            {:ok, %{version: version, url: url}}

          _ ->
            {:error, :invalid_response}
        end

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "GitHub API returned status #{status}"}

      {:error, reason} ->
        {:error, "Failed to connect to GitHub: #{inspect(reason)}"}
    end
  end

  defp do_self_update(version) do
    # Platform detection
    platform =
      case :os.type() do
        {:unix, :darwin} ->
          "macos"

        {:unix, _} ->
          "linux"

        {:win32, _} ->
          "windows"

          # _ -> throw({:error, "Unsupported platform"}) # Unreachable clause removed
      end

    # Determine file extension based on platform
    ext = if platform == "windows", do: "zip", else: "tar.gz"

    # Download URL for the new version
    url =
      "https://github.com/#{@github_repo}/releases/download/v#{version}/raxol-#{version}-#{platform}.#{ext}"

    # Temporary directory for the update
    tmp_dir = System.tmp_dir!() |> Path.join("raxol_update_#{version}")
    _ = File.rm_rf(tmp_dir)
    :ok = File.mkdir_p(tmp_dir)

    try do
      # Download the update
      archive_path = Path.join(tmp_dir, "update.#{ext}")
      :ok = download_file(url, archive_path)

      # Extract the update
      :ok = extract_archive(archive_path, tmp_dir, ext)

      # Get the current executable path
      current_exe =
        System.get_env("BURRITO_EXECUTABLE_PATH") ||
          System.argv() |> List.first()

      # Find the new executable in the extracted files
      new_exe = find_executable(tmp_dir, platform)

      # Apply the update by replacing the current executable
      apply_update(current_exe, new_exe, platform)

      :ok
    catch
      {:error, reason} -> {:error, reason}
    after
      # Clean up temporary files
      _ = File.rm_rf(tmp_dir)
    end
  end

  defp download_file(url, destination) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], [
           {:stream, String.to_charlist(destination)}
         ]) do
      {:ok, :saved_to_file} ->
        :ok

      {:error, reason} ->
        throw({:error, "Failed to download update: #{inspect(reason)}"})
    end
  end

  defp extract_archive(archive_path, destination, "tar.gz") do
    case System.cmd("tar", ["xzf", archive_path, "-C", destination]) do
      {_, 0} -> :ok
      {error, _} -> throw({:error, "Failed to extract update: #{error}"})
    end
  end

  defp extract_archive(archive_path, destination, "zip") do
    case System.cmd("unzip", [archive_path, "-d", destination]) do
      {_, 0} -> :ok
      {error, _} -> throw({:error, "Failed to extract update: #{error}"})
    end
  end

  defp find_executable(dir, platform) do
    executable_name = if platform == "windows", do: "raxol.exe", else: "raxol"
    executable_path = Path.join(dir, executable_name)

    if File.exists?(executable_path) do
      executable_path
    else
      # Search recursively in subdirectories
      case find_file_recursive(dir, executable_name) do
        nil ->
          throw({:error, "Could not find new executable in update package"})

        path ->
          path
      end
    end
  end

  defp check_file(path, filename) do
    cond do
      Path.basename(path) == filename -> path
      File.dir?(path) -> find_file_recursive(path, filename)
      true -> nil
    end
  end

  defp find_file_recursive(dir, filename) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.find_value(files, &check_file(Path.join(dir, &1), filename))

      _ ->
        nil
    end
  end

  def do_replace_executable(current_exe, new_exe, platform) do
    # Make the new executable executable
    File.chmod!(new_exe, 0o755)

    if platform == "windows" do
      # On Windows, we need to use a different approach since we can't replace a running executable
      # Create a batch file that will replace the exe after we exit
      updater_bat = System.tmp_dir!() |> Path.join("raxol_updater.bat")

      # Ensure paths are properly escaped for the batch file
      safe_new_exe = Path.expand(new_exe)
      safe_current_exe = Path.expand(current_exe)

      batch_contents = """
      @echo off
      timeout /t 2 /nobreak > nul
      copy /y "#{safe_new_exe}" "#{safe_current_exe}"
      del "#{updater_bat}"
      """

      File.write!(updater_bat, batch_contents)

      # Execute the batch file and exit
      # Using start /b runs the command in the background without a new window
      _ = System.cmd("cmd", ["/c", "start", "/b", updater_bat])
      # Give the batch file a moment to start before exiting
      Process.sleep(500)
      # Exit the current Elixir application
      System.stop(0)
    else
      # On Unix systems, we can replace the current executable directly
      # The new process will start with the updated executable
      case File.cp(new_exe, current_exe) do
        :ok ->
          IO.puts(
            "Executable replaced successfully. Please restart the application."
          )

          # On Unix, we might not need to System.stop immediately,
          # depending on how the restart is managed.
          # For now, let's assume the caller handles the restart or exit logic
          # after this function returns :ok.
          :ok

        {:error, reason} ->
          throw({:error, "Failed to replace executable: #{inspect(reason)}"})
      end
    end
  end

  defp apply_update(current_exe, new_exe, platform) do
    do_replace_executable(current_exe, new_exe, platform)
    # Consider if any further action is needed here after calling the helper,
    # especially for the non-Windows case where we didn't System.stop() inside.
    # If the application should exit after update on Unix, add System.stop(0) here.
    # For now, returning :ok based on the helper's success.
    :ok
  end

  defp do_delta_update(version, delta_info) do
    IO.puts(
      "Delta update available (#{delta_info.savings_percent}% smaller download)"
    )

    case DeltaUpdater.apply_delta_update(version, delta_info.delta_url) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.puts("Delta update failed: #{reason}")
        IO.puts("Falling back to full update...")
        do_self_update(version)
    end
  end

  defp try_delta_update(version) do
    case DeltaUpdater.check_delta_availability(version) do
      {:ok, delta_info} -> do_delta_update(version, delta_info)
      {:error, _reason} -> do_self_update(version)
    end
  end

  defp get_target_version(version, force) do
    case version do
      nil ->
        case check_for_updates(force: force) do
          {:update_available, v} -> {:ok, v}
          {:no_update, v} -> {:no_update, v}
          {:error, reason} -> {:error, reason}
        end

      v ->
        {:ok, v}
    end
  end

  defp apply_target_update(version, use_delta) do
    case self_update(version, use_delta: use_delta) do
      :ok -> :ok
      {:no_update, v} -> {:no_update, v}
      {:error, reason} -> {:error, reason}
    end
  end

  defp default_settings do
    default_update_settings()
  end

  defp update_last_check(settings) do
    Map.put(settings, :last_check, DateTime.utc_now())
  end

  defp get_platform do
    case :os.type() do
      {:unix, :darwin} -> "macos"
      {:unix, _} -> "linux"
      {:win32, _} -> "windows"
    end
  end

  defp fetch_github_releases do
    url = "https://api.github.com/repos/#{@github_repo}/releases"

    case :httpc.request(
           :get,
           {String.to_charlist(url), [{~c"User-Agent", ~c"Raxol-Updater"}]},
           [],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(body) do
          {:ok, releases} -> {:ok, releases}
          _ -> {:error, :invalid_response}
        end

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "GitHub API returned status #{status}"}

      {:error, reason} ->
        {:error, "Failed to connect to GitHub: #{inspect(reason)}"}
    end
  end

  defp set_update_progress(progress) do
    Process.put(:update_progress, progress)
  end

  defp set_update_error(error) do
    Process.put(:update_error, error)
  end

  defp default_stats do
    %{
      total_updates: 0,
      successful_updates: 0,
      failed_updates: 0,
      last_update: nil,
      average_update_time: 0
    }
  end

  defp log_update(message) do
    settings = get_update_settings()
    log_file = Path.join(settings.download_path, "update.log")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    log_entry = "[#{timestamp}] #{message}\n"

    File.write(log_file, log_entry, [:append])
  end

  defp update_stats(stats) do
    settings = get_update_settings()
    stats_file = Path.join(settings.download_path, "update_stats.json")
    File.write(stats_file, Jason.encode!(stats))
  end
end
