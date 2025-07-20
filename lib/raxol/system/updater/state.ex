defmodule Raxol.System.Updater.State do
  @moduledoc """
  State management for the Raxol System Updater including settings, progress tracking, statistics, and logging.
  """

  @update_settings_file "~/.raxol/update_settings.json"

  def get_update_settings do
    case Application.get_env(:raxol, :update_settings) do
      nil -> default_update_settings()
      settings -> settings
    end
  end

  def set_update_settings(settings) do
    Application.put_env(:raxol, :update_settings, settings)
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
    File.write(stats_file, Jason.encode!(default_stats()))
  end

  def set_auto_check(enabled) when is_boolean(enabled) do
    with {:ok, settings} <- get_update_settings() do
      settings = Map.put(settings, "auto_check", enabled)
      save_update_settings(settings)
    end
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

  defp save_update_settings(settings) do
    file_path = Path.expand(@update_settings_file)

    case Jason.encode(settings) do
      {:ok, json} ->
        File.write(file_path, json)

      error ->
        error
    end
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

  def set_update_progress(progress) do
    Process.put(:update_progress, progress)
  end

  def set_update_error(error) do
    Process.put(:update_error, error)
  end

  def log_update(message) do
    settings = get_update_settings()
    log_file = Path.join(settings.download_path, "update.log")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    log_entry = "[#{timestamp}] #{message}\n"

    File.write(log_file, log_entry, [:append])
  end

  def update_stats(stats) do
    settings = get_update_settings()
    stats_file = Path.join(settings.download_path, "update_stats.json")
    File.write(stats_file, Jason.encode!(stats))
  end
end
