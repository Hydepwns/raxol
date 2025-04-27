defmodule Raxol.Core.UserPreferences do
  @moduledoc """
  Manages user preferences for the Raxol application.

  Acts as a GenServer holding the preferences state and handles persistence.
  """

  use GenServer
  require Logger

  # Use the new Persistence module
  alias Raxol.Core.Preferences.Persistence

  @save_delay_ms 1000 # Delay in ms before saving after a change

  # --- Data Structure ---
  defmodule State do
    @moduledoc "Internal state for the UserPreferences GenServer."
    defstruct [
      preferences: %{},
      save_timer: nil # Stores ref for the save timer
    ]
  end

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a user preference value by key path.

  Accepts a single key or a list of keys for nested access.

  ## Examples
      UserPreferences.get(:theme) #=> "dark"
      UserPreferences.get([:accessibility, :high_contrast]) #=> true
  """
  def get(key_or_path) do
    GenServer.call(__MODULE__, {:get, key_or_path})
  end

  @doc """
  Sets a user preference value by key path.

  Accepts a single key or a list of keys for nested access.
  Triggers an automatic save after a short delay.

  ## Examples
      UserPreferences.set(:theme, "light")
      UserPreferences.set([:accessibility, :high_contrast], false)
  """
  @spec set(atom | list(atom), any()) :: :ok
  def set(key_or_path, value) do
    GenServer.cast(__MODULE__, {:set, key_or_path, value})
    :ok # Cast is async, reply immediately
  end

  @doc """
  Forces an immediate save of the current preferences.
  """
  def save! do
    GenServer.call(__MODULE__, :save_now)
  end

  @doc """
  Retrieves the entire preferences map.
  """
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    preferences =
      case Persistence.load() do
        {:ok, loaded_prefs} ->
          Logger.info("User preferences loaded successfully.")
          # Deep merge with defaults to ensure all keys exist
          deep_merge(default_preferences(), loaded_prefs)
        {:error, :file_not_found} ->
          Logger.info("No preferences file found, using defaults.")
          default_preferences()
        {:error, reason} ->
          Logger.warning("Failed to load preferences (#{reason}), using defaults.")
          default_preferences()
      end
    {:ok, %State{preferences: preferences}}
  end

  @impl true
  def handle_call({:get, key_or_path}, _from, state) do
    value = get_in(state.preferences, List.wrap(key_or_path))
    {:reply, value, state}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
     {:reply, state.preferences, state}
  end

  # Handle immediate save request
  @impl true
  def handle_call(:save_now, _from, state) do
    # Cancel any pending delayed save
    cancel_save_timer(state.save_timer)

    case Persistence.save(state.preferences) do
      :ok ->
        Logger.debug("User preferences saved immediately.")
        {:reply, :ok, %{state | save_timer: nil}}
      {:error, reason} ->
        Logger.error("Failed to save preferences immediately: #{inspect reason}")
        {:reply, {:error, reason}, %{state | save_timer: nil}}
    end
  end

  # Handle setting a value (using cast for async operation)
  @impl true
  def handle_cast({:set, key_or_path, value}, state) do
    keys = List.wrap(key_or_path)
    current_value = get_in(state.preferences, keys)

    if current_value != value do
      new_preferences = put_in(state.preferences, keys, value)
      Logger.debug("Preference updated: #{inspect keys} = #{inspect value}")
      new_state = %{state | preferences: new_preferences}
      # Schedule a save after a delay
      {:noreply, schedule_save(new_state)}
    else
      {:noreply, state} # Value didn't change, do nothing
    end
  end

  # Handle the delayed save message
  @impl true
  def handle_info(:perform_delayed_save, state) do
    case Persistence.save(state.preferences) do
      :ok -> Logger.debug("User preferences saved after delay.")
      {:error, reason} -> Logger.error("Failed to save preferences after delay: #{inspect reason}")
    end
    # Reset the timer ref in state
    {:noreply, %{state | save_timer: nil}}
  end

  # --- Internal Helpers ---

  defp default_preferences do
    %{
      theme: Raxol.UI.Theming.Theme.default_theme().name,
      terminal: Raxol.Terminal.Config.Defaults.generate_default_config(),
      accessibility: %{
        enabled: true,
        screen_reader: true,
        high_contrast: false,
        reduced_motion: false,
        keyboard_focus: true,
        large_text: false,
        silence_announcements: false
      },
      keybindings: %{
        # Default keybindings can be added here
      }
    }
  end

  # Basic deep merge for nested maps
  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn _key, val1, val2 ->
      if is_map(val1) and is_map(val2) do
        deep_merge(val1, val2)
      else
        val2 # Value from map2 overrides map1
      end
    end)
  end

  # Schedules a save operation, cancelling any existing timer
  defp schedule_save(state = %State{save_timer: existing_timer}) do
    cancel_save_timer(existing_timer)
    new_timer = Process.send_after(self(), :perform_delayed_save, @save_delay_ms)
    %{state | save_timer: new_timer}
  end

  # Cancels a Process.send_after timer if it exists
  defp cancel_save_timer(timer_ref) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
  end

end
