defmodule Raxol.Core.KeyboardShortcuts do
  @moduledoc """
  Keyboard shortcuts manager for Raxol applications.

  This module provides functionality to register, manage, and handle keyboard shortcuts
  throughout the application. It integrates with the accessibility features to provide
  better keyboard navigation and interaction.

  ## Features

  * Register global and context-specific shortcuts
  * Handle keyboard shortcuts with custom callbacks
  * Display available shortcuts based on current context
  * Integration with accessibility features
  * Support for shortcut combinations (Ctrl, Alt, Shift modifiers)

  ## Examples

      # Initialize the keyboard shortcuts manager
      KeyboardShortcuts.init()

      # Register a global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+F", :search, fn ->
        # Search functionality
        search_content()
      end)

      # Register a context-specific shortcut
      KeyboardShortcuts.register_shortcut("Alt+S", :save, fn ->
        # Save functionality
        save_document()
      end, context: :editor)

      # Get all available shortcuts for current context
      shortcuts = KeyboardShortcuts.get_shortcuts_for_context(:editor)

      # Display help for available shortcuts
      KeyboardShortcuts.show_shortcuts_help()
  """

  @behaviour Raxol.Core.KeyboardShortcutsBehaviour

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Initialize the keyboard shortcuts manager.

  This function sets up the necessary state for managing keyboard shortcuts
  and registers event handlers for keyboard events.

  ## Examples

      iex> KeyboardShortcuts.init()
      :ok
  """
  def init do
    # Initialize shortcuts registry
    Process.put(:keyboard_shortcuts, %{
      global: %{},
      contexts: %{}
    })

    # Register event handler for keyboard events
    EventManager.register_handler(
      :keyboard_event,
      __MODULE__,
      :handle_keyboard_event
    )

    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Clean up the keyboard shortcuts manager.

  This function cleans up any resources used by the keyboard shortcuts manager
  and unregisters event handlers.

  ## Examples

      iex> KeyboardShortcuts.cleanup()
      :ok
  """
  def cleanup do
    # Unregister event handler
    EventManager.unregister_handler(
      :keyboard_event,
      __MODULE__,
      :handle_keyboard_event
    )

    # Clean up shortcuts registry
    Process.delete(:keyboard_shortcuts)

    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Register a keyboard shortcut with a callback function.

  ## Parameters

  * `shortcut` - The keyboard shortcut string (e.g., "Ctrl+S", "Alt+F4")
  * `name` - A unique identifier for the shortcut (atom or string)
  * `callback` - A function to be called when the shortcut is triggered
  * `opts` - Options for the shortcut

  ## Options

  * `:context` - The context in which this shortcut is active (default: `:global`)
  * `:description` - A description of what the shortcut does
  * `:priority` - Priority level (`:high`, `:medium`, `:low`), affects precedence

  ## Examples

      iex> KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> save_document() end)
      :ok

      iex> KeyboardShortcuts.register_shortcut("Alt+F", :file_menu, fn -> open_file_menu() end,
      ...>   context: :main_menu, description: "Open File menu")
      :ok
  """
  def register_shortcut(shortcut, name, callback, opts \\ []) do
    # Parse shortcut string
    parsed_shortcut = parse_shortcut(shortcut)

    # Get options
    context = Keyword.get(opts, :context, :global)
    description = Keyword.get(opts, :description, "")
    priority = Keyword.get(opts, :priority, :medium)

    # Create shortcut definition
    shortcut_def = %{
      key_combo: parsed_shortcut,
      name: name,
      callback: callback,
      description: description,
      priority: priority
    }

    # Get current shortcuts registry
    shortcuts = Process.get(:keyboard_shortcuts)

    # Update shortcuts registry
    updated_shortcuts =
      if context == :global do
        # Update global shortcuts
        global = Map.put(shortcuts.global, name, shortcut_def)
        %{shortcuts | global: global}
      else
        # Update context-specific shortcuts
        contexts =
          Map.update(
            shortcuts.contexts,
            context,
            %{name => shortcut_def},
            &Map.put(&1, name, shortcut_def)
          )

        %{shortcuts | contexts: contexts}
      end

    # Store updated shortcuts
    Process.put(:keyboard_shortcuts, updated_shortcuts)

    # Notify about new shortcut
    EventManager.dispatch({:shortcut_registered, name, shortcut, context})

    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Unregister a keyboard shortcut.

  ## Parameters

  * `name` - The unique identifier for the shortcut
  * `context` - The context in which the shortcut was registered (default: `:global`)

  ## Examples

      iex> KeyboardShortcuts.unregister_shortcut(:save)
      :ok

      iex> KeyboardShortcuts.unregister_shortcut(:file_menu, :main_menu)
      :ok
  """
  def unregister_shortcut(name, context \\ :global) do
    # Get current shortcuts registry
    shortcuts = Process.get(:keyboard_shortcuts)

    # Update shortcuts registry
    updated_shortcuts =
      if context == :global do
        # Update global shortcuts
        global = Map.delete(shortcuts.global, name)
        %{shortcuts | global: global}
      else
        # Update context-specific shortcuts
        contexts =
          Map.update(
            shortcuts.contexts,
            context,
            %{},
            &Map.delete(&1, name)
          )

        %{shortcuts | contexts: contexts}
      end

    # Store updated shortcuts
    Process.put(:keyboard_shortcuts, updated_shortcuts)

    # Notify about removed shortcut
    EventManager.dispatch({:shortcut_unregistered, name, context})

    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Set the current context for shortcuts.

  This affects which shortcuts are active and will be triggered by keyboard events.

  ## Parameters

  * `context` - The context to set as active

  ## Examples

      iex> KeyboardShortcuts.set_context(:editor)
      :ok

      iex> KeyboardShortcuts.set_context(:file_browser)
      :ok
  """
  def set_context(context) do
    # Store current context
    Process.put(:keyboard_shortcuts_context, context)

    # Notify about context change
    EventManager.dispatch({:shortcut_context_changed, context})

    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Get the current active context for shortcuts.

  ## Examples

      iex> KeyboardShortcuts.get_current_context()
      :editor
  """
  def get_current_context do
    Process.get(:keyboard_shortcuts_context, :global)
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Get all shortcuts for a specific context.

  ## Parameters

  * `context` - The context to get shortcuts for (default: current context)

  ## Examples

      iex> KeyboardShortcuts.get_shortcuts_for_context(:editor)
      [
        %{name: :save, key_combo: "Ctrl+S", description: "Save document"},
        %{name: :find, key_combo: "Ctrl+F", description: "Find in document"}
      ]
  """
  def get_shortcuts_for_context(context \\ nil) do
    # Get current shortcuts registry
    shortcuts = Process.get(:keyboard_shortcuts)

    # Determine context to use
    context_to_use = context || get_current_context()

    # Get shortcuts for context
    context_shortcuts =
      if context_to_use == :global do
        Map.values(shortcuts.global)
      else
        # Combine global shortcuts with context-specific ones
        global_shortcuts = Map.values(shortcuts.global)

        context_map = Map.get(shortcuts.contexts, context_to_use, %{})
        context_specific_shortcuts = Map.values(context_map)

        global_shortcuts ++ context_specific_shortcuts
      end

    # Format shortcuts for display
    Enum.map(context_shortcuts, fn shortcut ->
      %{
        name: shortcut.name,
        key_combo: shortcut_to_string(shortcut.key_combo),
        description: shortcut.description
      }
    end)
  end

  @doc """
  Show help for available keyboard shortcuts for the current context.

  Returns a formatted string of available shortcuts. This version matches the behaviour and can be called without arguments.

  ## Examples

      iex> KeyboardShortcuts.show_shortcuts_help()
      {:ok, help_string}
  """
  def show_shortcuts_help() do
    show_shortcuts_help(nil)
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Display help for available shortcuts.

  This function generates a help message for all shortcuts available in the current context
  and announces it through the accessibility system if enabled.

  ## Parameters

  * `user_preferences_pid_or_name` - The PID or name of the user preferences process

  ## Examples

      iex> KeyboardShortcuts.show_shortcuts_help(self())
      :ok
  """
  def show_shortcuts_help(user_preferences_pid_or_name) do
    # Get current context
    current_context = get_current_context()

    # Get shortcuts for context
    shortcuts = get_shortcuts_for_context(current_context)

    # Format help message
    context_name =
      if current_context == :global, do: "Global", else: "#{current_context}"

    help_message = "Available keyboard shortcuts for #{context_name}:\n"

    shortcuts_help =
      shortcuts
      |> Enum.sort_by(fn s -> s.key_combo end)
      |> Enum.map(fn s -> "#{s.key_combo}: #{s.description}" end)
      |> Enum.join("\n")

    full_message = help_message <> shortcuts_help

    # Announce through accessibility system if available
    if function_exported?(Accessibility, :announce, 3) do
      Accessibility.announce(
        full_message,
        [priority: :medium],
        user_preferences_pid_or_name
      )
    end

    # Return formatted help
    {:ok, full_message}
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Trigger a shortcut programmatically.

  ## Parameters

  * `name` - The unique identifier for the shortcut
  * `context` - The context in which the shortcut was registered (default: current context)

  ## Examples

      iex> KeyboardShortcuts.trigger_shortcut(:save)
      :ok

      iex> KeyboardShortcuts.trigger_shortcut(:file_menu, :main_menu)
      :ok
  """
  def trigger_shortcut(name, context \\ nil) do
    # Get current shortcuts registry
    shortcuts = Process.get(:keyboard_shortcuts)

    # Determine context to use
    context_to_use = context || get_current_context()

    # Find shortcut
    shortcut =
      if context_to_use == :global do
        Map.get(shortcuts.global, name)
      else
        context_map = Map.get(shortcuts.contexts, context_to_use, %{})
        Map.get(context_map, name) || Map.get(shortcuts.global, name)
      end

    # Execute callback if found
    if shortcut do
      shortcut.callback.()
      :ok
    else
      {:error, :shortcut_not_found}
    end
  end

  # Private functions

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  # Make handle_keyboard_event public and uncomment it and helpers
  def handle_keyboard_event({:keyboard_event, {:key, key, modifiers}}) do
    # Get current shortcuts registry
    shortcuts = Process.get(:keyboard_shortcuts)

    # Get current context
    current_context = get_current_context()

    # Build key combo
    key_combo = %{
      key: key,
      ctrl: Enum.member?(modifiers, :ctrl),
      alt: Enum.member?(modifiers, :alt),
      shift: Enum.member?(modifiers, :shift)
    }

    # Find matching shortcuts
    matching_shortcuts =
      find_matching_shortcuts(shortcuts, key_combo, current_context)

    # Execute callbacks for matching shortcuts
    # Execute only the highest priority shortcut found
    case matching_shortcuts do
      [] ->
        # No shortcut found
        :ok

      [highest_priority_shortcut | _] ->
        highest_priority_shortcut.callback.()
        :ok
    end

    # # Original: Execute callbacks for all matching shortcuts
    # Enum.each(matching_shortcuts, fn shortcut ->
    #   shortcut.callback.()
    # end)

    # :ok
  end

  # Catch-all for other event formats
  def handle_keyboard_event(_), do: :ok

  defp find_matching_shortcuts(shortcuts, key_combo, current_context) do
    # Get global shortcuts that match
    global_matches =
      shortcuts.global
      |> Map.values()
      |> Enum.filter(fn shortcut ->
        match_key_combo?(shortcut.key_combo, key_combo)
      end)

    # If we're in global context, just return global matches sorted by priority
    if current_context == :global do
      global_matches
      |> Enum.sort_by(&priority_value(&1.priority))
    else
      # Get context-specific shortcuts that match
      context_map = Map.get(shortcuts.contexts, current_context, %{})

      context_matches =
        context_map
        |> Map.values()
        |> Enum.filter(fn shortcut ->
          match_key_combo?(shortcut.key_combo, key_combo)
        end)

      # Combine both, with context-specific taking precedence, and sort
      prioritized_shortcuts(global_matches, context_matches)
    end
  end

  defp match_key_combo?(shortcut_combo, key_combo) do
    shortcut_combo.key == key_combo.key &&
      shortcut_combo.ctrl == key_combo.ctrl &&
      shortcut_combo.alt == key_combo.alt &&
      shortcut_combo.shift == key_combo.shift
  end

  defp prioritized_shortcuts(global_matches, context_matches) do
    # Identify shortcut names from context matches
    context_names = MapSet.new(context_matches, & &1.name)

    # Filter out global shortcuts that are overridden by name in context
    # (Note: This simple name override might not be ideal if different key combos
    # exist for the same name globally vs context)
    filtered_globals =
      Enum.reject(global_matches, fn g ->
        MapSet.member?(context_names, g.name)
      end)

    # Combine and sort by priority (high first)
    (filtered_globals ++ context_matches)
    |> Enum.sort_by(fn s ->
      priority_value(s.priority)
    end)
  end

  defp priority_value(:high), do: 1
  defp priority_value(:medium), do: 2
  defp priority_value(:low), do: 3

  defp parse_shortcut(shortcut_string) do
    # Simplified parsing (assumes format like "Ctrl+S")
    # Split by "+" to separate modifiers from the key
    parts = String.split(shortcut_string, "+")

    # Extract modifiers and key
    {modifiers, [key]} = Enum.split(parts, length(parts) - 1)

    # Create structured key combo
    %{
      key: String.downcase(key),
      ctrl: "ctrl" in Enum.map(modifiers, &String.downcase/1),
      alt: "alt" in Enum.map(modifiers, &String.downcase/1),
      shift: "shift" in Enum.map(modifiers, &String.downcase/1)
    }
  end

  # Convert structured key combo back to string
  defp shortcut_to_string(key_combo) do
    modifiers = []

    modifiers = if key_combo.ctrl, do: ["Ctrl" | modifiers], else: modifiers
    modifiers = if key_combo.alt, do: ["Alt" | modifiers], else: modifiers
    modifiers = if key_combo.shift, do: ["Shift" | modifiers], else: modifiers

    case modifiers do
      [] -> String.capitalize(key_combo.key)
      _ -> Enum.join(modifiers, "+") <> "+" <> String.capitalize(key_combo.key)
    end
  end
end
