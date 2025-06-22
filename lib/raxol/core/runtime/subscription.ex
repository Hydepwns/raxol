defmodule Raxol.Core.Runtime.Subscription do
  import Raxol.Guards

  @moduledoc """
  Provides a way to subscribe to recurring updates and external events.

  Subscriptions allow applications to receive messages over time without
  explicitly requesting them. This is useful for:
  * Timer-based updates (animation, polling)
  * System events (window resize, focus change)
  * External data streams (file changes, network events)

  ## Types of Subscriptions

  * `:interval` - Regular time-based updates
  * `:events` - System or component events
  * `:file_watch` - File system changes
  * `:custom` - Custom event sources

  ## Examples

      # Update every second
      Subscription.interval(1000, :tick)

      # Listen for specific events
      Subscription.events([:key_press, :mouse_click])

      # Watch a file for changes
      Subscription.file_watch("config.json", [:modify, :delete])

      # Custom subscription
      Subscription.custom(MyEventSource, :start_listening)
  """

  @type t :: %__MODULE__{
          type: :interval | :events | :file_watch | :custom,
          data: term()
        }

  defstruct [:type, :data]

  @doc """
  Creates a new subscription. This is the low-level constructor, prefer using
  the specific subscription constructors unless you need custom behavior.
  """
  def new(type, data) do
    %__MODULE__{type: type, data: data}
  end

  @doc """
  Creates a subscription that will send a message at regular intervals.

  ## Options
    * `:start_immediately` - Send first message immediately (default: false)
    * `:jitter` - Add random jitter to interval (default: 0)
  """
  def interval(interval_ms, msg, opts \\ [])

  def interval(interval_ms, msg, opts)
      when integer?(interval_ms) and interval_ms > 0 do
    data = %{
      interval: interval_ms,
      message: msg,
      start_immediately: Keyword.get(opts, :start_immediately, false),
      jitter: Keyword.get(opts, :jitter, 0)
    }

    new(:interval, data)
  end

  def interval(_interval_ms, _msg, _opts) do
    {:error, :invalid_interval}
  end

  @doc """
  Creates a subscription for system or component events.

  ## Event Types
    * `:key_press` - Keyboard events
    * `:mouse_click` - Mouse click events
    * `:mouse_move` - Mouse movement events
    * `:window_resize` - Terminal window resize
    * `:focus_change` - Terminal focus change
    * `:component` - Component-specific events
  """
  def events(event_types) when list?(event_types) do
    new(:events, event_types)
  end

  def events(_event_types) do
    {:error, :invalid_events}
  end

  @doc """
  Creates a subscription that watches for file system changes.

  ## Event Types
    * `:modify` - File content changes
    * `:delete` - File deletion
    * `:create` - File creation
    * `:rename` - File rename
    * `:attrib` - Attribute changes

  Returns `{:error, :invalid_file_watch_args}` if event_types is not a list.
  """
  def file_watch(path, event_types \\ [:modify])

  def file_watch(path, event_types) when list?(event_types) do
    data = %{
      path: path,
      events: event_types
    }

    new(:file_watch, data)
  end

  def file_watch(_path, _event_types), do: {:error, :invalid_file_watch_args}

  @doc """
  Creates a custom subscription using a provided event source.
  The event source should implement the `Raxol.Core.Runtime.EventSource`
  behaviour.
  """
  def custom(source_module, init_args) do
    data = %{
      module: source_module,
      args: init_args
    }

    new(:custom, data)
  end

  @doc """
  Starts a subscription within the given context. This is used by the runtime
  system and should not be called directly by applications.

  Returns `{:ok, subscription_id}` or `{:error, reason}`.
  """
  def start(%__MODULE__{} = subscription, context) do
    case subscription do
      %{type: :interval, data: data} ->
        start_interval(data, context)

      %{type: :events, data: event_types} ->
        start_event_subscription(event_types, context)

      %{type: :file_watch, data: data} ->
        start_file_watch(data, context)

      %{type: :custom, data: data} ->
        start_custom_subscription(data, context)
    end
  end

  @doc """
  Stops a subscription. This is used by the runtime system and should not
  be called directly by applications.
  """
  def stop(subscription_id) do
    stop_subscription(subscription_id)
  end

  defp stop_subscription({:interval, timer_ref}), do: stop_interval(timer_ref)
  defp stop_subscription({:events, actual_id}), do: stop_events(actual_id)
  defp stop_subscription({:file_watch, watcher_pid}), do: stop_file_watch(watcher_pid)
  defp stop_subscription({:custom, source_pid}), do: stop_custom(source_pid)
  defp stop_subscription(_), do: {:error, :invalid_subscription}

  defp stop_interval(timer_ref) do
    case :timer.cancel(timer_ref) do
      {:ok, :cancel} -> :ok
      {:error, reason} -> {:error, {:timer_cancel_error, reason}}
      _ -> :ok
    end
  end

  defp stop_events(actual_id) do
    Raxol.Core.Events.Manager.unsubscribe(actual_id)
    :ok
  end

  defp stop_file_watch(watcher_pid) do
    if Process.alive?(watcher_pid), do: Process.exit(watcher_pid, :normal), else: {:error, :process_not_alive}
  end

  defp stop_custom(source_pid) do
    if Process.alive?(source_pid), do: Process.exit(source_pid, :normal), else: {:error, :process_not_alive}
  end

  # Private helpers for starting different types of subscriptions

  defp start_interval(data, context) do
    %{
      interval: interval,
      message: msg,
      start_immediately: immediate,
      jitter: jitter
    } = data

    if immediate do
      send(context.pid, {:subscription, msg})
    end

    # Calculate jitter safely, ensuring we don't call :rand.uniform with 0
    jitter_ms = if jitter > 0, do: :rand.uniform(jitter), else: 0

    # Add error handling for timer creation
    case :timer.send_interval(
           interval + jitter_ms,
           context.pid,
           {:subscription, msg}
         ) do
      {:ok, timer_ref} ->
        {:ok, {:interval, timer_ref}}

      {:error, reason} ->
        {:error, {:timer_creation_error, reason}}
    end
  end

  defp start_event_subscription(event_types, context) do
    subscription_id =
      Raxol.Core.Events.Manager.subscribe(event_types, context.pid)

    {:ok, {:events, subscription_id}}
  end

  defp start_file_watch(data, context) do
    %{path: path, events: events} = data

    {:ok, pid} =
      Task.start(fn ->
        watch_file(path, events, context.pid)
      end)

    {:ok, {:file_watch, pid}}
  end

  defp start_custom_subscription(data, context) do
    %{module: module, args: args} = data

    case module.start_link(args, context) do
      {:ok, pid} -> {:ok, {:custom, pid}}
      error -> error
    end
  end

  # File watching helper
  defp watch_file(path, events, target_pid) do
    case FileSystem.start_link(dirs: [path]) do
      {:ok, watcher_pid} ->
        case FileSystem.subscribe(watcher_pid) do
          :ok ->
            receive do
              {_watcher_pid, {:file_event, path, file_events}} ->
                if Enum.any?(file_events, &(&1 in events)) do
                  send(
                    target_pid,
                    {:subscription, {:file_change, path, file_events}}
                  )
                end
            after
              5000 ->
                # Timeout after 5 seconds if no file events are received
                send(target_pid, {:subscription, {:file_watch_timeout, path}})
            end

            # Continue watching
            watch_file(path, events, target_pid)

          error ->
            send(
              target_pid,
              {:subscription, {:file_watch_error, {:subscribe_error, error}}}
            )
        end

      {:error, reason} ->
        send(
          target_pid,
          {:subscription, {:file_watch_error, {:start_error, reason}}}
        )
    end
  end
end
