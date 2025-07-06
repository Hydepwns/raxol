defmodule Raxol.Core.UserPreferences do
  import Raxol.Guards

  @moduledoc """
  Manages user preferences for the terminal emulator.

  Acts as a GenServer holding the preferences state and handles persistence.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  # Use the new Persistence module
  alias Raxol.Core.Preferences.Persistence

  # Delay in ms before saving after a change
  @save_delay_ms 1000

  # --- Data Structure ---
  defmodule State do
    @moduledoc "Internal state for the UserPreferences GenServer."
    defstruct preferences: %{},
              # Stores ref for the save timer
              save_timer: nil
  end

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @impl GenServer
  def init(opts) do
    preferences =
      if Keyword.get(opts, :test_mode?, false) do
        Raxol.Core.Runtime.Log.info(
          "UserPreferences starting in test mode, using defaults only."
        )

        default_preferences()
      else
        case Persistence.load() do
          {:ok, loaded_prefs} ->
            Raxol.Core.Runtime.Log.info("User preferences loaded successfully.")
            # Deep merge with defaults to ensure all keys exist
            deep_merge(default_preferences(), loaded_prefs)

          {:error, :file_not_found} ->
            Raxol.Core.Runtime.Log.info(
              "No preferences file found, using defaults."
            )

            default_preferences()

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to load preferences (#{reason}), using defaults."
            )

            default_preferences()
        end
      end

    {:ok, %State{preferences: preferences}}
  end

  def get(key_or_path, pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, {:get, key_or_path})
  end

  def set(key_or_path, value, pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, {:set, key_or_path, value})
  end

  def save!(pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, :save_now)
  end

  def get_all(pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, :get_all)
  end

  def set_preferences(preferences, pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, {:set_preferences, preferences})
  end

  def reset_to_defaults_for_test!(pid_or_name \\ __MODULE__) do
    GenServer.call(pid_or_name, :reset_to_defaults)
  end

  @impl GenServer
  def handle_call({:get, key_or_path}, _from, state) do
    path = normalize_path(key_or_path)
    value = get_in(state.preferences, path)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call({:set, key_or_path, value}, _from, state) do
    path = normalize_path(key_or_path)
    current_value = get_in(state.preferences, path)

    if current_value != value do
      new_preferences = put_in(state.preferences, path, value)

      Raxol.Core.Runtime.Log.debug(
        "Preference updated: #{inspect(path)} = #{inspect(value)}"
      )

      new_state = %{state | preferences: new_preferences}

      # Send preferences_applied message for test synchronization
      send(self(), {:preferences_applied})

      # Schedule a save after a delay
      {:reply, :ok, schedule_save(new_state)}
    else
      # Value didn't change, do nothing, but still reply :ok
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call(:get_all, _from, state) do
    {:reply, state.preferences, state}
  end

  @impl GenServer
  def handle_call({:set_preferences, preferences}, _from, state) do
    new_preferences = deep_merge(state.preferences, preferences)

    Raxol.Core.Runtime.Log.debug(
      "All preferences updated: #{inspect(preferences)}"
    )

    new_state = %{state | preferences: new_preferences}

    # Send preferences_applied message for test synchronization
    send(self(), {:preferences_applied})

    # Schedule a save after a delay
    {:reply, :ok, schedule_save(new_state)}
  end

  @impl GenServer
  def handle_call(:save_now, _from, state) do
    # Cancel any pending delayed save
    cancel_save_timer(state.save_timer)

    case Persistence.save(state.preferences) do
      :ok ->
        Raxol.Core.Runtime.Log.debug("User preferences saved immediately.")
        {:reply, :ok, %{state | save_timer: nil}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to save preferences immediately: #{inspect(reason)}"
        )

        {:reply, {:error, reason}, %{state | save_timer: nil}}
    end
  end

  @impl GenServer
  def handle_call(:reset_to_defaults, _from, state) do
    Raxol.Core.Runtime.Log.info(
      "UserPreferences resetting to defaults for test."
    )

    new_preferences = default_preferences()
    # Cancel any pending save timer as we are resetting
    new_state = %{
      state
      | preferences: new_preferences,
        save_timer: cancel_save_timer(state.save_timer)
    }

    {:reply, :ok, new_state}
  end

  # Schedules a save operation, cancelling any existing timer
  defp schedule_save(state = %State{save_timer: existing_timer}) do
    cancel_save_timer(existing_timer)

    timer_id = System.unique_integer([:positive])

    Process.send_after(
      self(),
      {:perform_delayed_save, timer_id},
      @save_delay_ms
    )

    %{state | save_timer: timer_id}
  end

  # Cancels a Process.send_after timer if it exists
  defp cancel_save_timer(timer_id) when integer?(timer_id) do
    # We can't actually cancel the timer, but we can ignore its message
    # when it arrives by checking the timer_id
    :ok
  end

  defp cancel_save_timer(_), do: :ok

  # Handle the delayed save message
  @impl GenServer
  def handle_info({:perform_delayed_save, timer_id}, state) do
    if timer_id == state.save_timer do
      case Persistence.save(state.preferences) do
        :ok ->
          Raxol.Core.Runtime.Log.debug("User preferences saved after delay.")

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error(
            "Failed to save preferences after delay: #{inspect(reason)}"
          )
      end

      # Reset the timer id in state
      {:noreply, %{state | save_timer: nil}}
    else
      # Ignore stale timer messages
      {:noreply, state}
    end
  end

  # Catch-all for unexpected messages
  @impl GenServer
  def handle_info(msg, state) do
    # Handle the preferences_applied message specially
    case msg do
      {:preferences_applied} ->
        # This is expected, don't log it as a warning
        {:noreply, state}

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(inspect(msg), %{})
        {:noreply, state}
    end
  end

  # --- Internal Helpers ---

  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn _key, val1, val2 ->
      if map?(val1) and map?(val2) do
        deep_merge(val1, val2)
      else
        # Value from map2 overrides map1
        val2
      end
    end)
  end

  # Helper to normalize key paths to a list of atoms
  defp normalize_path(path) when atom?(path), do: [path]
  # Assume list is already correct
  defp normalize_path(path) when list?(path), do: path

  defp normalize_path(path) when binary?(path) do
    String.split(path, ".")
    # Use existing_atom for safety
    |> Enum.map(&String.to_existing_atom/1)
  catch
    ArgumentError ->
      Raxol.Core.Runtime.Log.error(
        "Invalid preference path string: #{inspect(path)} - cannot convert segments to atoms."
      )

      # Return empty path on error to avoid crash, get_in/put_in will likely fail gracefully
      []
  end

  @doc """
  Returns the current theme id as an atom, defaulting to :default if not set or invalid.
  """
  def get_theme_id(pid_or_name \\ __MODULE__) do
    theme = get([:theme, :active_id], pid_or_name) || get(:theme, pid_or_name)

    cond do
      atom?(theme) ->
        theme

      binary?(theme) ->
        try do
          String.to_existing_atom(theme)
        rescue
          ArgumentError -> :default
        end

      true ->
        :default
    end
  end

  @doc """
  Returns the default preferences map.
  This includes default values for theme, terminal configuration, accessibility settings,
  and keybindings.
  """
  def default_preferences do
    %{
      theme: %{
        active_id: :default
      },
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
      keybindings:
        %{
          # Add default keybindings here
        }
    }
  end
end
