defmodule Raxol.Core.Accessibility.Announcements do
  @moduledoc """
  Handles screen reader announcements and announcement queue management.
  """

  alias Raxol.Core.Events.Manager, as: EventManager
  require Logger

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
  def announce(message, opts \\ [], user_preferences_pid_or_name) when is_binary(message) do
    if is_nil(user_preferences_pid_or_name) do
      raise "Accessibility.Announcements.announce/3 must be called with a user_preferences_pid_or_name."
    end
    disabled = Process.get(:accessibility_disabled) == true

    # Check if announcements are silenced
    silenced = get_silence_setting(user_preferences_pid_or_name)

    # Check if screen reader is enabled
    screen_reader_enabled =
      get_screen_reader_setting(user_preferences_pid_or_name)

    cond do
      # Do nothing if accessibility is disabled
      disabled ->
        :ok

      # Do nothing if announcements are silenced
      silenced ->
        :ok

      # Do nothing if screen reader is disabled
      screen_reader_enabled == false ->
        :ok

      true ->
        # Settings allow announcements, proceed
        priority = Keyword.get(opts, :priority, :normal)
        interrupt = Keyword.get(opts, :interrupt, false)

        announcement = %{
          message: message,
          priority: priority,
          timestamp: System.monotonic_time(:millisecond),
          interrupt: interrupt
        }

        # Add to queue
        current_queue = Process.get(:accessibility_announcements, [])

        updated_queue =
          if announcement.interrupt,
            do: [announcement],
            else: insert_by_priority(current_queue, announcement, priority)

        Process.put(:accessibility_announcements, updated_queue)

        # Dispatch event to notify screen readers
        EventManager.dispatch({:accessibility_announce, message})
    end

    :ok
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

    case queue do
      [] ->
        nil

      [next | rest] ->
        Process.put(key, rest)
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
    Process.put(:accessibility_announcements, [])
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
    announcement_priority = Map.get(priority_order, priority, 2)

    Enum.sort_by(queue ++ [announcement], fn item ->
      # Sort descending by priority
      Map.get(priority_order, item.priority, 2) * -1
    end)
  end
end
