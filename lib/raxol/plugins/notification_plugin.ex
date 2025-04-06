defmodule Raxol.Plugins.NotificationPlugin do
  @moduledoc """
  Plugin that provides terminal notifications with configurable styles and behaviors.
  """

  @behaviour Raxol.Plugins.Plugin

  @default_config %{
    style: "minimal",  # minimal, banner, or popup
    position: "top-right",  # top-right, top-left, bottom-right, bottom-left
    duration: 5000,  # notification duration in milliseconds
    sound: false,  # whether to play a sound
    max_notifications: 3,  # maximum number of visible notifications
    colors: %{
      success: {0, 255, 0},  # green
      error: {255, 0, 0},    # red
      warning: {255, 255, 0}, # yellow
      info: {0, 0, 255}      # blue
    }
  }

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :notifications,  # list of active notifications
    :dependencies,
    :api_version
  ]

  @impl true
  def init(config \\ %{}) do
    # Merge provided config with defaults
    merged_config = Map.merge(@default_config, config)

    {:ok, %__MODULE__{
      name: "notification",
      version: "1.0.0",
      description: "Provides terminal notifications with configurable styles and behaviors",
      enabled: true,
      config: merged_config,
      notifications: [],
      dependencies: [],
      api_version: "1.0.0"
    }}
  end

  @impl true
  def handle_input(plugin, input) do
    # Check for notification commands
    cond do
      String.starts_with?(input, "/notify ") ->
        # Format: /notify [type] [message]
        case parse_notification_command(input) do
          {:ok, type, message} ->
            # show_notification/3 returns {:ok, updated_plugin, display_string}
            # We need to conform to the expected handle_input/2 return type.
            # The display_string should ideally be sent via an output mechanism.
            case show_notification(plugin, type, message) do
              {:ok, updated_plugin, _display_string} ->
                # TODO: Send display_string to terminal output if necessary
                {:ok, updated_plugin}
            end
          {:error, reason} ->
            {:error, reason}
        end

      String.starts_with?(input, "/notify-config ") ->
        # Format: /notify-config [setting] [value]
        case parse_config_command(input) do
          {:ok, setting, value} ->
            update_config(plugin, setting, value)
          {:error, reason} ->
            {:error, reason}
        end

      true ->
        {:ok, plugin}
    end
  end

  @impl true
  def handle_output(plugin, _output) do
    {:ok, plugin}
  end

  @impl true
  def handle_mouse(_plugin, _event) do
    :ok
  end

  @impl true
  def handle_resize(_plugin, _width, _height) do
    :ok
  end

  @impl true
  def cleanup(_plugin) do
    :ok
  end

  @impl true
  def get_dependencies do
    # This plugin has no dependencies
    []
  end

  @impl true
  def get_api_version do
    "1.0.0"
  end

  # Private functions

  defp parse_notification_command(command) do
    # Expected format: "/notify type message"
    pattern = ~r/^\/notify\s+(\w+)\s+(.*)$/
    case Regex.run(pattern, command) do
      [_, type_str, message] ->
        # Attempt to convert type string to an existing atom
        try do
          type_atom = String.to_existing_atom(type_str)
          {:ok, type_atom, String.trim(message)}
        rescue
          ArgumentError ->
            {:error, "Invalid notification type: #{type_str}"}
        end
      nil ->
        {:error, "Invalid command format. Use: /notify <type> <message>"}
    end
  end

  defp parse_config_command(command) do
    # Expected format: "/notify-config setting value"
    pattern = ~r/^\/notify-config\s+([\w\-]+)\s+(.*)$/
    case Regex.run(pattern, command) do
      [_, setting, value] ->
        {:ok, String.trim(setting), String.trim(value)}
      nil ->
        {:error, "Invalid command format. Use: /notify-config <setting> <value>"}
    end
  end

  defp show_notification(plugin, type, message) do
    # Create notification
    notification = %{
      id: :rand.uniform(1000000),
      type: type,
      message: message,
      timestamp: System.system_time(:millisecond)
    }

    # Add to notifications list, respecting max_notifications limit
    notifications = [notification | plugin.notifications]
    |> Enum.take(plugin.config.max_notifications)

    # Generate notification display based on style
    display = generate_notification_display(notification, plugin.config)

    # Return updated plugin and display
    {:ok, %{plugin | notifications: notifications}, display}
  end

  defp generate_notification_display(notification, config) do
    {r, g, b} = Map.get(config.colors, String.to_atom(notification.type))

    case config.style do
      "minimal" ->
        # Simple text with color
        "\e[38;2;#{r};#{g};#{b}m[#{String.upcase(notification.type)}] #{notification.message}\e[0m"

      "banner" ->
        # Banner style with background
        """
        \e[48;2;#{r};#{g};#{b}m\e[38;2;0;0;0m
        #{String.pad_leading(String.upcase(notification.type), 10)} | #{notification.message}
        \e[0m
        """

      "popup" ->
        # Popup style with box drawing
        """
        \e[38;2;#{r};#{g};#{b}m┌#{String.duplicate("─", 50)}┐
        │ #{String.pad_leading(String.upcase(notification.type), 10)} │ #{notification.message}
        └#{String.duplicate("─", 50)}┘\e[0m
        """
    end
  end

  defp update_config(plugin, setting, value) do
    case setting do
      "style" when value in ["minimal", "banner", "popup"] ->
        {:ok, %{plugin | config: Map.put(plugin.config, :style, value)}}

      "position" when value in ["top-right", "top-left", "bottom-right", "bottom-left"] ->
        {:ok, %{plugin | config: Map.put(plugin.config, :position, value)}}

      "duration" ->
        case Integer.parse(value) do
          {duration, _} when duration > 0 ->
            {:ok, %{plugin | config: Map.put(plugin.config, :duration, duration)}}
          _ ->
            {:error, "Duration must be a positive integer"}
        end

      "sound" when value in ["true", "false"] ->
        {:ok, %{plugin | config: Map.put(plugin.config, :sound, value == "true")}}

      "max_notifications" ->
        case Integer.parse(value) do
          {max, _} when max > 0 ->
            {:ok, %{plugin | config: Map.put(plugin.config, :max_notifications, max)}}
          _ ->
            {:error, "Max notifications must be a positive integer"}
        end

      _ ->
        {:error, "Invalid setting or value"}
    end
  end
end
