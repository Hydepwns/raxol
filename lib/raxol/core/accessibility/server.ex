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
  Handles focus change events.
  """
  def handle_focus_change(server \\ __MODULE__, old_focus, new_focus) do
    GenServer.cast(server, {:handle_focus_change, old_focus, new_focus})
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
    history =
      if limit do
        Enum.take(state.announcements.history, limit)
      else
        state.announcements.history
      end

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
  def handle_cast({:announce, message, opts}, state) do
    new_state = process_announcement(state, message, opts)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:handle_focus_change, old_focus, new_focus}, state) do
    if state.enabled && state.preferences.screen_reader do
      # Get metadata for the new focus
      metadata = Map.get(state.metadata, new_focus, %{})

      # Create announcement based on metadata
      announcement = create_focus_announcement(new_focus, metadata)

      # Announce the focus change
      new_state = process_announcement(state, announcement, priority: :high)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Private Helper Functions

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
    if state.enabled && state.preferences.screen_reader &&
         !state.preferences.silence_announcements do
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
      if interrupt || Enum.empty?(state.announcements.queue) do
        # Immediate announcement
        deliver_announcement(announcement, state.announcement_callback)
      else
        # Queue announcement based on priority
        new_queue = insert_by_priority(state.announcements.queue, announcement)
        process_queue(new_queue, state.announcement_callback)
      end

      new_announcements = %{
        state.announcements
        | history: limited_history
      }

      %{state | announcements: new_announcements}
    else
      state
    end
  end

  defp deliver_announcement(announcement, callback) do
    # Call the callback if provided
    if callback do
      callback.(announcement.message)
    end

    # Dispatch event for other systems
    EventManager.dispatch({:screen_reader_announcement, announcement.message})
  end

  defp insert_by_priority(queue, announcement) do
    priority_value =
      case announcement.priority do
        :high -> 1
        :medium -> 2
        :low -> 3
      end

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
    parts = if description != "", do: parts ++ [description], else: parts

    Enum.join(parts, ", ")
  end

  # Event handler callbacks (called by EventManager)
  def handle_focus_change_event({:focus_change, old_focus, new_focus}) do
    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_preference_changed_event({:preference_changed, key, value}) do
    # Handle preference changes from other systems
    :ok
  end

  def handle_theme_changed_event({:theme_changed, theme}) do
    # Handle theme changes that might affect accessibility
    :ok
  end
end
