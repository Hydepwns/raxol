defmodule Raxol.Core.Plugins.Core.NotificationPlugin do
  @moduledoc """
  Core plugin responsible for handling notifications (:notify).
  """

  require Logger

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(_config) do
    Logger.info("Notification Plugin initialized.")
    # No specific state needed
    {:ok, %{}}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      # Command name (atom), Function name (atom), Arity
      {:notify, :handle_command, 1}
    ]
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:notify, [data], state) when is_map(data) do
    handle_notify(data, state)
  end
  # Catch-all for incorrect args or unknown commands directed here
  def handle_command(command, args, state) do
    Logger.warning("NotificationPlugin received unhandled/invalid command: #{inspect command} with args: #{inspect args}")
    {:error, {:unhandled_notification_command, command}, state}
  end

  # Internal handler for :notify
  # data is expected to be a map like %{title: "Optional Title", message: "Message Body"}
  defp handle_notify(data, state) do
    message = Map.get(data, :message, "Notification") # Default message if missing
    title = Map.get(data, :title, "Raxol Notification") # Default title

    Logger.debug("NotificationPlugin: Sending notification...")

    # Escape message and title for shell commands
    # Basic escaping for quotes, may need more robust escaping depending on shell
    safe_message = String.replace(message, "\"", "\\\"")
    safe_title = String.replace(title, "\"", "\\\"")

    case :os.type() do
      {:unix, :linux} ->
        # Use notify-send on Linux
        cmd = "notify-send \"#{safe_title}\" \"#{safe_message}\""
        System.cmd(cmd, [])
        # We don't strictly need the result, assume fire-and-forget
        # Could add error checking based on exit code if needed
        Logger.debug("NotificationPlugin: Used notify-send.")
        {:ok, state, :notification_sent_linux}

      {:unix, :darwin} ->
        # Use osascript on macOS
        script = "display notification \"#{safe_message}\" with title \"#{safe_title}\""
        cmd = "osascript -e '#{script}'"
        System.cmd(cmd, [])
        Logger.debug("NotificationPlugin: Used osascript.")
        {:ok, state, :notification_sent_macos}

      {:win32, _} ->
        Logger.warning("NotificationPlugin: Desktop notifications not yet implemented for Windows.")
        {:ok, state, :notification_skipped_windows}

      _ ->
        Logger.warning("NotificationPlugin: Desktop notifications not supported on this OS: #{inspect(:os.type())}")
        {:ok, state, :notification_skipped_unsupported_os}
    end
  rescue
    e ->
      Logger.error("NotificationPlugin: Error executing notification command: #{inspect(e)}")
      {:error, {:notification_command_failed, inspect(e)}, state}
  end

  def terminate(_state) do
    Logger.info("Notification Plugin terminated.")
    :ok
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def terminate(_reason, _state) do
    Logger.info("Notification Plugin terminated (Behaviour callback).")
    :ok
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def enable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def disable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def filter_event(event, state), do: {:ok, event, state}
end
