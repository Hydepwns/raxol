defmodule Raxol.Core.KeyboardShortcuts.Server do
  @moduledoc """
  GenServer implementation for keyboard shortcuts management in Raxol.

  This server provides a pure functional approach to keyboard shortcuts,
  eliminating Process dictionary usage and implementing proper OTP patterns.

  ## Features
  - Global and context-specific shortcut registration
  - Priority-based shortcut resolution
  - Shortcut conflict detection
  - Context switching support
  - Shortcut help generation
  - Integration with accessibility features
  - Customizable key binding formats
  - Supervised state management with fault tolerance

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    shortcuts: %{
      global: %{shortcut_key => shortcut_def},
      contexts: %{context_name => %{shortcut_key => shortcut_def}}
    },
    active_context: atom(),
    enabled: boolean(),
    conflict_resolution: :first | :last | :priority,
    shortcut_format: :standard | :vim | :emacs
  }
  ```
  """

  use GenServer
  require Logger
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility

  @default_state %{
    shortcuts: %{
      global: %{},
      contexts: %{}
    },
    active_context: :global,
    enabled: true,
    conflict_resolution: :priority,
    shortcut_format: :standard
  }

  # Client API

  @doc """
  Starts the Keyboard Shortcuts server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    initial_state = Keyword.get(opts, :initial_state, @default_state)
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Initializes the keyboard shortcuts manager.
  """
  def init_shortcuts(server \\ __MODULE__) do
    GenServer.call(server, :init_shortcuts)
  end

  @doc """
  Registers a keyboard shortcut with a callback function.
  
  ## Options
  - `:context` - The context in which this shortcut is active (default: `:global`)
  - `:description` - A description of what the shortcut does
  - `:priority` - Priority level (1-10, lower = higher priority)
  - `:override` - Whether to override existing shortcut (default: false)
  """
  def register_shortcut(server \\ __MODULE__, shortcut, name, callback, opts \\ []) do
    GenServer.call(server, {:register_shortcut, shortcut, name, callback, opts})
  end

  @doc """
  Unregisters a keyboard shortcut.
  """
  def unregister_shortcut(server \\ __MODULE__, shortcut, context \\ :global) do
    GenServer.call(server, {:unregister_shortcut, shortcut, context})
  end

  @doc """
  Sets the active context for shortcuts.
  """
  def set_active_context(server \\ __MODULE__, context) do
    GenServer.call(server, {:set_active_context, context})
  end

  @doc """
  Gets the active context.
  """
  def get_active_context(server \\ __MODULE__) do
    GenServer.call(server, :get_active_context)
  end

  @doc """
  Gets all shortcuts for a specific context.
  """
  def get_shortcuts_for_context(server \\ __MODULE__, context \\ :global) do
    GenServer.call(server, {:get_shortcuts_for_context, context})
  end

  @doc """
  Gets all available shortcuts (global + active context).
  """
  def get_available_shortcuts(server \\ __MODULE__) do
    GenServer.call(server, :get_available_shortcuts)
  end

  @doc """
  Generates help text for available shortcuts.
  """
  def generate_shortcuts_help(server \\ __MODULE__) do
    GenServer.call(server, :generate_shortcuts_help)
  end

  @doc """
  Handles a keyboard event.
  """
  def handle_keyboard_event(server \\ __MODULE__, event) do
    GenServer.cast(server, {:handle_keyboard_event, event})
  end

  @doc """
  Enables/disables shortcuts processing.
  """
  def set_enabled(server \\ __MODULE__, enabled) when is_boolean(enabled) do
    GenServer.call(server, {:set_enabled, enabled})
  end

  @doc """
  Checks if shortcuts are enabled.
  """
  def enabled?(server \\ __MODULE__) do
    GenServer.call(server, :is_enabled)
  end

  @doc """
  Sets conflict resolution strategy.
  """
  def set_conflict_resolution(server \\ __MODULE__, strategy) 
      when strategy in [:first, :last, :priority] do
    GenServer.call(server, {:set_conflict_resolution, strategy})
  end

  @doc """
  Clears all shortcuts.
  """
  def clear_all(server \\ __MODULE__) do
    GenServer.call(server, :clear_all)
  end

  @doc """
  Clears shortcuts for a specific context.
  """
  def clear_context(server \\ __MODULE__, context) do
    GenServer.call(server, {:clear_context, context})
  end

  @doc """
  Gets the current state (for debugging/testing).
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call(:init_shortcuts, _from, state) do
    # Register event handler for keyboard events
    EventManager.register_handler(:keyboard_event, __MODULE__, :handle_keyboard_event)
    
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:register_shortcut, shortcut, name, callback, opts}, _from, state) do
    context = Keyword.get(opts, :context, :global)
    description = Keyword.get(opts, :description, "")
    priority = Keyword.get(opts, :priority, 5)
    override = Keyword.get(opts, :override, false)
    
    parsed_shortcut = parse_shortcut(shortcut)
    
    shortcut_def = %{
      key_combo: parsed_shortcut,
      name: name,
      callback: callback,
      description: description,
      priority: priority,
      raw: shortcut
    }
    
    # Check for conflicts
    existing = get_shortcut_from_state(state, parsed_shortcut, context)
    
    if existing && !override do
      {:reply, {:error, :conflict}, state}
    else
      new_state = add_shortcut_to_state(state, parsed_shortcut, shortcut_def, context)
      
      # Announce if accessibility is enabled
      if Accessibility.enabled?() do
        Accessibility.announce("Shortcut #{shortcut} registered for #{name}")
      end
      
      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unregister_shortcut, shortcut, context}, _from, state) do
    parsed_shortcut = parse_shortcut(shortcut)
    new_state = remove_shortcut_from_state(state, parsed_shortcut, context)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_active_context, context}, _from, state) do
    new_state = %{state | active_context: context}
    
    # Dispatch context change event
    EventManager.dispatch({:shortcut_context_changed, context})
    
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_active_context, _from, state) do
    {:reply, state.active_context, state}
  end

  @impl GenServer
  def handle_call({:get_shortcuts_for_context, context}, _from, state) do
    shortcuts = 
      if context == :global do
        state.shortcuts.global
      else
        Map.get(state.shortcuts.contexts, context, %{})
      end
    
    {:reply, shortcuts, state}
  end

  @impl GenServer
  def handle_call(:get_available_shortcuts, _from, state) do
    global = state.shortcuts.global
    context_shortcuts = 
      if state.active_context != :global do
        Map.get(state.shortcuts.contexts, state.active_context, %{})
      else
        %{}
      end
    
    # Merge with context shortcuts taking precedence
    available = Map.merge(global, context_shortcuts)
    {:reply, available, state}
  end

  @impl GenServer
  def handle_call(:generate_shortcuts_help, _from, state) do
    help = generate_help_text(state)
    {:reply, help, state}
  end

  @impl GenServer
  def handle_call({:set_enabled, enabled}, _from, state) do
    new_state = %{state | enabled: enabled}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:is_enabled, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl GenServer
  def handle_call({:set_conflict_resolution, strategy}, _from, state) do
    new_state = %{state | conflict_resolution: strategy}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:clear_all, _from, state) do
    new_state = %{state | shortcuts: %{global: %{}, contexts: %{}}}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:clear_context, context}, _from, state) do
    new_state = 
      if context == :global do
        put_in(state, [:shortcuts, :global], %{})
      else
        update_in(state, [:shortcuts, :contexts], &Map.delete(&1, context))
      end
    
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:handle_keyboard_event, event}, state) do
    if state.enabled do
      process_keyboard_event(event, state)
    end
    
    {:noreply, state}
  end

  # Private Helper Functions

  defp parse_shortcut(shortcut) when is_binary(shortcut) do
    # Parse shortcut string like "Ctrl+S", "Alt+F4", "Cmd+Shift+P"
    parts = String.split(shortcut, "+")
    
    {modifiers, [key]} = Enum.split(parts, -1)
    
    modifiers = Enum.map(modifiers, fn mod ->
      case String.downcase(mod) do
        "ctrl" -> :ctrl
        "control" -> :ctrl
        "alt" -> :alt
        "shift" -> :shift
        "cmd" -> :cmd
        "command" -> :cmd
        "meta" -> :meta
        "win" -> :win
        _ -> String.to_atom(String.downcase(mod))
      end
    end)
    
    key_atom = 
      case String.downcase(key) do
        "space" -> :space
        "enter" -> :enter
        "return" -> :enter
        "tab" -> :tab
        "esc" -> :escape
        "escape" -> :escape
        "up" -> :up
        "down" -> :down
        "left" -> :left
        "right" -> :right
        single when byte_size(single) == 1 -> String.to_atom(String.downcase(single))
        other -> String.to_atom(String.downcase(other))
      end
    
    %{
      modifiers: Enum.sort(modifiers),
      key: key_atom
    }
  end

  defp get_shortcut_from_state(state, parsed_shortcut, context) do
    shortcuts = 
      if context == :global do
        state.shortcuts.global
      else
        Map.get(state.shortcuts.contexts, context, %{})
      end
    
    Map.get(shortcuts, shortcut_key(parsed_shortcut))
  end

  defp add_shortcut_to_state(state, parsed_shortcut, shortcut_def, context) do
    key = shortcut_key(parsed_shortcut)
    
    if context == :global do
      put_in(state, [:shortcuts, :global, key], shortcut_def)
    else
      contexts = state.shortcuts.contexts
      context_shortcuts = Map.get(contexts, context, %{})
      updated_shortcuts = Map.put(context_shortcuts, key, shortcut_def)
      updated_contexts = Map.put(contexts, context, updated_shortcuts)
      
      %{state | shortcuts: %{state.shortcuts | contexts: updated_contexts}}
    end
  end

  defp remove_shortcut_from_state(state, parsed_shortcut, context) do
    key = shortcut_key(parsed_shortcut)
    
    if context == :global do
      update_in(state, [:shortcuts, :global], &Map.delete(&1, key))
    else
      update_in(state, [:shortcuts, :contexts, context], &Map.delete(&1 || %{}, key))
    end
  end

  defp shortcut_key(parsed_shortcut) do
    modifiers_str = Enum.join(parsed_shortcut.modifiers, "_")
    "#{modifiers_str}_#{parsed_shortcut.key}"
  end

  defp process_keyboard_event({:keyboard_event, key_data}, state) when is_map(key_data) do
    key = key_data[:key]
    modifiers = key_data[:modifiers] || []
    
    parsed = %{
      key: key,
      modifiers: Enum.sort(modifiers)
    }
    
    key_str = shortcut_key(parsed)
    
    # Look for matching shortcut in active context first, then global
    shortcut = 
      if state.active_context != :global do
        context_shortcuts = Map.get(state.shortcuts.contexts, state.active_context, %{})
        Map.get(context_shortcuts, key_str)
      end || Map.get(state.shortcuts.global, key_str)
    
    if shortcut && shortcut.callback do
      # Execute callback
      try do
        shortcut.callback.()
        
        # Announce if accessibility is enabled
        if Accessibility.enabled?() && shortcut.description != "" do
          Accessibility.announce(shortcut.description, priority: :high)
        end
      rescue
        error ->
          Logger.error("Shortcut callback failed: #{inspect(error)}")
      end
    end
  end

  defp process_keyboard_event(_event, _state), do: :ok

  defp generate_help_text(state) do
    global_shortcuts = format_shortcuts_group("Global", state.shortcuts.global)
    
    context_help = 
      if state.active_context != :global do
        context_shortcuts = Map.get(state.shortcuts.contexts, state.active_context, %{})
        format_shortcuts_group(to_string(state.active_context), context_shortcuts)
      else
        ""
      end
    
    [global_shortcuts, context_help]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n\n")
  end

  defp format_shortcuts_group(title, shortcuts) when map_size(shortcuts) > 0 do
    header = "#{title} Shortcuts:\n"
    
    shortcuts_text = 
      shortcuts
      |> Enum.sort_by(fn {_key, def} -> def.priority end)
      |> Enum.map(fn {_key, def} ->
        "  #{def.raw} - #{def.description || def.name}"
      end)
      |> Enum.join("\n")
    
    header <> shortcuts_text
  end

  defp format_shortcuts_group(_title, _shortcuts), do: ""
end