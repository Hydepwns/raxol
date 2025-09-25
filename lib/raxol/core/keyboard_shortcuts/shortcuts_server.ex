defmodule Raxol.Core.KeyboardShortcuts.ShortcutsServer do
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
  alias Raxol.Core.Events.EventManager, as: EventManager
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
  def register_shortcut(
        server \\ __MODULE__,
        shortcut,
        name,
        callback,
        opts \\ []
      ) do
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
    # Event handler registration is done by the main KeyboardShortcuts module
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(
        {:register_shortcut, shortcut, name, callback, opts},
        _from,
        state
      ) do
    context = Keyword.get(opts, :context, :global)
    description = Keyword.get(opts, :description, "")
    priority = Keyword.get(opts, :priority, :medium)
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

    case check_shortcut_conflict(existing, override) do
      {:conflict, _} ->
        {:reply, {:error, :conflict}, state}

      :allow ->
        new_state =
          add_shortcut_to_state(state, parsed_shortcut, shortcut_def, context)

        announce_shortcut_registration(shortcut, name)
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unregister_shortcut, shortcut, context}, _from, state) do
    new_state =
      if is_atom(shortcut) or
           (is_binary(shortcut) and not String.contains?(shortcut, "+")) do
        # Unregister by name
        remove_shortcut_by_name(state, shortcut, context)
      else
        # Unregister by shortcut string
        parsed_shortcut = parse_shortcut(shortcut)
        remove_shortcut_from_state(state, parsed_shortcut, context)
      end

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
    shortcuts = get_shortcuts_by_context(state, context)
    {:reply, shortcuts, state}
  end

  @impl GenServer
  def handle_call(:get_available_shortcuts, _from, state) do
    global = state.shortcuts.global

    context_shortcuts = get_context_shortcuts(state)

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
    new_state = clear_shortcuts_for_context(state, context)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:handle_keyboard_event, event}, state) do
    process_event_if_enabled(event, state)

    {:noreply, state}
  end

  # Private Helper Functions

  @spec check_shortcut_conflict(any(), String.t() | integer()) :: any()
  defp check_shortcut_conflict(existing, override)
       when existing != nil and override == false do
    {:conflict, existing}
  end

  @spec check_shortcut_conflict(any(), any()) :: any()
  defp check_shortcut_conflict(_, _), do: :allow

  @spec announce_shortcut_registration(any(), String.t() | atom()) :: any()
  defp announce_shortcut_registration(shortcut, name) do
    case Accessibility.enabled?() do
      true ->
        Accessibility.announce("Shortcut #{shortcut} registered for #{name}")

      false ->
        :ok
    end
  end

  @spec get_shortcuts_by_context(map(), any()) :: any() | nil
  defp get_shortcuts_by_context(state, :global), do: state.shortcuts.global

  @spec get_shortcuts_by_context(map(), any()) :: any() | nil
  defp get_shortcuts_by_context(state, context) do
    Map.get(state.shortcuts.contexts, context, %{})
  end

  @spec get_context_shortcuts(map()) :: any() | nil
  defp get_context_shortcuts(state) when state.active_context != :global do
    Map.get(state.shortcuts.contexts, state.active_context, %{})
  end

  @spec get_context_shortcuts(map()) :: any() | nil
  defp get_context_shortcuts(_state), do: %{}

  @spec clear_shortcuts_for_context(map(), any()) :: any()
  defp clear_shortcuts_for_context(state, :global) do
    put_in(state, [:shortcuts, :global], %{})
  end

  @spec clear_shortcuts_for_context(map(), any()) :: any()
  defp clear_shortcuts_for_context(state, context) do
    update_in(state, [:shortcuts, :contexts], &Map.delete(&1, context))
  end

  @spec process_event_if_enabled(any(), map()) :: any()
  defp process_event_if_enabled(event, state) when state.enabled == true do
    process_keyboard_event(event, state)
  end

  @spec process_event_if_enabled(any(), map()) :: any()
  defp process_event_if_enabled(_event, _state), do: :ok

  @spec add_shortcut_by_context(map(), any(), any(), any()) :: any()
  defp add_shortcut_by_context(state, key, shortcut_def, :global) do
    put_in(state, [:shortcuts, :global, key], shortcut_def)
  end

  @spec add_shortcut_by_context(map(), any(), any(), any()) :: any()
  defp add_shortcut_by_context(state, key, shortcut_def, context) do
    contexts = state.shortcuts.contexts
    context_shortcuts = Map.get(contexts, context, %{})
    updated_shortcuts = Map.put(context_shortcuts, key, shortcut_def)
    updated_contexts = Map.put(contexts, context, updated_shortcuts)
    %{state | shortcuts: %{state.shortcuts | contexts: updated_contexts}}
  end

  @spec remove_shortcut_by_context(map(), any(), any()) :: any()
  defp remove_shortcut_by_context(state, key, :global) do
    update_in(state, [:shortcuts, :global], &Map.delete(&1, key))
  end

  @spec remove_shortcut_by_context(map(), any(), any()) :: any()
  defp remove_shortcut_by_context(state, key, context) do
    update_in(
      state,
      [:shortcuts, :contexts, context],
      &Map.delete(&1 || %{}, key)
    )
  end

  @spec remove_shortcut_by_name(map(), String.t() | atom(), any()) :: any()
  defp remove_shortcut_by_name(state, name, :global) do
    shortcuts = state.shortcuts.global

    key_to_remove =
      Enum.find_value(shortcuts, fn {key, shortcut} ->
        if shortcut.name == name, do: key
      end)

    if key_to_remove do
      update_in(state, [:shortcuts, :global], &Map.delete(&1, key_to_remove))
    else
      state
    end
  end

  @spec remove_shortcut_by_name(map(), String.t() | atom(), any()) :: any()
  defp remove_shortcut_by_name(state, name, context) do
    shortcuts = Map.get(state.shortcuts.contexts, context, %{})

    key_to_remove =
      Enum.find_value(shortcuts, fn {key, shortcut} ->
        if shortcut.name == name, do: key
      end)

    if key_to_remove do
      update_in(
        state,
        [:shortcuts, :contexts, context],
        &Map.delete(&1 || %{}, key_to_remove)
      )
    else
      state
    end
  end

  @spec find_matching_shortcut(map(), any()) :: any()
  defp find_matching_shortcut(state, key_str)
       when state.active_context != :global do
    context_shortcuts =
      Map.get(state.shortcuts.contexts, state.active_context, %{})

    Map.get(context_shortcuts, key_str) ||
      Map.get(state.shortcuts.global, key_str)
  end

  @spec find_matching_shortcut(map(), any()) :: any()
  defp find_matching_shortcut(state, key_str) do
    Map.get(state.shortcuts.global, key_str)
  end

  @spec execute_shortcut_callback(any()) :: any()
  defp execute_shortcut_callback(nil), do: :ok

  @spec execute_shortcut_callback(any()) :: any()
  defp execute_shortcut_callback(shortcut) when shortcut.callback == nil,
    do: :ok

  @spec execute_shortcut_callback(any()) :: any()
  defp execute_shortcut_callback(shortcut) do
    case Raxol.Core.ErrorHandling.safe_call(shortcut.callback) do
      {:ok, _result} ->
        announce_shortcut_execution(shortcut)

      {:error, reason} ->
        require Logger
        Logger.error("Shortcut callback failed: #{inspect(reason)}")
    end
  end

  @spec announce_shortcut_execution(any()) :: any()
  defp announce_shortcut_execution(shortcut) do
    case {Accessibility.enabled?(), shortcut.description} do
      {true, description} when description != "" ->
        Accessibility.announce(description, priority: :high)

      _ ->
        :ok
    end
  end

  @spec generate_context_help(map()) :: any()
  defp generate_context_help(state) when state.active_context != :global do
    context_shortcuts =
      Map.get(state.shortcuts.contexts, state.active_context, %{})

    format_shortcuts_group(to_string(state.active_context), context_shortcuts)
  end

  @spec generate_context_help(map()) :: any()
  defp generate_context_help(_state), do: ""

  @spec parse_shortcut(String.t()) :: {:ok, any()} | {:error, any()}
  defp parse_shortcut(shortcut) when is_binary(shortcut) do
    # Parse shortcut string like "Ctrl+S", "Alt+F4", "Cmd+Shift+P"
    parts = String.split(shortcut, "+")
    {modifiers, [key]} = Enum.split(parts, -1)

    %{
      modifiers: Enum.sort(parse_modifiers(modifiers)),
      key: parse_key(key)
    }
  end

  @spec parse_modifiers(list(String.t())) :: list(atom())
  defp parse_modifiers(modifiers) do
    Enum.map(modifiers, &parse_modifier/1)
  end

  @spec parse_modifier(String.t()) :: atom()
  defp parse_modifier(mod) do
    case String.downcase(mod) do
      "ctrl" -> :ctrl
      "control" -> :ctrl
      "alt" -> :alt
      "shift" -> :shift
      "cmd" -> :cmd
      "command" -> :cmd
      "meta" -> :meta
      "win" -> :win
      other -> String.to_atom(other)
    end
  end

  @spec parse_key(String.t()) :: atom()
  defp parse_key(key) do
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
      other -> String.to_atom(other)
    end
  end

  @spec get_shortcut_from_state(map(), any(), any()) :: any() | nil
  defp get_shortcut_from_state(state, parsed_shortcut, context) do
    shortcuts = get_shortcuts_by_context(state, context)
    Map.get(shortcuts, shortcut_key(parsed_shortcut))
  end

  @spec add_shortcut_to_state(map(), any(), any(), any()) :: any()
  defp add_shortcut_to_state(state, parsed_shortcut, shortcut_def, context) do
    key = shortcut_key(parsed_shortcut)

    add_shortcut_by_context(state, key, shortcut_def, context)
  end

  @spec remove_shortcut_from_state(map(), any(), any()) :: any()
  defp remove_shortcut_from_state(state, parsed_shortcut, context) do
    key = shortcut_key(parsed_shortcut)

    remove_shortcut_by_context(state, key, context)
  end

  @spec shortcut_key(any()) :: any()
  defp shortcut_key(parsed_shortcut) do
    modifiers_str =
      if parsed_shortcut.modifiers == [] do
        ""
      else
        Enum.join(parsed_shortcut.modifiers, "_") <> "_"
      end

    "#{modifiers_str}#{parsed_shortcut.key}"
  end

  @spec process_keyboard_event(any(), map()) :: any()
  defp process_keyboard_event(
         %Raxol.Core.Events.Event{
           type: :keyboard_event,
           data: {:key, key, modifiers}
         },
         state
       ) do
    # Convert key to atom if needed
    key_atom = if is_binary(key), do: String.to_atom(key), else: key

    parsed = %{
      key: key_atom,
      modifiers: Enum.sort(modifiers || [])
    }

    key_str = shortcut_key(parsed)

    # Look for matching shortcut in active context first, then global
    shortcut = find_matching_shortcut(state, key_str)

    execute_shortcut_callback(shortcut)
  end

  @spec process_keyboard_event(any(), map()) :: any()
  defp process_keyboard_event(
         %Raxol.Core.Events.Event{type: :keyboard_event, data: key_data},
         state
       )
       when is_map(key_data) do
    key = key_data[:key]
    modifiers = key_data[:modifiers] || []

    parsed = %{
      key: key,
      modifiers: Enum.sort(modifiers)
    }

    key_str = shortcut_key(parsed)

    # Look for matching shortcut in active context first, then global
    shortcut = find_matching_shortcut(state, key_str)

    execute_shortcut_callback(shortcut)
  end

  @spec process_keyboard_event(any(), map()) :: any()
  defp process_keyboard_event(_event, _state), do: :ok

  @spec generate_help_text(map()) :: any()
  defp generate_help_text(state) do
    global_shortcuts = format_shortcuts_group("Global", state.shortcuts.global)

    context_help = generate_context_help(state)

    [global_shortcuts, context_help]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n\n")
  end

  @spec format_shortcuts_group(any(), any()) :: String.t()
  defp format_shortcuts_group(title, shortcuts) when map_size(shortcuts) > 0 do
    header = "Available keyboard shortcuts for #{title}:\n"

    shortcuts_text =
      shortcuts
      |> Enum.sort_by(fn {_key, def} -> def.priority end)
      |> Enum.map_join(
        "\n",
        fn {_key, def} ->
          "  #{def.raw}: #{def.description || def.name}"
        end
      )

    header <> shortcuts_text
  end

  @spec format_shortcuts_group(any(), any()) :: String.t()
  defp format_shortcuts_group(_title, _shortcuts), do: ""
end
