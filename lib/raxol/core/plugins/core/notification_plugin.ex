defmodule Raxol.Core.Plugins.Core.NotificationPlugin do
  @moduledoc """
  Core plugin responsible for handling notifications (:notify).
  Relies on an implementation of Raxol.System.Interaction for OS interactions.
  """

  require Logger

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  # Default implementation module
  @default_interaction_module Raxol.System.InteractionImpl

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(_config) do
    # Determine interaction module at runtime
    interaction_mod =
      Application.get_env(
        :raxol,
        :system_interaction_module,
        @default_interaction_module
      )

    Logger.info(
      "Notification Plugin initialized (Interaction: #{interaction_mod})."
    )

    # Store the module in the plugin state and initialize other fields
    initial_state = %{
      interaction_module: interaction_mod,
      name: "notification",
      enabled: true,
      # Default config
      config: %{style: "minimal"},
      # Initialize notifications list
      notifications: []
    }

    {:ok, initial_state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      {:notify, :handle_command, 2}
    ]
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  # Handle :notify with [level_string, message_string] arguments
  def handle_command(:notify, [level, message], state)
      when is_binary(level) and is_binary(message) do
    # Extract here
    interaction_mod = state.interaction_module
    # Construct the data map expected by handle_notify
    # Using level as title for simplicity, could be refined
    data_map = %{title: level, message: message}
    handle_notify(interaction_mod, data_map, state)
  end

  # Catch-all for missing interaction module in state (shouldn't happen)
  # def handle_command(:notify, [data], state) when is_map(data) do
  #    Logger.error("NotificationPlugin state missing :interaction_module!")
  #    {:error, :internal_plugin_error, state}
  # end

  # Catch-all for incorrect args or unknown commands directed here
  def handle_command(command, args, state) do
    Logger.warning(
      "NotificationPlugin received unhandled/invalid command: #{inspect(command)} with args: #{inspect(args)}"
    )

    {:error, {:unhandled_notification_command, command}, state}
  end

  # Internal handler for :notify
  # Retrieves interaction_mod from state
  defp handle_notify(interaction_mod, data, state) do
    message = Map.get(data, :message, "Notification")
    title = Map.get(data, :title, "Raxol Notification")

    Logger.debug(
      "NotificationPlugin: Sending notification - Title: '#{title}', Message: '#{message}'"
    )

    # Determine the command and arguments based on the OS using injected module
    {executable, args, os_name} =
      case interaction_mod.get_os_type() do
        {:unix, :linux} ->
          # Check if notify-send exists
          case interaction_mod.find_executable("notify-send") do
            nil ->
              {:error, {:command_not_found, :notify_send}, nil}

            path ->
              # Use raw title/message
              {path, [title, message], :linux}
          end

        {:unix, :darwin} ->
          # Check if osascript exists
          case interaction_mod.find_executable("osascript") do
            nil ->
              {:error, {:command_not_found, :osascript}, nil}

            path ->
              # Construct the AppleScript command
              script =
                if title do
                  ~s(display notification \"#{message}\" with title \"#{title}\")
                else
                  ~s(display notification \"#{message}\")
                end

              {path, ["-e", script], :macos}
          end

        {:win32, :nt} ->
          # Use PowerShell with BurntToast module (requires user installation)
          # Check if powershell exists
          case interaction_mod.find_executable("powershell") do
            nil ->
              # Corrected error tuple
              {:error, {:command_not_found, :powershell}, nil}

            path ->
              # Simple text notification via BurntToast
              # Note: User needs to install BurntToast: Install-Module -Name BurntToast
              script =
                ~s(Import-Module BurntToast; New-BurntToastNotification -Text "#{message}")

              # Powershell args: -NoProfile, -ExecutionPolicy Bypass (maybe needed), -Command ...
              {path, ["-NoProfile", "-Command", script], :windows}
          end

        # Other OS types are currently unsupported
        other_os ->
          # Pass OS tuple in error
          {:error, {:unsupported_os, other_os}, nil}
      end

    # Execute the command if executable found
    case executable do
      # Handle cases where executable wasn't found or OS is unsupported *before* trying system_cmd
      :error ->
        # 'args' here is the error tuple
        handle_notification_error(args, state)

      # Valid executable path found
      _ ->
        try do
          Logger.debug(
            "Executing notification command: #{executable} with args: #{inspect(args)}"
          )

          # Use injected module
          case interaction_mod.system_cmd(executable, args,
                 stderr_to_stdout: true
               ) do
            {output, 0} ->
              Logger.debug(
                "Notification command successful (Output: #{output})"
              )

              {:ok, state, :notification_sent}

            {output, exit_code} ->
              Logger.error(
                "Notification command failed. Exit Code: #{exit_code}, Output: #{output}"
              )

              {:error, {:command_failed, exit_code, output}, state}
          end
        rescue
          e ->
            Logger.error(
              "NotificationPlugin: Error executing notification command: #{inspect(e)}"
            )

            {:error,
             {:command_exception, inspect(e.__struct__), Exception.message(e)},
             state}
        end
    end
  end

  # Helper to handle specific notification errors
  defp handle_notification_error(reason_tuple, state) do
    case reason_tuple do
      {:command_not_found, :notify_send} ->
        Logger.error(
          "NotificationPlugin: Command 'notify-send' not found. Please install it."
        )

        {:error, {:command_not_found, :notify_send}, state}

      {:command_not_found, :osascript} ->
        Logger.error("NotificationPlugin: Command 'osascript' not found.")
        {:error, {:command_not_found, :osascript}, state}

      {:command_not_found, :powershell} ->
        Logger.error("NotificationPlugin: Command 'powershell' not found.")
        {:error, {:command_not_found, :powershell}, state}

      {:unsupported_os, os_tuple} ->
        Logger.warning(
          "NotificationPlugin: Desktop notifications not supported on this OS: #{inspect(os_tuple)}"
        )

        {:ok, state, :notification_skipped_unsupported_os}

      # Generic fallback
      _ ->
        Logger.error(
          "NotificationPlugin: Unknown notification error: #{inspect(reason_tuple)}"
        )

        {:error, {:unknown_notification_error, reason_tuple}, state}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def terminate(_state) do
    Logger.info("Notification Plugin terminated.")
    :ok
  end

  # Keep both terminate clauses if needed by different supervisor strategies
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
