defmodule Raxol.System.Updater do
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
  @update_check_interval 86400
  @update_settings_file "~/.raxol/update_settings.json"

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
      # Update the last check timestamp
      settings = Map.put(settings, "last_check", :os.system_time(:second))
      _ = save_update_settings(settings)

      # case Version.compare(@version, latest_version) do # Version module seems unavailable
      # Basic comparison for now
      case @version == latest_version[:version] do
        true ->
          {:no_update, @version}

        false ->
          {:update_available, latest_version[:version]}
          #  :lt -> {:update_available, latest_version}
          #  _ -> {:no_update, @version}
      end
    else
      {:error, reason} -> {:error, reason}
      # Don't check yet based on interval
      false -> {:no_update, @version}
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
  def self_update(version \\ nil, opts \\ []) do
    use_delta = Keyword.get(opts, :use_delta, true)

    # Check if we're running as a compiled binary.
    # This functionality was previously attempted with Burrito, but the utility module was not available.
    # For now, we assume the application is not running as a standalone binary for self-update purposes.
    is_binary = false

    if !is_binary do
      {:error, "Not running as a compiled binary"}
    else
      # If no specific version is provided, fetch the latest
      version =
        if is_nil(version) do
          case fetch_latest_version() do
            {:ok, latest} -> latest
            {:error, reason} -> throw({:error, reason})
          end
        else
          version
        end

      # Check if we actually need to update
      # case Version.compare(@version, version) do # Version module seems unavailable
      # Basic comparison for now
      case @version == version do
        false ->
          #  :lt ->
          if use_delta do
            # Try delta update first, fall back to full update
            try_delta_update(version)
          else
            # Skip delta update attempt
            do_self_update(version)
          end

        true ->
          {:no_update, @version}
          #  _ -> {:no_update, @version}
      end
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
        IO.puts("Run 'raxol update' to install.")
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
  def set_auto_check(enabled) when is_boolean(enabled) do
    with {:ok, settings} <- get_update_settings() do
      settings = Map.put(settings, "auto_check", enabled)
      save_update_settings(settings)
    end
  end

  # Private functions

  defp get_update_settings do
    file_path = Path.expand(@update_settings_file)

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, settings} -> {:ok, settings}
            _error -> {:ok, default_settings()}
          end

        _error ->
          {:ok, default_settings()}
      end
    else
      # Ensure directory exists
      file_dir = Path.dirname(file_path)
      :ok = File.mkdir_p(file_dir)

      # Return default settings
      {:ok, default_settings()}
    end
  end

  defp default_settings do
    %{
      "auto_check" => true,
      "last_check" => 0,
      "channel" => "stable"
    }
  end

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

        with {:ok, release_data} <- Jason.decode(body_str),
             version = release_data["tag_name"],
             url = release_data["html_url"] do
          {:ok, %{version: version, url: url}}
        else
          _ -> {:error, :invalid_response}
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
          System.argv() |> List.first() ||
          throw({:error, "Cannot determine executable path"})

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

  defp find_file_recursive(dir, filename) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.find_value(files, fn file ->
          path = Path.join(dir, file)

          cond do
            Path.basename(path) == filename ->
              path

            File.dir?(path) ->
              find_file_recursive(path, filename)

            true ->
              nil
          end
        end)

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

  # Try to use delta update, fall back to full update if needed
  defp try_delta_update(version) do
    case DeltaUpdater.check_delta_availability(version) do
      {:ok, delta_info} ->
        # Delta update is available
        IO.puts(
          "Delta update available (#{delta_info.savings_percent}% smaller download)"
        )

        case DeltaUpdater.apply_delta_update(version, delta_info.delta_url) do
          :ok ->
            :ok

          {:error, reason} ->
            # If delta update fails, fall back to full update
            IO.puts("Delta update failed: #{reason}")
            IO.puts("Falling back to full update...")
            do_self_update(version)
        end

      {:error, _reason} ->
        # Delta update not available, use full update
        do_self_update(version)
    end
  end

  @doc """
  Checks for updates and applies them if available.

  ## Options
  - `:force` (boolean): Force update check, bypassing interval.
  - `:use_delta` (boolean): Use delta updates if available (default: true).
  - `:version` (string): Update to a specific version (default: latest).

  ## Returns
  - `:ok` if update was successful.
  - `{:no_update, version}` if already up to date.
  - `{:error, reason}` if an error occurred.
  """
  def update(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    force = Keyword.get(opts, :force, false)
    use_delta = Keyword.get(opts, :use_delta, true)
    version = Keyword.get(opts, :version)

    try do
      # 1. Determine target version
      target_version =
        case version do
          nil ->
            case check_for_updates(force: force) do
              {:update_available, v} -> v
              {:no_update, v} -> throw({:no_update, v})
              {:error, reason} -> throw({:error, reason})
            end

          v ->
            v
        end

      # 2. Apply update
      case self_update(target_version, use_delta: use_delta) do
        :ok -> :ok
        {:no_update, v} -> {:no_update, v}
        {:error, reason} -> {:error, reason}
      end
    catch
      {:no_update, v} -> {:no_update, v}
      {:error, reason} -> {:error, reason}
    end
  end
end
