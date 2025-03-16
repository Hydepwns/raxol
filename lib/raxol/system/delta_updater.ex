defmodule Raxol.System.DeltaUpdater do
  @moduledoc """
  Provides delta update functionality for Raxol's self-update system.
  
  Delta updates only download and apply the differences between versions
  rather than full packages, providing:
  - Faster updates with smaller downloads
  - Reduced bandwidth usage
  - More efficient update process
  
  This module works with the main Updater module to provide an optimized
  update experience.
  """
  
  alias Raxol.Style.Colors.Color
  
  @github_repo "username/raxol"
  @version Mix.Project.config[:version]
  @delta_temp_dir "delta_updates"
  
  @doc """
  Check if delta updates are available between the current version and the target version.
  
  Returns:
  - `{:ok, delta_info}` - Delta update is available with info about size savings
  - `{:error, reason}` - Delta update not available or error
  
  ## Examples
  
      iex> Raxol.System.DeltaUpdater.check_delta_availability("1.2.0")
      {:ok, %{full_size: 15000000, delta_size: 2500000, savings_percent: 83}}
  """
  def check_delta_availability(target_version) do
    url = "https://api.github.com/repos/#{@github_repo}/releases/tags/v#{target_version}"
    
    case :httpc.request(:get, {String.to_charlist(url), [{'User-Agent', 'Raxol-Updater'}]}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body_str = List.to_string(body)
        
        with {:ok, release_data} <- Jason.decode(body_str),
             {:ok, assets} <- extract_assets(release_data),
             {:ok, delta_asset} <- find_delta_asset(assets, @version, target_version) do
          
          # Get full package size for comparison
          {:ok, full_asset} <- find_full_asset(assets, target_version)
          
          delta_size = delta_asset["size"]
          full_size = full_asset["size"]
          savings_percent = round((full_size - delta_size) / full_size * 100)
          
          {:ok, %{
            delta_url: delta_asset["browser_download_url"],
            full_size: full_size,
            delta_size: delta_size,
            savings_percent: savings_percent
          }}
        else
          {:error, reason} -> {:error, reason}
        end
        
      {:ok, {{_, status, _}, _, _}} ->
        {:error, "GitHub API returned status #{status}"}
      {:error, reason} ->
        {:error, "Failed to connect to GitHub: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Apply a delta update to upgrade from the current version to the target version.
  
  Returns:
  - `:ok` - Delta update successfully applied
  - `{:error, reason}` - Failed to apply delta update
  
  ## Examples
  
      iex> Raxol.System.DeltaUpdater.apply_delta_update("1.2.0", delta_url)
      :ok
  """
  def apply_delta_update(target_version, delta_url) do
    # Platform detection
    platform = case :os.type() do
      {:unix, :darwin} -> "macos"
      {:unix, _} -> "linux"
      {:win32, _} -> "windows"
      _ -> {:error, "Unsupported platform"}
    end
    
    # Create temporary directory
    tmp_dir = Path.join(System.tmp_dir!(), "#{@delta_temp_dir}_#{target_version}")
    _ = File.rm_rf(tmp_dir)
    :ok = File.mkdir_p(tmp_dir)
    
    try do
      # 1. Download the delta package
      delta_file = Path.join(tmp_dir, "delta.bin")
      :ok = download_delta(delta_url, delta_file)
      
      # 2. Get current executable
      current_exe = get_current_executable()
      
      # 3. Apply the binary delta to create the new executable
      new_exe = Path.join(tmp_dir, "raxol_new")
      :ok = apply_binary_delta(current_exe, delta_file, new_exe)
      
      # 4. Verify the patched executable
      :ok = verify_patched_executable(new_exe, target_version)
      
      # 5. Replace the current executable with the new one
      :ok = replace_executable(current_exe, new_exe, platform)
      
      :ok
    catch
      {:error, reason} -> {:error, reason}
    after
      # Clean up temporary files
      _ = File.rm_rf(tmp_dir)
    end
  end
  
  # Private functions
  
  defp extract_assets(%{"assets" => assets}) when is_list(assets), do: {:ok, assets}
  defp extract_assets(_), do: {:error, "No assets found in release data"}
  
  defp find_delta_asset(assets, from_version, to_version) do
    # Look for delta package with pattern like "raxol-delta-1.1.0-1.2.0-linux.bin"
    platform = get_platform_name()
    delta_pattern = "raxol-delta-#{from_version}-#{to_version}-#{platform}"
    
    case Enum.find(assets, fn asset -> 
      String.contains?(asset["name"], delta_pattern)
    end) do
      nil -> {:error, "No delta update package found"}
      asset -> {:ok, asset}
    end
  end
  
  defp find_full_asset(assets, version) do
    # Look for full package with pattern like "raxol-1.2.0-linux.tar.gz"
    platform = get_platform_name()
    ext = if platform == "windows", do: "zip", else: "tar.gz"
    full_pattern = "raxol-#{version}-#{platform}.#{ext}"
    
    case Enum.find(assets, fn asset -> 
      asset["name"] == full_pattern 
    end) do
      nil -> {:error, "No full update package found"}
      asset -> {:ok, asset}
    end
  end
  
  defp get_platform_name do
    case :os.type() do
      {:unix, :darwin} -> "macos"
      {:unix, _} -> "linux"
      {:win32, _} -> "windows"
      _ -> "unknown"
    end
  end
  
  defp download_delta(url, destination) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], [{:stream, String.to_charlist(destination)}]) do
      {:ok, :saved_to_file} -> :ok
      {:error, reason} -> throw({:error, "Failed to download delta update: #{inspect(reason)}"})
    end
  end
  
  defp get_current_executable do
    exe = System.get_env("BURRITO_EXECUTABLE_PATH") || System.argv() |> List.first()
    
    if is_nil(exe) do
      throw({:error, "Cannot determine executable path"})
    else
      exe
    end
  end
  
  defp apply_binary_delta(original_file, delta_file, output_file) do
    # We use bsdiff/bspatch for binary deltas
    # This assumes bspatch is available on the system
    case System.cmd("bspatch", [original_file, output_file, delta_file]) do
      {_, 0} -> :ok
      {error, _} -> throw({:error, "Failed to apply delta update: #{error}"})
    end
  end
  
  defp verify_patched_executable(exe_path, expected_version) do
    # Make the patched file executable
    File.chmod!(exe_path, 0o755)
    
    # Run the new executable with --version to verify it reports the correct version
    case System.cmd(exe_path, ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, expected_version) do
          :ok
        else
          throw({:error, "Version verification failed for patched executable"})
        end
      {error, _} -> 
        throw({:error, "Failed to verify patched executable: #{error}"})
    end
  end
  
  defp replace_executable(current_exe, new_exe, platform) do
    # Same replacement logic as in the main updater
    # Make the new executable executable
    File.chmod!(new_exe, 0o755)
    
    if platform == "windows" do
      # On Windows, we need to use a different approach since we can't replace a running executable
      # Create a batch file that will replace the exe after we exit
      updater_bat = System.tmp_dir!() |> Path.join("raxol_updater.bat")
      
      batch_contents = """
      @echo off
      timeout /t 2 /nobreak > nul
      copy /y "#{new_exe}" "#{current_exe}"
      del "#{updater_bat}"
      """
      
      File.write!(updater_bat, batch_contents)
      
      # Execute the batch file and exit
      System.cmd("cmd", ["/c", "start", "/b", updater_bat])
      System.stop(0)
    else
      # On Unix systems, we can replace the current executable directly
      # The new process will start with the updated executable
      case File.cp(new_exe, current_exe) do
        :ok -> :ok
        {:error, reason} -> throw({:error, "Failed to replace executable: #{inspect(reason)}"})
      end
    end
    
    :ok
  end
end 