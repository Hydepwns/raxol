defmodule Raxol.Core.KeyboardShortcuts do
  @moduledoc """
  Refactored KeyboardShortcuts that delegates to GenServer implementation.

  This module provides the same API as the original KeyboardShortcuts but uses
  a supervised GenServer instead of the Process dictionary for state management.

  ## Migration Notice
  This module is a drop-in replacement for `Raxol.Core.KeyboardShortcuts`.
  All functions maintain backward compatibility while providing improved
  fault tolerance and functional programming patterns.

  ## Benefits over Process Dictionary
  - Supervised state management with fault tolerance
  - Pure functional shortcut resolution
  - Priority-based conflict resolution
  - Context-aware shortcut activation
  - Better debugging and testing capabilities
  - No global state pollution
  """

  @behaviour Raxol.Core.KeyboardShortcutsBehaviour

  alias Raxol.Core.KeyboardShortcuts.Server
  alias Raxol.Core.Events.Manager, as: EventManager

  @doc """
  Ensures the Keyboard Shortcuts server is started.
  """
  def ensure_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Initialize the keyboard shortcuts manager.

  This function sets up the necessary state for managing keyboard shortcuts
  and registers event handlers for keyboard events.
  """
  def init do
    ensure_started()
    Server.init_shortcuts()

    # Register this module's handler with EventManager
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
  """
  def cleanup do
    ensure_started()

    # Unregister event handler
    EventManager.unregister_handler(
      :keyboard_event,
      __MODULE__,
      :handle_keyboard_event
    )

    # Clear all shortcuts
    Server.clear_all()
    :ok
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Register a keyboard shortcut with a callback function.

  ## Parameters
  - `shortcut` - The keyboard shortcut string (e.g., "Ctrl+S", "Alt+F4")
  - `name` - A unique identifier for the shortcut (atom or string)
  - `callback` - A function to be called when the shortcut is triggered
  - `opts` - Options for the shortcut

  ## Options
  - `:context` - The context in which this shortcut is active (default: `:global`)
  - `:description` - A description of what the shortcut does
  - `:priority` - Priority level (1-10, lower = higher priority)
  - `:override` - Whether to override existing shortcut (default: false)
  """
  def register_shortcut(shortcut, name, callback, opts \\ []) do
    ensure_started()

    case Server.register_shortcut(shortcut, name, callback, opts) do
      :ok ->
        :ok

      {:error, :conflict} ->
        # For backward compatibility, silently override on conflict
        Server.register_shortcut(
          shortcut,
          name,
          callback,
          Keyword.put(opts, :override, true)
        )
    end
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Unregister a keyboard shortcut.

  ## Parameters
  - `shortcut` - The keyboard shortcut string to unregister
  - `context` - The context from which to unregister (default: `:global`)
  """
  def unregister_shortcut(shortcut, context \\ :global) do
    ensure_started()
    Server.unregister_shortcut(shortcut, context)
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Set the active context for shortcuts.

  Context-specific shortcuts will only be active when their context is set.
  """
  def set_active_context(context) do
    ensure_started()
    Server.set_active_context(context)
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Get all shortcuts for a specific context.

  Returns a map of shortcut definitions for the given context.
  """
  def get_shortcuts_for_context(context \\ :global) do
    ensure_started()
    Server.get_shortcuts_for_context(context)
  end

  @impl Raxol.Core.KeyboardShortcutsBehaviour
  @doc """
  Show help text for available shortcuts.

  Displays formatted help text for all available shortcuts in the current context.
  """
  def show_shortcuts_help do
    ensure_started()
    help_text = Server.generate_shortcuts_help()
    IO.puts(help_text)
    :ok
  end

  @doc """
  Handle keyboard events.

  This function is called by the EventManager when keyboard events occur.
  """
  def handle_keyboard_event(event) do
    ensure_started()
    Server.handle_keyboard_event(event)
    :ok
  end

  # Additional helper functions

  @doc """
  Get the currently active context.
  """
  def get_active_context do
    ensure_started()
    Server.get_active_context()
  end

  @doc """
  Get all available shortcuts (global + active context).
  """
  def get_available_shortcuts do
    ensure_started()
    Server.get_available_shortcuts()
  end

  @doc """
  Get formatted help text for shortcuts.
  """
  def get_shortcuts_help do
    ensure_started()
    Server.generate_shortcuts_help()
  end

  @doc """
  Enable or disable shortcut processing.
  """
  def set_enabled(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_enabled(enabled)
  end

  @doc """
  Check if shortcuts are enabled.
  """
  def enabled? do
    ensure_started()
    Server.enabled?()
  end

  @doc """
  Set conflict resolution strategy.

  ## Strategies
  - `:first` - Keep the first registered shortcut
  - `:last` - Keep the last registered shortcut
  - `:priority` - Use priority to resolve conflicts
  """
  def set_conflict_resolution(strategy)
      when strategy in [:first, :last, :priority] do
    ensure_started()
    Server.set_conflict_resolution(strategy)
  end

  @doc """
  Clear all shortcuts.
  """
  def clear_all do
    ensure_started()
    Server.clear_all()
  end

  @doc """
  Clear shortcuts for a specific context.
  """
  def clear_context(context) do
    ensure_started()
    Server.clear_context(context)
  end

  @doc """
  Register a batch of shortcuts at once.

  ## Example
  ```elixir
  register_batch([
    {"Ctrl+S", :save, &save_file/0, description: "Save file"},
    {"Ctrl+O", :open, &open_file/0, description: "Open file"},
    {"Ctrl+Q", :quit, &quit_app/0, description: "Quit application"}
  ])
  ```
  """
  def register_batch(shortcuts) when is_list(shortcuts) do
    ensure_started()

    Enum.each(shortcuts, fn
      {shortcut, name, callback} ->
        register_shortcut(shortcut, name, callback)

      {shortcut, name, callback, opts} ->
        register_shortcut(shortcut, name, callback, opts)
    end)

    :ok
  end

  @doc """
  Check if a shortcut is registered.
  """
  def shortcut_registered?(shortcut, context \\ :global) do
    ensure_started()
    shortcuts = Server.get_shortcuts_for_context(context)

    # Parse the shortcut to get the key
    parsed = parse_shortcut_string(shortcut)
    key = shortcut_key(parsed)

    Map.has_key?(shortcuts, key)
  end

  # Private helper functions

  defp parse_shortcut_string(shortcut) when is_binary(shortcut) do
    parts = String.split(shortcut, "+")
    {modifiers, [key]} = Enum.split(parts, -1)

    modifiers =
      Enum.map(modifiers, fn mod ->
        case String.downcase(mod) do
          "ctrl" -> :ctrl
          "control" -> :ctrl
          "alt" -> :alt
          "shift" -> :shift
          "cmd" -> :cmd
          "command" -> :cmd
          _ -> String.to_atom(String.downcase(mod))
        end
      end)

    %{
      modifiers: Enum.sort(modifiers),
      key: String.to_atom(String.downcase(key))
    }
  end

  defp shortcut_key(parsed) do
    modifiers_str = Enum.join(parsed.modifiers, "_")
    "#{modifiers_str}_#{parsed.key}"
  end
end
