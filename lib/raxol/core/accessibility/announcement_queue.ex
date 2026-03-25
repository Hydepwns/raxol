defmodule Raxol.Core.Accessibility.AnnouncementQueue do
  @moduledoc """
  Pure-functional helpers for announcement queue management, priority sorting,
  history tracking, and delivery.  Used by AccessibilityServer.
  """

  alias Raxol.Core.Events.EventManager

  @doc """
  Returns the announcement state map after processing a new announcement.
  Does nothing if announcements should not be processed.
  """
  def process(
        announcements_state,
        message,
        opts,
        callback,
        enabled?,
        screen_reader?,
        silenced?
      ) do
    if enabled? and screen_reader? and not silenced? do
      do_process(announcements_state, message, opts, callback)
    else
      announcements_state
    end
  end

  @doc "Returns history limited to `limit` entries (or all when nil)."
  def limited_history(history, nil), do: history
  def limited_history(history, limit), do: Enum.take(history, limit)

  @doc "Returns {next_message, updated_announcements_state} or {nil, state} when empty."
  def pop(announcements_state) do
    case announcements_state.queue do
      [] ->
        {nil, announcements_state}

      [announcement | rest] ->
        {announcement.message, %{announcements_state | queue: rest}}
    end
  end

  @doc """
  Parses event dispatcher arguments into `{old_focus, new_focus}` tuples.
  Returns `{nil, nil}` when the event cannot be parsed.
  """
  def parse_focus_change_event_data(event_data) do
    case event_data do
      %{old_focus: old_focus, new_focus: new_focus} ->
        {old_focus, new_focus}

      %{nil: new_focus} ->
        {nil, new_focus}

      {old_focus, new_focus} ->
        {old_focus, new_focus}

      new_focus when is_binary(new_focus) ->
        {nil, new_focus}

      map when is_map(map) ->
        case Map.values(map) do
          [new_focus] -> {nil, new_focus}
          [old_focus, new_focus] -> {old_focus, new_focus}
          _ -> {nil, inspect(map)}
        end

      other ->
        {nil, other}
    end
  end

  @doc "Appends a high-priority focus announcement to both queue and history."
  def enqueue_focus(announcements_state, text, event_manager_pid) do
    announcement = %{
      message: text,
      priority: :high,
      timestamp: DateTime.utc_now(),
      opts: [priority: :high]
    }

    new_history = [announcement | announcements_state.history]

    limited_history =
      Enum.take(new_history, announcements_state.max_history)

    new_queue = announcements_state.queue ++ [announcement]

    if event_manager_pid do
      EventManager.dispatch(:screen_reader_announcement, %{text: text})
    end

    %{announcements_state | history: limited_history, queue: new_queue}
  end

  # --- private ---

  defp do_process(announcements_state, message, opts, callback) do
    priority = Keyword.get(opts, :priority, :medium)
    interrupt = Keyword.get(opts, :interrupt, false)

    announcement = %{
      message: message,
      priority: priority,
      timestamp: DateTime.utc_now(),
      opts: opts
    }

    new_history =
      [announcement | announcements_state.history]
      |> Enum.take(announcements_state.max_history)

    new_queue =
      handle_delivery(
        interrupt,
        announcements_state.queue,
        announcement,
        callback
      )

    %{announcements_state | history: new_history, queue: new_queue}
  end

  defp handle_delivery(true, _queue, announcement, callback) do
    deliver(announcement, callback)
    [announcement]
  end

  defp handle_delivery(false, queue, announcement, callback) do
    if Enum.empty?(queue) do
      deliver(announcement, callback)
      queue ++ [announcement]
    else
      new_queue = insert_by_priority(queue, announcement)
      process_head(new_queue, callback)
      new_queue
    end
  end

  defp deliver(announcement, callback) do
    call_callback(callback, announcement.message)

    if Process.whereis(EventManager) do
      EventManager.dispatch({:screen_reader_announcement, announcement.message})
    end

    :ok
  end

  defp call_callback(nil, _message), do: :ok
  defp call_callback(callback, message), do: callback.(message)

  defp process_head([], _callback), do: :ok

  defp process_head([announcement | _rest], callback),
    do: deliver(announcement, callback)

  defp insert_by_priority(queue, announcement) do
    (queue ++ [announcement])
    |> Enum.with_index()
    |> Enum.sort_by(fn {a, idx} ->
      priority_val =
        case a.priority do
          :high -> 1
          :medium -> 2
          :normal -> 2
          :low -> 3
          _ -> 2
        end

      {priority_val, idx}
    end)
    |> Enum.map(fn {a, _idx} -> a end)
  end
end
