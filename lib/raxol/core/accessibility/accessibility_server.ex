defmodule Raxol.Core.Accessibility.AccessibilityServer do
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

  ## Sub-modules
  - `AnnouncementQueue`  -- queue, priority, history, delivery
  - `PreferenceManager`  -- preference merge/sync/notify
  - `MetadataRegistry`   -- element/component metadata and style registration
  - `FocusManager`       -- focus tracking, history, and focus announcements
  """

  use Raxol.Core.Behaviours.BaseManager
  require Logger
  alias Raxol.Core.Accessibility.{AnnouncementQueue, FocusManager, MetadataRegistry, PreferenceManager}
  alias Raxol.Core.Events.EventManager
  alias Raxol.Core.Runtime.Log

  @compile {:no_warn_undefined, [Raxol.Core.Accessibility.MetadataRegistry, Raxol.Core.Accessibility.FocusManager]}

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

  @doc "Enables accessibility features with the given options."
  @spec enable(GenServer.server(), keyword(), atom() | pid() | nil) :: :ok
  def enable(server \\ __MODULE__, options \\ [], user_preferences_pid \\ nil) do
    GenServer.call(server, {:enable, options, user_preferences_pid})
  end

  @doc "Disables accessibility features."
  @spec disable(GenServer.server()) :: :ok
  def disable(server \\ __MODULE__) do
    GenServer.call(server, :disable)
  end

  @doc "Resets the accessibility server to its default state (for test isolation)."
  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @doc "Checks if accessibility is enabled."
  @spec enabled?(GenServer.server()) :: boolean()
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
  @spec announce(GenServer.server(), String.t(), keyword()) :: :ok
  def announce(server \\ __MODULE__, message, opts \\ []) do
    GenServer.cast(server, {:announce, message, opts})
  end

  @doc "Announces with synchronous confirmation."
  @spec announce_sync(GenServer.server(), String.t(), keyword()) :: :ok
  def announce_sync(server \\ __MODULE__, message, opts \\ []) do
    GenServer.call(server, {:announce_sync, message, opts})
  end

  @doc "Sets high contrast mode."
  @spec set_high_contrast(GenServer.server(), boolean()) :: :ok
  def set_high_contrast(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :high_contrast, enabled})
  end

  @doc "Gets high contrast mode status."
  @spec high_contrast?(GenServer.server()) :: boolean()
  def high_contrast?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :high_contrast})
  end

  @doc "Sets reduced motion mode."
  @spec set_reduced_motion(GenServer.server(), boolean()) :: :ok
  def set_reduced_motion(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :reduced_motion, enabled})
  end

  @doc "Gets reduced motion mode status."
  @spec reduced_motion?(GenServer.server()) :: boolean()
  def reduced_motion?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :reduced_motion})
  end

  @doc "Sets large text mode."
  @spec set_large_text(GenServer.server(), boolean()) :: :ok
  def set_large_text(server \\ __MODULE__, enabled) when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :large_text, enabled})
  end

  def set_large_text_with_prefs(
        server \\ __MODULE__,
        enabled,
        user_preferences_pid
      )
      when is_boolean(enabled) do
    GenServer.call(
      server,
      {:set_preference_with_prefs, :large_text, enabled, user_preferences_pid}
    )
  end

  @doc "Gets large text mode status."
  @spec large_text?(GenServer.server()) :: boolean()
  def large_text?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :large_text})
  end

  @doc "Sets screen reader support."
  @spec set_screen_reader(GenServer.server(), boolean()) :: :ok
  def set_screen_reader(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :screen_reader, enabled})
  end

  @doc "Gets screen reader support status."
  @spec screen_reader?(GenServer.server()) :: boolean()
  def screen_reader?(server \\ __MODULE__) do
    GenServer.call(server, {:get_preference, :screen_reader})
  end

  @doc "Sets keyboard focus indicators."
  @spec set_keyboard_focus(GenServer.server(), boolean()) :: :ok
  def set_keyboard_focus(server \\ __MODULE__, enabled)
      when is_boolean(enabled) do
    GenServer.call(server, {:set_preference, :keyboard_focus, enabled})
  end

  @doc "Sets accessibility metadata for a component."
  def set_metadata(server \\ __MODULE__, component_id, metadata) do
    GenServer.call(server, {:set_metadata, component_id, metadata})
  end

  @doc "Registers element metadata for a component."
  def register_element_metadata(element_id, metadata) do
    register_element_metadata(__MODULE__, element_id, metadata)
  end

  def register_element_metadata(server, element_id, metadata) do
    GenServer.call(server, {:register_metadata, element_id, metadata})
  end

  @doc "Gets element metadata for a component."
  def get_element_metadata(element_id) do
    get_element_metadata(__MODULE__, element_id)
  end

  def get_element_metadata(server, element_id) do
    GenServer.call(server, {:get_metadata, element_id})
  end

  @doc "Gets accessibility metadata for a component."
  def get_metadata(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:get_metadata, component_id})
  end

  @doc "Removes metadata for a component."
  def remove_metadata(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:remove_metadata, component_id})
  end

  @doc "Gets all current preferences."
  @spec get_preferences(GenServer.server()) :: map()
  def get_preferences(server \\ __MODULE__) do
    GenServer.call(server, :get_preferences)
  end

  @doc "Adds an announcement to the queue."
  def add_announcement(announcement, user_preferences_pid_or_name \\ nil) do
    add_announcement(__MODULE__, announcement, user_preferences_pid_or_name)
  end

  def add_announcement(server, announcement, _user_preferences_pid_or_name) do
    GenServer.cast(server, {:announce, announcement, []})
  end

  @doc "Gets the next announcement from the queue."
  def get_next_announcement(user_preferences_pid_or_name \\ nil) do
    get_next_announcement(__MODULE__, user_preferences_pid_or_name)
  end

  def get_next_announcement(server, _user_preferences_pid_or_name) do
    GenServer.call(server, :get_next_announcement)
  end

  @doc "Clears all announcements from the queue."
  def clear_all_announcements do
    clear_all_announcements(__MODULE__)
  end

  def clear_all_announcements(server) do
    GenServer.call(server, :clear_all_announcements)
  end

  @doc "Clears announcements for a specific user."
  def clear_announcements(user_preferences_pid_or_name) do
    clear_announcements(__MODULE__, user_preferences_pid_or_name)
  end

  def clear_announcements(server, _user_preferences_pid_or_name) do
    GenServer.call(server, :clear_all_announcements)
  end

  @doc "Gets announcement history."
  def get_announcement_history(server \\ __MODULE__, limit \\ nil) do
    GenServer.call(server, {:get_announcement_history, limit})
  end

  @doc "Clears announcement history."
  def clear_announcement_history(server \\ __MODULE__) do
    GenServer.call(server, :clear_announcement_history)
  end

  @doc "Sets the announcement callback function."
  def set_announcement_callback(server \\ __MODULE__, callback)
      when is_function(callback, 1) do
    GenServer.call(server, {:set_announcement_callback, callback})
  end

  @doc "Gets the current state (for debugging/testing)."
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  @doc "Checks if announcements should be made."
  @spec should_announce?(atom() | pid() | nil) :: boolean()
  def should_announce?(user_preferences_pid_or_name \\ nil) do
    case user_preferences_pid_or_name do
      nil ->
        true

      prefs ->
        try do
          screen_reader =
            Raxol.Core.UserPreferences.get(
              [:accessibility, :screen_reader],
              prefs
            )

          silence =
            Raxol.Core.UserPreferences.get(
              [:accessibility, :silence_announcements],
              prefs
            )

          screen_reader != false and silence != true
        rescue
          _ -> true
        catch
          :exit, _ -> true
        end
    end
  end

  @doc "Handles focus change events."
  def handle_focus_change(server \\ __MODULE__, old_focus, new_focus) do
    GenServer.cast(server, {:handle_focus_change, old_focus, new_focus})
  end

  @doc "Gets an option value."
  def get_option(key, default \\ nil) do
    get_option(__MODULE__, key, default)
  end

  def get_option(server, key, default) do
    case GenServer.call(server, {:get_preference, key}) do
      nil -> default
      value -> value
    end
  end

  @doc "Sets an option value."
  def set_option(key, value) do
    set_option(__MODULE__, key, value)
  end

  def set_option(server, key, value) do
    GenServer.call(server, {:set_preference, key, value})
  end

  @doc "Gets a component hint."
  def get_component_hint(component_id, hint_level \\ :normal) do
    get_component_hint(__MODULE__, component_id, hint_level)
  end

  def get_component_hint(server, component_id, _hint_level) do
    case GenServer.call(server, {:get_metadata, component_id}) do
      nil -> nil
      metadata -> Map.get(metadata, :hint)
    end
  end

  @doc "Registers component style."
  def register_component_style(component_type, style) do
    register_component_style(__MODULE__, component_type, style)
  end

  def register_component_style(server, component_type, style) do
    GenServer.call(server, {:register_component_style, component_type, style})
  end

  @doc "Gets component style."
  def get_component_style(component_type) do
    get_component_style(__MODULE__, component_type)
  end

  def get_component_style(server, component_type) do
    GenServer.call(server, {:get_component_style, component_type})
  end

  @doc "Unregisters component style."
  def unregister_component_style(component_type) do
    unregister_component_style(__MODULE__, component_type)
  end

  def unregister_component_style(server, component_type) do
    GenServer.call(server, {:unregister_component_style, component_type})
  end

  @doc "Unregisters element metadata."
  def unregister_element_metadata(element_id) do
    unregister_element_metadata(__MODULE__, element_id)
  end

  def unregister_element_metadata(server, element_id) do
    GenServer.call(server, {:remove_metadata, element_id})
  end

  @doc "Gets focus history."
  def get_focus_history do
    get_focus_history(__MODULE__)
  end

  def get_focus_history(server) do
    GenServer.call(server, :get_focus_history)
  end

  # BaseManager Callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    initial_state = Keyword.get(opts, :initial_state, @default_state)
    {:ok, initial_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:enable, options, user_preferences_pid},
        _from,
        state
      ) do
    preferences = PreferenceManager.merge(state.preferences, options)

    new_state = %{
      state
      | enabled: true,
        preferences: preferences,
        user_preferences_pid: user_preferences_pid
    }

    case user_preferences_pid do
      nil -> :ok
      pid -> PreferenceManager.sync_all(preferences, pid)
    end

    register_event_handlers()

    if Process.whereis(EventManager),
      do: EventManager.dispatch({:accessibility_enabled, preferences})

    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:disable, _from, state) do
    new_state = %{state | enabled: false}
    unregister_event_handlers()

    if Process.whereis(EventManager),
      do: EventManager.dispatch(:accessibility_disabled)

    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:reset, _from, _state) do
    unregister_event_handlers()
    {:reply, :ok, @default_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:is_enabled, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_preference, key, value}, _from, state) do
    new_preferences = Map.put(state.preferences, key, value)
    new_state = %{state | preferences: new_preferences}

    PreferenceManager.sync_one(key, value, state.user_preferences_pid)

    if Process.whereis(EventManager),
      do: EventManager.dispatch({:accessibility_preference_changed, key, value})

    PreferenceManager.maybe_notify_color_system(key, value)

    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:set_preference_with_prefs, key, value, user_preferences_pid},
        _from,
        state
      ) do
    new_preferences = Map.put(state.preferences, key, value)
    new_state = %{state | preferences: new_preferences}

    PreferenceManager.sync_one(key, value, user_preferences_pid)

    if Process.whereis(EventManager),
      do: EventManager.dispatch({:accessibility_preference_changed, key, value})

    PreferenceManager.maybe_notify_color_system(key, value)

    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_preference, key}, _from, state) do
    value =
      case key do
        :enabled -> state.enabled
        _ -> Map.get(state.preferences, key, false)
      end

    {:reply, value, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_preferences, _from, state) do
    {:reply, state.preferences, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:announce_sync, message, opts}, _from, state) do
    new_announcements = process_announcement(state, message, opts)
    new_state = %{state | announcements: new_announcements}
    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_metadata, component_id, metadata}, _from, state) do
    {:reply, :ok, MetadataRegistry.put_metadata(state, component_id, metadata)}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_metadata, component_id}, _from, state) do
    {:reply, MetadataRegistry.get_metadata(state, component_id), state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:remove_metadata, component_id}, _from, state) do
    {:reply, :ok, MetadataRegistry.remove_metadata(state, component_id)}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_announcement_history, limit}, _from, state) do
    history =
      AnnouncementQueue.limited_history(state.announcements.history, limit)

    {:reply, history, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:clear_announcement_history, _from, state) do
    new_state = %{state | announcements: %{state.announcements | history: []}}
    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_announcement_callback, callback}, _from, state) do
    {:reply, :ok, %{state | announcement_callback: callback}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_next_announcement, _from, state) do
    {message, new_announcements} = AnnouncementQueue.pop(state.announcements)
    {:reply, message, %{state | announcements: new_announcements}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:clear_all_announcements, _from, state) do
    new_state = %{state | announcements: %{state.announcements | queue: []}}
    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:register_metadata, element_id, metadata},
        _from,
        state
      ) do
    {:reply, :ok, MetadataRegistry.put_metadata(state, element_id, metadata)}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:register_component_style, component_type, style},
        _from,
        state
      ) do
    {:reply, :ok, MetadataRegistry.register_component_style(state, component_type, style)}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_component_style, component_type}, _from, state) do
    {:reply, MetadataRegistry.get_component_style(state, component_type), state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:unregister_component_style, component_type},
        _from,
        state
      ) do
    {:reply, :ok, MetadataRegistry.unregister_component_style(state, component_type)}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_focus_history, _from, state) do
    {:reply, FocusManager.get_focus_history(state), state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast(
        {:announce, %{message: message} = announcement, opts},
        state
      )
      when is_binary(message) do
    merged_opts =
      Keyword.merge(opts,
        priority: Map.get(announcement, :priority, :medium),
        interrupt: Map.get(announcement, :interrupt, false)
      )

    new_announcements = process_announcement(state, message, merged_opts)
    {:noreply, %{state | announcements: new_announcements}}
  end

  def handle_manager_cast({:announce, message, opts}, state)
      when is_binary(message) do
    new_announcements = process_announcement(state, message, opts)
    {:noreply, %{state | announcements: new_announcements}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:handle_focus_change, _old_focus, new_focus}, state) do
    if state.enabled && state.preferences.screen_reader do
      FocusManager.handle_focus_announcement(state, new_focus)
    else
      {:noreply, state}
    end
  end

  # Event handler callbacks (called by EventManager)

  def handle_focus_change_event(:focus_change) do
    Log.warning(
      "AccessibilityServer.handle_focus_change_event/1 called with just event type, this is a known issue with EventManager dispatch"
    )

    :ok
  end

  def handle_focus_change_event({:focus_change, old_focus, new_focus}) do
    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_focus_change_event(unexpected_arg) do
    Log.warning(
      "AccessibilityServer.handle_focus_change_event/1 called with unexpected argument: #{inspect(unexpected_arg)}"
    )

    :ok
  end

  def handle_focus_change_event(
        {:focus_change, old_focus, new_focus},
        _metadata
      ) do
    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_focus_change_event(event_type, event_data)
      when event_type == :focus_change do
    {old_focus, new_focus} =
      AnnouncementQueue.parse_focus_change_event_data(event_data)

    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_focus_change_event(old_focus, new_focus) do
    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_focus_change_event(_event_name, _measurements, metadata, _config)
      when is_map(metadata) do
    old_focus = Map.get(metadata, :old_focus, nil)
    new_focus = Map.get(metadata, :new_focus, nil)

    Log.debug(
      "AccessibilityServer telemetry handler called with metadata: #{inspect(metadata)}"
    )

    handle_focus_change(__MODULE__, old_focus, new_focus)
  end

  def handle_preference_changed_event({:preference_changed, _key, _value}),
    do: :ok

  def handle_theme_changed_event({:theme_changed, _theme}), do: :ok

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:preferences_applied, _name}, state) do
    {:noreply, state}
  end

  def handle_manager_info(msg, state) do
    Raxol.Core.Runtime.Log.error(
      "#{__MODULE__} received unexpected message in handle_info/2: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Private helpers

  defp process_announcement(state, message, opts) do
    AnnouncementQueue.process(
      state.announcements,
      message,
      opts,
      state.announcement_callback,
      state.enabled,
      state.preferences.screen_reader,
      state.preferences.silence_announcements
    )
  end

  defp register_event_handlers do
    FocusManager.register_event_handlers(__MODULE__)
  end

  defp unregister_event_handlers do
    FocusManager.unregister_event_handlers(__MODULE__)
  end
end
