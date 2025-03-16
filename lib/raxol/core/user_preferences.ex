defmodule Raxol.Core.UserPreferences do
  @moduledoc """
  User preferences management for Raxol terminal UI applications.
  
  This module provides a persistent storage system for user preferences,
  focusing particularly on accessibility features, color themes, and
  UI customization options.
  
  Preferences are stored persistently between application sessions, and
  apply consistently across all components. The module includes a comprehensive
  API for retrieving, updating, and applying preferences.
  
  ## Features
  
  - Persistent storage of user preferences
  - Support for accessibility settings
  - Theme and color preferences
  - Keyboard shortcut customization
  - Focus and navigation preferences
  - Integration with all UI components
  
  ## Usage
  
  ```elixir
  # Initialize preferences system
  UserPreferences.init()
  
  # Set preferences
  UserPreferences.set(:high_contrast, true)
  UserPreferences.set(:theme, :dark)
  
  # Get preferences
  high_contrast = UserPreferences.get(:high_contrast)
  theme = UserPreferences.get(:theme)
  
  # Save preferences to storage
  UserPreferences.save()
  
  # Load preferences from storage
  UserPreferences.load()
  ```
  """
  
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility
  alias Raxol.Style.Colors.System, as: ColorSystem
  
  @default_prefs %{
    # Accessibility preferences
    high_contrast: false,
    reduced_motion: false,
    large_text: false,
    screen_reader: false,
    keyboard_focus: true,
    
    # Theme preferences
    theme: :standard,
    accent_color: "#4B9CD3",
    custom_colors: %{},
    
    # Focus and navigation preferences
    focus_highlight_style: :solid,
    focus_highlight_color: :blue,
    focus_animation: :pulse,
    tab_navigation_enabled: true,
    
    # Keyboard shortcut preferences
    custom_shortcuts: %{},
    shortcut_help_level: :basic
  }
  
  @storage_file "user_preferences.dat"
  
  @doc """
  Initialize the user preferences system.
  
  This loads saved preferences if they exist, or sets up defaults.
  It also registers necessary event handlers and applies the loaded preferences.
  
  ## Options
  
  * `:storage_dir` - Directory to store preferences (default: "./prefs")
  * `:auto_save` - Whether to automatically save when preferences change (default: true)
  
  ## Examples
  
      iex> UserPreferences.init()
      :ok
      
      iex> UserPreferences.init(storage_dir: "/tmp/app_prefs")
      :ok
  """
  def init(opts \\ []) do
    # Get storage directory
    storage_dir = Keyword.get(opts, :storage_dir, "./prefs")
    
    # Get auto save setting
    auto_save = Keyword.get(opts, :auto_save, true)
    
    # Store settings
    Process.put(:user_preferences_settings, %{
      storage_dir: storage_dir,
      auto_save: auto_save
    })
    
    # Create storage directory if it doesn't exist
    File.mkdir_p!(storage_dir)
    
    # Initialize preferences with defaults
    Process.put(:user_preferences, @default_prefs)
    
    # Try to load saved preferences
    load()
    
    # Register event handlers
    EventManager.register_handler(:user_preference_changed, __MODULE__, :handle_preference_changed)
    
    # Apply loaded preferences
    apply_all_preferences()
    
    :ok
  end
  
  @doc """
  Get a user preference value.
  
  ## Parameters
  
  * `key` - The preference key to retrieve
  * `default` - Default value if preference doesn't exist (default: nil)
  
  ## Examples
  
      iex> UserPreferences.get(:theme)
      :dark
      
      iex> UserPreferences.get(:custom_setting, "default")
      "default"
  """
  def get(key, default \\ nil) do
    # Get current preferences
    prefs = Process.get(:user_preferences, @default_prefs)
    
    # Get value or default
    Map.get(prefs, key, default)
  end
  
  @doc """
  Set a user preference value.
  
  This function updates a preference and triggers any necessary effects,
  such as updating the UI components that depend on this preference.
  
  ## Parameters
  
  * `key` - The preference key to set
  * `value` - The value to set
  
  ## Examples
  
      iex> UserPreferences.set(:theme, :dark)
      :ok
      
      iex> UserPreferences.set(:high_contrast, true)
      :ok
  """
  def set(key, value) do
    # Get current preferences
    prefs = Process.get(:user_preferences, @default_prefs)
    
    # Don't update if value is the same
    if Map.get(prefs, key) == value do
      :ok
    else
      # Update preferences
      updated_prefs = Map.put(prefs, key, value)
      Process.put(:user_preferences, updated_prefs)
      
      # Broadcast event
      EventManager.broadcast({:user_preference_changed, key, value})
      
      # Auto-save if enabled
      settings = Process.get(:user_preferences_settings, %{})
      if Map.get(settings, :auto_save, true) do
        save()
      end
      
      # Apply specific preference
      apply_preference(key, value)
      
      :ok
    end
  end
  
  @doc """
  Update multiple preferences at once.
  
  ## Parameters
  
  * `preferences` - Map of preferences to update
  
  ## Examples
  
      iex> UserPreferences.update(%{
      ...>   theme: :dark,
      ...>   high_contrast: true
      ...> })
      :ok
  """
  def update(preferences) do
    # Get current preferences
    prefs = Process.get(:user_preferences, @default_prefs)
    
    # Merge and update
    updated_prefs = Map.merge(prefs, preferences)
    Process.put(:user_preferences, updated_prefs)
    
    # Broadcast events for each changed preference
    Map.keys(preferences)
    |> Enum.each(fn key ->
      value = Map.get(preferences, key)
      EventManager.broadcast({:user_preference_changed, key, value})
      
      # Apply specific preference
      apply_preference(key, value)
    end)
    
    # Auto-save if enabled
    settings = Process.get(:user_preferences_settings, %{})
    if Map.get(settings, :auto_save, true) do
      save()
    end
    
    :ok
  end
  
  @doc """
  Reset all preferences to default values.
  
  ## Examples
  
      iex> UserPreferences.reset()
      :ok
  """
  def reset do
    # Set to defaults
    Process.put(:user_preferences, @default_prefs)
    
    # Apply all default preferences
    apply_all_preferences()
    
    # Auto-save if enabled
    settings = Process.get(:user_preferences_settings, %{})
    if Map.get(settings, :auto_save, true) do
      save()
    end
    
    :ok
  end
  
  @doc """
  Save preferences to persistent storage.
  
  ## Examples
  
      iex> UserPreferences.save()
      :ok
  """
  def save do
    # Get current preferences
    prefs = Process.get(:user_preferences, @default_prefs)
    
    # Get storage directory
    settings = Process.get(:user_preferences_settings, %{})
    storage_dir = Map.get(settings, :storage_dir, "./prefs")
    
    # Serialize preferences
    serialized = :erlang.term_to_binary(prefs)
    
    # Save to file
    file_path = Path.join(storage_dir, @storage_file)
    File.write!(file_path, serialized)
    
    :ok
  end
  
  @doc """
  Load preferences from persistent storage.
  
  ## Examples
  
      iex> UserPreferences.load()
      :ok
  """
  def load do
    # Get storage directory
    settings = Process.get(:user_preferences_settings, %{})
    storage_dir = Map.get(settings, :storage_dir, "./prefs")
    
    # Build file path
    file_path = Path.join(storage_dir, @storage_file)
    
    # Check if file exists
    if File.exists?(file_path) do
      try do
        # Read and deserialize
        serialized = File.read!(file_path)
        prefs = :erlang.binary_to_term(serialized)
        
        # Update preferences
        Process.put(:user_preferences, prefs)
        
        :ok
      rescue
        _ ->
          # On error, use defaults
          Process.put(:user_preferences, @default_prefs)
          :error
      end
    else
      # If file doesn't exist, use defaults
      :ok
    end
  end
  
  @doc """
  Handle preference change events.
  """
  def handle_preference_changed({:user_preference_changed, key, value}) do
    # This handler could be used to log changes or trigger additional actions
    # beyond what apply_preference does
    :ok
  end
  
  # Private functions
  
  defp apply_all_preferences do
    # Get current preferences
    prefs = Process.get(:user_preferences, @default_prefs)
    
    # Apply each preference
    Enum.each(prefs, fn {key, value} ->
      apply_preference(key, value)
    end)
  end
  
  defp apply_preference(:high_contrast, value) do
    # Update accessibility setting
    Accessibility.set_high_contrast(value)
  end
  
  defp apply_preference(:reduced_motion, value) do
    # Update accessibility setting
    Accessibility.set_reduced_motion(value)
  end
  
  defp apply_preference(:large_text, value) do
    # Update accessibility setting
    Accessibility.set_large_text(value)
  end
  
  defp apply_preference(:screen_reader, value) do
    # Update accessibility setting
    Accessibility.set_screen_reader(value)
  end
  
  defp apply_preference(:theme, value) do
    # Apply theme
    ColorSystem.apply_theme(value)
  end
  
  defp apply_preference(:accent_color, value) do
    # Update accent color
    # This might involve creating a custom theme based on the current one
    current_theme = get(:theme)
    
    # Get existing custom colors
    custom_colors = get(:custom_colors, %{})
    
    # Update custom colors
    updated_custom_colors = Map.put(custom_colors, :accent, value)
    
    # Store updated custom colors
    set(:custom_colors, updated_custom_colors)
    
    # Apply custom colors to current theme
    # Implementation would depend on ColorSystem API
  end
  
  defp apply_preference(:focus_highlight_style, value) do
    # Update focus ring style
    Raxol.Components.FocusRing.configure(style: value)
  end
  
  defp apply_preference(:focus_highlight_color, value) do
    # Update focus ring color
    Raxol.Components.FocusRing.configure(color: value)
  end
  
  defp apply_preference(:focus_animation, value) do
    # Update focus ring animation
    Raxol.Components.FocusRing.configure(animation: value)
  end
  
  defp apply_preference(:tab_navigation_enabled, value) do
    # Enable or disable tab navigation
    if value do
      Raxol.Components.KeyboardNavigator.enable_tab_navigation()
    else
      Raxol.Components.KeyboardNavigator.disable_tab_navigation()
    end
  end
  
  defp apply_preference(:custom_shortcuts, value) do
    # Update custom shortcuts
    Enum.each(value, fn {shortcut_id, shortcut_def} ->
      # Register or update shortcut
      Raxol.Core.KeyboardShortcuts.register_custom_shortcut(shortcut_id, shortcut_def)
    end)
  end
  
  defp apply_preference(:shortcut_help_level, value) do
    # Update help level
    Raxol.Components.HintDisplay.set_help_level(value)
  end
  
  defp apply_preference(_, _) do
    # Unknown preference, do nothing
    :ok
  end
end 