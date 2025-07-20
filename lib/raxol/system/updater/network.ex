defmodule Raxol.System.Updater.Network do
  @moduledoc """
  Network operations for the Raxol System Updater including HTTP requests, GitHub API, file downloads, and archive operations.
  """

  @github_repo "username/raxol"

  def fetch_latest_version do
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

  def fetch_github_releases do
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

  def download_file(url, destination) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], [
           {:stream, String.to_charlist(destination)}
         ]) do
      {:ok, :saved_to_file} ->
        :ok

      {:error, reason} ->
        throw({:error, "Failed to download update: #{inspect(reason)}"})
    end
  end

  def extract_archive(archive_path, destination, "tar.gz") do
    case System.cmd("tar", ["xzf", archive_path, "-C", destination]) do
      {_, 0} -> :ok
      {error, _} -> throw({:error, "Failed to extract update: #{error}"})
    end
  end

  def extract_archive(archive_path, destination, "zip") do
    case System.cmd("unzip", [archive_path, "-d", destination]) do
      {_, 0} -> :ok
      {error, _} -> throw({:error, "Failed to extract update: #{error}"})
    end
  end

  def find_executable(dir, platform) do
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

  # --- Private Functions ---

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
end
