defmodule Raxol.System.DeltaUpdaterSystemAdapterImpl do
  @behaviour Raxol.System.DeltaUpdaterSystemAdapterBehaviour

  alias Raxol.System.Updater

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
    Updater.do_replace_executable(current_exe, new_exe, platform)
  end
end
