defmodule Raxol.System.DeltaUpdater do
  @moduledoc """
  Handles delta updates for the Raxol terminal emulator.
  """

  require Logger

  alias Raxol.System.Updater

  def check_delta_availability(target_version) do
    with {:ok, releases} <- get_releases(),
         {:ok, assets} <- extract_assets(releases),
         {:ok, full_asset} <- find_full_asset(assets, target_version),
         {:ok, delta_asset} <- find_delta_asset(assets, target_version) do
      # Compare sizes to determine if delta update is beneficial
      full_size = full_asset["size"]
      delta_size = delta_asset["size"]

      if delta_size < full_size * 0.5 do
        {:ok, delta_asset}
      else
        {:error, :delta_too_large}
      end
    else
      error -> error
    end
  end

  def apply_delta_update(delta_url, target_version) do
    # Create a temporary directory for the update
    tmp_dir = Path.join(System.tmp_dir!(), "raxol_update_#{:rand.uniform(1000000)}")
    File.mkdir_p!(tmp_dir)

    try do
      # 1. Get the current executable path
      current_exe = get_current_executable()

      # 2. Download the delta update
      delta_file = Path.join(tmp_dir, "update.delta")
      :ok = download_delta(delta_url, delta_file)

      # 3. Create a new executable by applying the delta
      new_exe = Path.join(tmp_dir, "raxol.new")
      :ok = apply_binary_delta(current_exe, delta_file, new_exe)

      # 4. Verify the patched executable
      :ok = verify_patched_executable(new_exe, target_version)

      # 5. Replace the current executable with the new one
      :ok = replace_executable(current_exe, new_exe)

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

  defp find_delta_asset(assets, target_version) do
    case Enum.find(assets, &(&1["name"] =~ ~r/delta-#{target_version}/)) do
      nil -> {:error, :delta_not_found}
      asset -> {:ok, asset}
    end
  end

  defp find_full_asset(assets, target_version) do
    case Enum.find(assets, &(&1["name"] =~ ~r/raxol-#{target_version}/)) do
      nil -> {:error, :full_package_not_found}
      asset -> {:ok, asset}
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

  defp replace_executable(current_exe, new_exe) do
    # Determine platform
    platform = case :os.type() do
      {:win32, _} -> "windows"
      _ -> "unix" # Or be more specific if needed
    end

    # Call the shared helper function
    Updater.do_replace_executable(current_exe, new_exe, platform)
  end

  defp get_releases do
    url = "https://api.github.com/repos/raxol/raxol/releases"

    case :httpc.request(:get, {String.to_charlist(url), [
      {~c"User-Agent", ~c"Raxol-Updater"}
    ]}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, {{_, status, _}, _, _}} ->
        {:error, "Failed to fetch releases: HTTP #{status}"}
      {:error, reason} ->
        {:error, "Failed to fetch releases: #{reason}"}
    end
  end
end
