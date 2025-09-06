defmodule Raxol.Core.Accessibility.Server do
  @moduledoc """
  Unified GenServer implementation for accessibility features in Raxol.

  This server consolidates all accessibility state management, eliminating
  Process dictionary usage across Accessibility, Announcements, and Metadata modules.

  ## Features
  - Screen reader announcements with queuing and priority
  - High contrast mode management
  - Reduced motion support
  - Large text support
  - Keyboard focus indicators
  - Accessibility metadata tracking
  - User preference integration
  - Theme integration for accessibility
  - Announcement history tracking

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    enabled: boolean(),
    preferences: %{
      screen_reader: boolean(),
      high_contrast: boolean(),
      reduced_motion: boolean(),
      large_text: boolean(),
      keyboard_focus: boolean(),
      silence_announcements: boolean()
    },
    announcements: %{
      queue: [announcement],
      history: [announcement],
      max_history: 100
    },
    metadata: %{component_id => metadata},
    theme_settings: map(),
    user_preferences_pid: pid() | nil,
    announcement_callback: function() | nil
  }
  ```
  """

  use GenServer
  require Logger
  alias Raxol.Core.Events.Manager, as: EventManager

  @default_preferences %{
    screen_reader: true,
    high_contrast: false,
    reduced_motion: false,
    large_text: false,
    keyboard_focus: true,
    silence_announcements: false
  }

  @default_state %{
    enabled: false,
    preferences: @default_preferences,
    announcements: %{
      queue: [],
      history: [],
      max_history: 100
    },
    metadata: %{},
    theme_settings: %{},
    user_preferences_pid: nil,
    announcement_callback: nil
  }

  # Client API

  @doc """
  Starts the Accessibility server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    initial_state = Keyword.get(opts, :initial_state, @default_state)
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Enables accessibility features with the given options.
  """
  def enable(server \\ __MODULE__, options \\ [], user_preferences_pid \\ nil) do
    GenServer.call(server, {:enable, options, user_preferences_pid})
  end

  @doc """
  Disables accessibility features.
  """
  def disable(server \\ __MODULE__) do
    GenServer.call(server, :disable)
  end

  @doc """
  Checks if accessibility is enabled.
  """
  def enabled?(server \\ __MODULE__) do
    GenServer.call(server, :is_enabled)
  end

  @doc """
  Makes an announcement for screen readers.

  ## Options
  - `:priority` - Priority level (:high, :medium, :low) default: :medium
  - `:interrupt` - Whether to interrupt current announcement default: false
  - `:language` - Language for the announcement
  """
  def announce(server \\ __MODULE__, message, opts \\ []) do
    GenServer.cast(server, {:announce, message, opts})
  end

  @doc """
  Announces with synchronous confirmation.
  """
  def announce_sync(server \\ __MODULE__, message, opts \\ []) do
    GenServer.call(server, {:announce_sync, message, opts})
  end

  @doc """
  Sets high contrast mode.
  """
  def set_high_contrast(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :high_contrast, enabled})
  end

  @doc """
  Gets high contrast mode status.
  """
  def high_contrast?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :high_contrast})
  end

  @doc """
  Sets reduced motion mode.
  """
  def set_reduced_motion(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :reduced_motion, enabled})
  end

  @doc """
  Gets reduced motion mode status.
  """
  def reduced_motion?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :reduced_motion})
  end

  @doc """
  Sets large text mode.
  """
  def set_large_text(server \\ __MODULE__, enabled) when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :large_text, enabled})
  end

  @doc """
  Gets large text mode status.
  """
  def large_text?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :large_text})
  end

  @doc """
  Sets screen reader support.
  """
  def set_screen_reader(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :screen_reader, enabled})
  end

  @doc """
  Gets screen reader support status.
  """
  def screen_reader?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :screen_reader})
  end

  @doc """
  Sets keyboard focus indicators.
  """
  def set_keyboard_focus(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :keyboard_focus, enabled})
  end

  @doc """
  Sets accessibility metadata for a component.
  """
  def set_metadata(server \\ __MODULE__, component_id, metadata) do
    GenServer.call(server, {:set_metadata, component_id, metadata})
  end

  @doc """
  Registers element metadata for a component.
  """
  def register_element_metadata(element_id, metadata) do
    register_element_metadata(__MODULE__, element_id, metadata)
  end

  def register_element_metadata(server, element_id, metadata) do
    GenServer.call(server, {:register_metadata, element_id, metadata})
  end

  @doc """
  Gets element metadata for a component.
  """
  def get_element_metadata(element_id) do
    get_element_metadata(__MODULE__, element_id)
  end

  def get_element_metadata(server, element_id) do
    GenServer.call(server, {:get_metadata, element_id})
  end

  @doc """
  Gets accessibility metadata for a component.
  """
  def get_metadata(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:get_metadata, component_id})
  end

  @doc """
  Removes metadata for a component.
  """
  def remove_metadata(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:remove_metadata, component_id})
  end

  @doc """
  Gets all current preferences.
  """
  def get_preferences(server \\ __MODULE__) do
    GenServer.call(server, :get_preferences)
  end

  @doc """
  Adds an announcement to the queue.
  """
  def add_announcement(announcement, user_preferences_pid_or_name \\ nil) do
    add_announcement(__MODULE__, announcement, user_preferences_pid_or_name)
  end

  def add_announcement(server, announcement, _user_preferences_pid_or_name) do
    GenServer.cast(server, {:announce, announcement, []})
  end

  @doc """
  Gets the next announcement from the queue.
  """
  def get_next_announcement(user_preferences_pid_or_name \\ nil) do
    get_next_announcement(__MODULE__, user_preferences_pid_or_name)
  end

  def get_next_announcement(server, _user_preferences_pid_or_name) do
    GenServer.call(server, :get_next_announcement)
  end

  @doc """
  Clears all announcements from the queue.
  """
  def clear_all_announcements do
    clear_all_announcements(__MODULE__)
  end

  def clear_all_announcements(server) do
    GenServer.call(server, :clear_all_announcements)
  end

  @doc """
  Clears announcements for a specific user.
  """
  def clear_announcements(user_preferences_pid_or_name) do
    clear_announcements(__MODULE__, user_preferences_pid_or_name)
  end

  def clear_announcements(server, _user_preferences_pid_or_name) do
    GenServer.call(server, :clear_all_announcements)
  end

  @doc """
  Gets announcement history.
  """
  def get_announcement_history(server \\ __MODULE__, limit \\ nil) do
    GenServer.call(server, {:get_announcement_history, limit})
  end

  @doc """
  Clears announcement history.
  """
  def clear_announcement_history(server \\ __MODULE__) do
    GenServer.call(server, :clear_announcement_history)
  end

  @doc """
  Sets the announcement callback function.
  """
  def set_announcement_callback(server \\ __MODULE__, callback)
      when is_function(callback, 1) do
    GenServer.call(server, {:set_announcement_callback, callback})
  end

  @doc """
  Gets the current state (for debugging/testing).
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Checks if announcements should be made.
  """
  def should_announce?(user_preferences_pid_or_name \\ nil) do
    # If user preferences provided, check if announcements are enabled
    case user_preferences_pid_or_name do
      nil -> true  # Default to allowing announcements
      pid when is_pid(pid) ->
        # Try to check user preferences, default to true if unavailable
        try do
          GenServer.call(pid, :get_silence_announcements, 1000)
          |> case do
            {:ok, silence} -> not silence
            _ -> true
          end
        catch
          :exit, _ -> true
        end
      name when is_atom(name) ->
        case Process.whereis(name) do
          nil -> true
          pid -> should_announce?(pid)
        end
      _ -> true
    end
  end

  @doc """
  Handles focus change events.
  """
  def handle_focus_change(server \\ __MODULE__, old_focus, new_focus) do
    GenServer.cast(server, {:handle_focus_change, old_focus, new_focus})
  end

  @doc """
  Gets an option value.
  """
  def get_option(key, default \\ nil) do
    get_option(__MODULE__, key, default)
  end

  def get_option(server, key, default) do
    case GenServer.call(server, {:get_preference, key}) do
      nil -> default
      value -> value
    end
  end

  @doc """
  Sets an option value.
  """
  def set_option(key, value) do
    set_option(__MODULE__, key, value)
  end

  def set_option(server, key, value) do
    GenServer.call(server, {:set_preference, key, value})
  end

  @doc """
  Gets a component hint.
  """
  def get_component_hint(component_id, hint_level \\ :normal) do
    get_component_hint(__MODULE__, component_id, hint_level)
  end

  def get_component_hint(server, component_id, _hint_level) do
    case GenServer.call(server, {:get_metadata, component_id}) do
      nil -> nil
      metadata -> Map.get(metadata, :hint)
    end
  end

  @doc """
  Registers component style.
  """
  def register_component_style(component_type, style) do
    register_component_style(__MODULE__, component_type, style)
  end

  def register_component_style(server, component_type, style) do
    GenServer.call(server, {:register_component_style, component_type, style})
  end

  @doc """
  Gets component style.
  """
  def get_component_style(component_type) do
    get_component_style(__MODULE__, component_type)
  end

  def get_component_style(server, component_type) do
    GenServer.call(server, {:get_component_style, component_type})
  end

  @doc """
  Unregisters component style.
  """
  def unregister_component_style(component_type) do
    unregister_component_style(__MODULE__, component_type)
  end

  def unregister_component_style(server, component_type) do
    GenServer.call(server, {:unregister_component_style, component_type})
  end

  @doc """
  Unregisters element metadata.
  """
  def unregister_element_metadata(element_id) do
    unregister_element_metadata(__MODULE__, element_id)
  end

  def unregister_element_metadata(server, element_id) do
    GenServer.call(server, {:remove_metadata, element_id})
  end

  @doc """
  Gets focus history.
  """
  def get_focus_history do
    get_focus_history(__MODULE__)
  end

  def get_focus_history(server) do
    GenServer.call(server, :get_focus_history)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:enable, options, user_preferences_pid}, _from, state) do
    preferences = merge_preferences(state.preferences, options)

    new_state = %{
      state
      | enabled: true,
        preferences: preferences,
        user_preferences_pid: user_preferences_pid
    }

    # Register event handlers
    register_event_handlers()

    # Dispatch accessibility enabled event
    EventManager.dispatch({:accessibility_enabled, preferences})

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:disable, _from, state) do
    new_state = %{state | enabled: false}

    # Unregister event handlers
    unregister_event_handlers()

    # Dispatch accessibility disabled event
    EventManager.dispatch(:accessibility_disabled)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:is_enabled, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl GenServer
  def handle_call({:set_preference, key, value}, _from, state) do
    new_preferences = Map.put(state.preferences, key, value)
    new_state = %{state | preferences: new_preferences}

    # Dispatch preference change event
    EventManager.dispatch({:accessibility_preference_changed, key, value})

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_preference, key}, _from, state) do
    value = Map.get(state.preferences, key, false)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:get_preferences, _from, state) do
    {:reply, state.preferences, state}
  end

  @impl GenServer
  def handle_call({:announce_sync, message, opts}, _from, state) do
    new_state = process_announcement(state, message, opts)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_metadata, component_id, metadata}, _from, state) do
    new_metadata = Map.put(state.metadata, component_id, metadata)
    new_state = %{state | metadata: new_metadata}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_metadata, component_id}, _from, state) do
    metadata = Map.get(state.metadata, component_id)
    {:reply, metadata, state}
  end

  @impl GenServer
  def handle_call({:remove_metadata, component_id}, _from, state) do
    new_metadata = Map.delete(state.metadata, component_id)
    new_state = %{state | metadata: new_metadata}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_announcement_history, limit}, _from, state) do
    history = get_limited_history(state.announcements.history, limit)

    {:reply, history, state}
  end

  @impl GenServer
  def handle_call(:clear_announcement_history, _from, state) do
    new_announcements = %{state.announcements | history: []}
    new_state = %{state | announcements: new_announcements}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_announcement_callback, callback}, _from, state) do
    new_state = %{state | announcement_callback: callback}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call(:get_next_announcement, _from, state) do
    case state.announcements.queue do
      [] -> {:reply, nil, state}
      [announcement | rest] ->
        new_announcements = %{state.announcements | queue: rest}
        new_state = %{state | announcements: new_announcements}
        {:reply, announcement, new_state}
    end
  end

  @impl GenServer
  def handle_call(:clear_all_announcements, _from, state) do
    new_announcements = %{state.announcements | queue: []}
    new_state = %{state | announcements: new_announcements}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_metadata, element_id, metadata}, _from, state) do
    new_metadata = Map.put(state.metadata, element_id, metadata)
    new_state = %{state | metadata: new_metadata}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_component_style, component_type, style}, _from, state) do
    # Store component styles in metadata with a special key
    style_key = {:component_style, component_type}
    new_metadata = Map.put(state.metadata, style_key, style)
    new_state = %{state | metadata: new_metadata}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_component_style, component_type}, _from, state) do
    style_key = {:component_style, component_type}
    style = Map.get(state.metadata, style_key)
    {:reply, style, state}
  end

  @impl GenServer
  def handle_call({:unregister_component_style, component_type}, _from, state) do
    style_key = {:component_style, component_type}
    new_metadata = Map.delete(state.metadata, style_key)
    new_state = %{state | metadata: new_metadata}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_focus_history, _from, state) do
    # Return focus history from metadata or empty list
    focus_history = Map.get(state.metadata, :focus_history, [])
    {:reply, focus_history, state}
  end

  @impl GenServer
  def handle_cast({:announce, message, opts}, state) do
    new_state = process_announcement(state, message, opts)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:handle_focus_change, _old_focus, new_focus}, state) do
    handle_focus_change_with_state(state, new_focus)
  end

  # Private Helper Functions

  defp get_limited_history(history, nil), do: history
  defp get_limited_history(history, limit), do: Enum.take(history, limit)

  defp handle_focus_change_with_state(state, new_focus) do
    handle_focus_announcement(state.enabled && state.preferences.screen_reader, state, new_focus)
  end

  defp handle_focus_announcement(false, state, _new_focus), do: {:noreply, state}
  defp handle_focus_announcement(true, state, new_focus) do
    # Get metadata for the new focus
    metadata = Map.get(state.metadata, new_focus, %{})

    # Create announcement based on metadata
    announcement = create_focus_announcement(new_focus, metadata)

    # Announce the focus change
    new_state = process_announcement(state, announcement, priority: :high)
    {:noreply, new_state}
  end

  defp should_process_announcement?(state) do
    state.enabled && state.preferences.screen_reader && !state.preferences.silence_announcements
  end

  defp handle_announcement_delivery(true, _queue, announcement, callback) do
    # Immediate announcement when interrupt is true
    deliver_announcement(announcement, callback)
  end
  defp handle_announcement_delivery(false, queue, announcement, callback) do
    handle_queue_delivery(Enum.empty?(queue), queue, announcement, callback)
  end

  defp handle_queue_delivery(true, _queue, announcement, callback) do
    # Immediate announcement when queue is empty
    deliver_announcement(announcement, callback)
  end
  defp handle_queue_delivery(false, queue, announcement, callback) do
    # Queue announcement based on priority
    new_queue = insert_by_priority(queue, announcement)
    process_queue(new_queue, callback)
  end

  defp call_callback_if_present(nil, _message), do: :ok
  defp call_callback_if_present(callback, message), do: callback.(message)

  defp merge_preferences(current, options) do
    options_map = Enum.into(options, %{})
    Map.merge(current, options_map)
  end

  defp register_event_handlers do
    EventManager.register_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change_event
    )

    EventManager.register_handler(
      :preference_changed,
      __MODULE__,
      :handle_preference_changed_event
    )

    EventManager.register_handler(
      :theme_changed,
      __MODULE__,
      :handle_theme_changed_event
    )
  end

  defp unregister_event_handlers do
    EventManager.unregister_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change_event
    )

    EventManager.unregister_handler(
      :preference_changed,
      __MODULE__,
      :handle_preference_changed_event
    )

    EventManager.unregister_handler(
      :theme_changed,
      __MODULE__,
      :handle_theme_changed_event
    )
  end

  defp process_announcement(state, message, opts) do
    case should_process_announcement?(state) do
      true ->
      priority = Keyword.get(opts, :priority, :medium)
      interrupt = Keyword.get(opts, :interrupt, false)

      announcement = %{
        message: message,
        priority: priority,
        timestamp: DateTime.utc_now(),
        opts: opts
      }

      # Add to history
      new_history = [announcement | state.announcements.history]
      limited_history = Enum.take(new_history, state.announcements.max_history)

      # Process announcement
      handle_announcement_delivery(interrupt, state.announcements.queue, announcement, state.announcement_callback)

      new_announcements = %{
        state.announcements
        | history: limited_history
      }

      %{state | announcements: new_announcements}
      false ->
        state
    end
  end

  defp deliver_announcement(announcement, callback) do
    # Call the callback if provided
    call_callback_if_present(callback, announcement.message)

    # Dispatch event for other systems
    EventManager.dispatch({:screen_reader_announcement, announcement.message})
  end

  defp insert_by_priority(queue, announcement) do
    Enum.sort_by([announcement | queue], fn a ->
      case a.priority do
        :high -> 1
        :medium -> 2
        :low -> 3
      end
    end)
  end

  defp process_queue([], _callback), do: :ok

  defp process_queue([announcement | _rest], callback) do
    deliver_announcement(announcement, callback)
  end

  defp create_focus_announcement(component_id, metadata) do
    label = Map.get(metadata, :label, component_id)
    role = Map.get(metadata, :role, "element")
    description = Map.get(metadata, :description, "")

    parts = [label, role]
    parts = case description != "" do
      true -> parts ++ [description]
      false -> parts
    end

    Enum.join(parts, ", ")
  end

  # Event handler callbacks (called by EventManager)
  def handle_focus_change_event({:focus_change, old_focus, new_focus}) do
    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_preference_changed_event({:preference_changed, _key, _value}) do
    # Handle preference changes from other systems
    :ok
  end

  def handle_theme_changed_event({:theme_changed, _theme}) do
    # Handle theme changes that might affect accessibility
    :ok
  end
end
