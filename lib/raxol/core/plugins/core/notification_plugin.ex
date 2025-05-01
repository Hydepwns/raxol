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
    message = Map.get(data, :message, "Notification")
    title = Map.get(data, :title, "Raxol Notification")

    Logger.debug("NotificationPlugin: Sending notification - Title: '#{title}', Message: '#{message}'")

    # Use System.shell_escape for safer argument construction
    # Note: This assumes System.shell_escape is available (Elixir >= 1.11 approx)
    safe_message = System.shell_escape(message)
    safe_title = System.shell_escape(title)

    # Define commands separately for clarity
    {executable, args, os_name} =
      case :os.type() do
        {:unix, :linux} ->
          # Check if notify-send exists
          case System.find_executable("notify-send") do
            nil -> {nil, :notify_send_not_found, :linux}
            path -> {path, [safe_title, safe_message], :linux}
          end

        {:unix, :darwin} ->
          # Check if osascript exists
          case System.find_executable("osascript") do
             nil -> {nil, :osascript_not_found, :macos}
             path ->
               script = "display notification #{safe_message} with title #{safe_title}"
               {path, ["-e", script], :macos}
           end

        {:win32, _} ->
          # Use PowerShell with BurntToast module (requires user installation)
          # Check if powershell exists
          case System.find_executable("powershell") do
             nil -> {nil, :powershell_not_found, :windows}
             path ->
               # Simple text notification via BurntToast
               # Note: User needs to install BurntToast: Install-Module -Name BurntToast
               script = ~s(Import-Module BurntToast; New-BurntToastNotification -Text "#{message}")
               # Powershell args: -NoProfile, -ExecutionPolicy Bypass (maybe needed), -Command ...
               {path, ["-NoProfile", "-Command", script], :windows}
          end

        {_other_family, _other_name} = os_tuple ->
          {nil, {:unsupported_os, os_tuple}, :unsupported}

      end

    # Execute the command if executable found
    case executable do
      nil ->
        # Handle cases where executable wasn't found or OS is unsupported
        handle_notification_error(args, state)

      _ ->
        try do
          Logger.debug("Executing notification command: #{executable} with args: #{inspect(args)}")
          case System.cmd(executable, args, stderr_to_stdout: true) do
            {output, 0} ->
              Logger.debug("Notification command successful (Output: #{output})")
              {:ok, state, String.to_atom("notification_sent_#{os_name}")}
            {output, exit_code} ->
              Logger.error("Notification command failed. Exit Code: #{exit_code}, Output: #{output}")
              {:error, {:command_failed, exit_code, output}, state}
          end
        rescue
          e ->
            Logger.error("NotificationPlugin: Error executing notification command: #{inspect(e)}")
            {:error, {:command_exception, inspect(e.__struct__), Exception.message(e)}, state}
        end
    end
  end

  # Helper to handle specific notification errors
  defp handle_notification_error(reason, state) do
    case reason do
      :notify_send_not_found ->
        Logger.error("NotificationPlugin: Command 'notify-send' not found. Please install it.")
        {:error, {:command_not_found, :notify_send}, state}
      :osascript_not_found ->
        Logger.error("NotificationPlugin: Command 'osascript' not found.")
        {:error, {:command_not_found, :osascript}, state}
      :powershell_not_found ->
        Logger.error("NotificationPlugin: Command 'powershell' not found.")
        {:error, {:command_not_found, :powershell}, state}
      {:unsupported_os, os_tuple} ->
        Logger.warning("NotificationPlugin: Desktop notifications not supported on this OS: #{inspect(os_tuple)}")
        {:ok, state, :notification_skipped_unsupported_os} # Still ok, just skipped
      _ -> # Generic fallback
         Logger.error("NotificationPlugin: Unknown notification error: #{inspect reason}")
         {:error, {:unknown_notification_error, reason}, state}
    end
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
