defmodule Raxol.System.DeltaUpdaterSystemAdapterImpl do
  @moduledoc """
  System adapter implementation for delta updater.

  Provides concrete implementations of system operations needed
  for delta updating, including HTTP requests and file operations.
  """

  @behaviour Raxol.System.DeltaUpdaterSystemAdapterBehaviour

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def httpc_request(method, url_with_headers, http_options, stream_options) do
    :httpc.request(method, url_with_headers, http_options, stream_options)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def os_type() do
    :os.type()
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def system_tmp_dir() do
    System.tmp_dir()
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def system_get_env(varname) do
    System.get_env(varname)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def system_argv() do
    System.argv()
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def system_cmd(command, args, options) do
    System.cmd(command, args, options)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def file_mkdir_p(path) do
    File.mkdir_p(path)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def file_rm_rf(path) do
    File.rm_rf(path)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def file_chmod(path, mode) do
    File.chmod(path, mode)
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def updater_do_replace_executable(current_exe, new_exe, platform) do
    Raxol.System.Updater.Network.do_replace_executable(
      current_exe,
      new_exe,
      platform
    )
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def current_version() do
    # Try to get the version from Mix.Project if available, otherwise fallback
    case Application.spec(:raxol, :vsn) do
      nil ->
        # Try Mix.Project.config if available (compile time)
        # Code.ensure_loaded?/1 returns a boolean, not {:module, _} or {:error, _}
        case Code.ensure_loaded?(Mix.Project) do
          true ->
            config = Mix.Project.config()
            to_string(config[:version] || "0.0.0")
          false ->
            "0.0.0"
        end

      vsn ->
        to_string(vsn)
    end
  end

  @impl Raxol.System.DeltaUpdaterSystemAdapterBehaviour
  def http_get(url) do
    # Perform a real HTTP GET using :httpc and return the body as a string
    case :httpc.request(:get, {to_charlist(url), []}, [], []) do
      {:ok, {{_http_vsn, 200, _reason_phrase}, _headers, body}} ->
        {:ok, IO.iodata_to_binary(body)}

      {:ok, {{_http_vsn, status, _reason_phrase}, _headers, body}} ->
        {:error, {:http_error, status, IO.iodata_to_binary(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
