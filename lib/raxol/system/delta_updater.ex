defmodule Raxol.System.DeltaUpdater do
  @moduledoc """
  Handles delta updates for the Raxol terminal emulator.
  """

  require Raxol.Core.Runtime.Log
  # Called via adapter now
  alias Raxol.System.DeltaUpdaterSystemAdapterImpl
  import Raxol.Guards

  @system_adapter Application.compile_env(
                    :raxol,
                    :system_adapter,
                    DeltaUpdaterSystemAdapterImpl
                  )

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
    random_suffix = :rand.uniform(1_000_000)

    with {:ok, base_tmp_dir} <- @system_adapter.system_tmp_dir(),
         tmp_dir_path =
           Path.join(base_tmp_dir, "raxol_update_#{random_suffix}"),
         :ok <- @system_adapter.file_mkdir_p(tmp_dir_path) do
      try do
        perform_update(tmp_dir_path, delta_url, target_version)
      after
        @system_adapter.file_rm_rf(tmp_dir_path)
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_update(tmp_dir_path, delta_url, target_version) do
    with {:ok, current_exe} <- get_current_executable(),
         delta_file = Path.join(tmp_dir_path, "update.delta"),
         :ok <- download_delta(delta_url, delta_file),
         new_exe = Path.join(tmp_dir_path, "raxol.new"),
         :ok <- apply_binary_delta(current_exe, delta_file, new_exe),
         :ok <- verify_patched_executable(new_exe, target_version),
         :ok <- replace_executable(current_exe, new_exe) do
      {:ok, :update_applied}
    end
  end

  # Private functions

  defp extract_assets(%{"assets" => assets}) when list?(assets),
    do: {:ok, assets}

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
    case @system_adapter.httpc_request(
           :get,
           {String.to_charlist(url), []},
           [],
           [{:stream, String.to_charlist(destination)}]
         ) do
      {:ok, :saved_to_file} ->
        :ok

      {:error, reason} ->
        # Return error tuple instead of throwing
        {:error, {:download_failed, reason}}
    end
  end

  defp get_current_executable do
    # Use adapter for system calls
    exe_path_env = @system_adapter.system_get_env("BURRITO_EXECUTABLE_PATH")
    argv = @system_adapter.system_argv()

    exe = exe_path_env || List.first(argv)

    if nil?(exe) do
      # Return error tuple
      {:error, :cannot_determine_executable_path}
    else
      {:ok, exe}
    end
  end

  defp apply_binary_delta(original_file, delta_file, output_file) do
    # We use bsdiff/bspatch for binary deltas
    # This assumes bspatch is available on the system
    case @system_adapter.system_cmd(
           "bspatch",
           [original_file, output_file, delta_file],
           []
         ) do
      {_output, 0} ->
        :ok

      {error_output, _exit_status} ->
        # Return error tuple
        {:error, {:apply_delta_failed, error_output}}
    end
  end

  defp verify_patched_executable(exe_path, expected_version) do
    case @system_adapter.file_chmod(exe_path, 0o755) do
      :ok -> check_version(exe_path, expected_version)
      {:error, reason} -> {:error, {:chmod_failed, reason}}
      error -> error
    end
  end

  defp check_version(exe_path, expected_version) do
    case @system_adapter.system_cmd(exe_path, ["--version"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        if String.contains?(output, expected_version),
          do: :ok,
          else: {:error, :version_verification_failed}

      {error_output, _exit_status} ->
        {:error, {:verify_failed_to_run, error_output}}
    end
  end

  defp replace_executable(current_exe, new_exe) do
    # Determine platform using adapter
    platform =
      case @system_adapter.os_type() do
        {:win32, _} -> "windows"
        # Default to unix for other :os.type() results
        _ -> "unix"
      end

    # Call the shared helper function via adapter
    @system_adapter.updater_do_replace_executable(
      current_exe,
      new_exe,
      platform
    )
  end

  defp get_releases do
    url = "https://api.github.com/repos/raxol/raxol/releases"
    headers = [{~c"User-Agent", ~c"Raxol-Updater"}]

    case @system_adapter.httpc_request(
           :get,
           {String.to_charlist(url), headers},
           [],
           []
         ) do
      {:ok, {{_http_vsn, 200, _reason_phrase}, _response_headers, body}} ->
        # Assuming body is a string that needs decoding
        try do
          {:ok, Jason.decode!(body)}
        rescue
          Jason.DecodeError -> {:error, :json_decode_error}
        end

      {:ok,
       {{_http_vsn, status_code, _reason_phrase}, _response_headers, _body}} ->
        {:error, {:fetch_releases_failed_status, status_code}}

      {:error, reason} ->
        {:error, {:fetch_releases_failed, reason}}
    end
  end
end
