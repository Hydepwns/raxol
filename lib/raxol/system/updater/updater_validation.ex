defmodule Raxol.System.Updater.Validation do
  @moduledoc """
  Validation functions for the Raxol System Updater including version checking, platform detection, and settings validation.
  """

  @update_check_interval 86_400

  def get_platform do
    case :os.type() do
      {:unix, :darwin} -> "macos"
      {:unix, _} -> "linux"
      {:win32, _} -> "windows"
    end
  end

  def should_check_for_update?(settings) do
    auto_check = Map.get(settings, "auto_check", true)
    last_check = Map.get(settings, "last_check", 0)

    current_time = :os.system_time(:second)
    time_since_last_check = current_time - last_check

    auto_check && time_since_last_check >= @update_check_interval
  end

  def compare_versions({:ok, latest_version}) do
    case Mix.Project.config()[:version] == latest_version[:version] do
      true -> {:no_update, Mix.Project.config()[:version]}
      false -> {:update_available, latest_version[:version]}
    end
  end

  def update_last_check(settings) do
    Map.put(settings, :last_check, DateTime.utc_now())
  end
end
