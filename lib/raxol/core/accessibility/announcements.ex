defmodule Raxol.Core.Accessibility.Announcements do
  use Agent
  import Raxol.Guards

  @moduledoc """
  Handles screen reader announcements and announcement queue management.
  """

  alias Raxol.Core.Events.Manager, as: EventManager
  require Raxol.Core.Runtime.Log

  # Start the Agent for global subscription storage
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__.Subscriptions)
  end

  def add_subscription(ref, pid) do
    Agent.update(__MODULE__.Subscriptions, &Map.put(&1, ref, pid))
  end

  def remove_subscription(ref) do
    Agent.update(__MODULE__.Subscriptions, &Map.delete(&1, ref))
  end

  def get_subscriptions do
    Agent.get(__MODULE__.Subscriptions, & &1)
  end

  @doc """
  Make an announcement for screen readers.

  ## Parameters

  * `message` - The message to announce
  * `opts` - Options for the announcement
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Options

  * `:priority` - Priority level (`:low`, `:medium`, `:high`) (default: `:medium`)
  * `:interrupt` - Whether to interrupt current announcements (default: `false`)

  ## Examples

      iex> Announcements.announce("Button clicked")
      :ok

      iex> Announcements.announce("Error occurred", priority: :high, interrupt: true)
      :ok
  """
  def announce(message, opts \\ [], user_preferences_pid_or_name)
      when binary?(message) do
    if nil?(user_preferences_pid_or_name) do
      raise "Accessibility.Announcements.announce/3 must be called with a user_preferences_pid_or_name."
    end

    if should_announce?(user_preferences_pid_or_name) do
      process_announcement(message, opts, user_preferences_pid_or_name)
    end

    :ok
  end

  defp should_announce?(user_preferences_pid_or_name) do
    disabled = Process.get(:accessibility_disabled) == true
    silenced = get_silence_setting(user_preferences_pid_or_name)

    screen_reader_enabled =
      get_screen_reader_setting(user_preferences_pid_or_name)

    not disabled and not silenced and screen_reader_enabled != false
  end

  defp process_announcement(message, opts, user_preferences_pid_or_name) do
    priority = Keyword.get(opts, :priority, :normal)
    interrupt = Keyword.get(opts, :interrupt, false)

    announcement = %{
      message: message,
      priority: priority,
      timestamp: System.monotonic_time(:millisecond),
      interrupt: interrupt
    }

    key = {:accessibility_announcements, user_preferences_pid_or_name}
    current_queue = Process.get(key, [])

    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "Announcements.announce storing with key: #{inspect(key)}, current_queue: #{inspect(current_queue)}"
    )

    updated_queue =
      if announcement.interrupt,
        do: [announcement],
        else: insert_by_priority(current_queue, announcement, priority)

    Process.put(key, updated_queue)

    legacy_queue = Process.get(:accessibility_announcements, [])
    Process.put(:accessibility_announcements, [announcement | legacy_queue])

    Raxol.Core.Runtime.Log.debug(
      "Announcements.announce stored announcement: #{inspect(announcement)}"
    )

    send_announcement_to_subscribers(message)

    EventManager.dispatch({:accessibility_announce, message})
  end

  @doc """
  Get the next announcement to be read by screen readers for a specific user/context.

  ## Parameters
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Examples
      iex> Announcements.get_next_announcement(:user1)
      "Button clicked"
  """
  def get_next_announcement(user_preferences_pid_or_name) do
    key =
      if user_preferences_pid_or_name do
        {:accessibility_announcements, user_preferences_pid_or_name}
      else
        :accessibility_announcements
      end

    queue = Process.get(key) || []

    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "Announcements.get_next_announcement looking for key: #{inspect(key)}, queue: #{inspect(queue)}"
    )

    case queue do
      [] ->
        Raxol.Core.Runtime.Log.debug(
          "Announcements.get_next_announcement returning nil (empty queue)"
        )

        nil

      [next | rest] ->
        Process.put(key, rest)

        Raxol.Core.Runtime.Log.debug(
          "Announcements.get_next_announcement returning: #{inspect(next.message)}"
        )

        next.message
    end
  end

  @doc """
  Clear all pending announcements.

  ## Examples

      iex> Announcements.clear_announcements()
      :ok
  """
  def clear_announcements do
    # Clear global announcements
    Process.put(:accessibility_announcements, [])

    # Clear all user-specific announcement queues
    # Get all process dictionary keys that match the pattern {:accessibility_announcements, _}
    all_keys = Process.get() |> Enum.map(&elem(&1, 0))

    announcement_keys =
      all_keys
      |> Enum.filter(fn key ->
        case key do
          {:accessibility_announcements, _} -> true
          _ -> false
        end
      end)

    # Clear each user-specific queue
    Enum.each(announcement_keys, fn key ->
      Process.put(key, [])
    end)

    # Send announcements_cleared messages to subscribers
    send_clear_message_to_subscribers()

    :ok
  end

  @doc """
  Clear all pending announcements for a specific user.

  ## Examples

      iex> Announcements.clear_announcements(:user_prefs)
      :ok
  """
  def clear_announcements(user_preferences_pid_or_name) do
    key = {:accessibility_announcements, user_preferences_pid_or_name}
    Process.put(key, [])
    :ok
  end

  # --- Private Functions ---

  defp get_silence_setting(user_preferences_pid_or_name) do
    case Raxol.Core.UserPreferences.get(
           [:accessibility, :silence_announcements],
           user_preferences_pid_or_name
         ) do
      true -> true
      _ -> false
    end
  end

  defp get_screen_reader_setting(user_preferences_pid_or_name) do
    case Raxol.Core.UserPreferences.get(
           [:accessibility, :screen_reader],
           user_preferences_pid_or_name
         ) do
      false -> false
      _ -> true
    end
  end

  # Inserting announcement into queue by priority
  defp insert_by_priority(queue, announcement, priority) do
    # medium == normal
    priority_order = %{high: 3, normal: 2, medium: 2, low: 1}
    _announcement_priority = Map.get(priority_order, priority, 2)

    Enum.sort_by(queue ++ [announcement], fn item ->
      # Sort descending by priority
      Map.get(priority_order, item.priority, 2) * -1
    end)
  end

  defp send_announcement_to_subscribers(message) do
    subscriptions = get_subscriptions()

    Enum.each(subscriptions, fn {ref, pid} ->
      if Process.alive?(pid) do
        send(pid, {:announcement_added, ref, message})
      end
    end)
  end

  defp send_clear_message_to_subscribers do
    subscriptions = get_subscriptions()

    Enum.each(subscriptions, fn {ref, pid} ->
      if Process.alive?(pid) do
        send(pid, {:announcements_cleared, ref})
      end
    end)
  end
end
