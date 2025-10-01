defmodule Raxol.Core.KeyboardShortcuts.ShortcutsServer do
  @moduledoc """
  GenServer implementation for keyboard shortcuts management.

  Provides state management for keyboard shortcuts with context awareness,
  priority handling, and functional pattern resolution.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  defstruct [
    :shortcuts,
    :active_context,
    :enabled,
    :priority_maps
  ]

  @type t :: %__MODULE__{
          shortcuts: map(),
          active_context: atom(),
          enabled: boolean(),
          priority_maps: map()
        }

  # Client API

  @doc """
  Initialize shortcuts configuration.
  """
  def init_shortcuts(server) do
    GenServer.call(server, :init_shortcuts)
  end

  @doc """
  Register a keyboard shortcut.
  """
  def register_shortcut(server, shortcut, name, callback, opts \\ []) do
    GenServer.call(server, {:register_shortcut, shortcut, name, callback, opts})
  end

  @doc """
  Handle keyboard event.
  """
  def handle_keyboard_event(server, event) do
    GenServer.call(server, {:handle_keyboard_event, event})
  end

  @doc """
  Get active context.
  """
  def get_active_context(server) do
    GenServer.call(server, :get_active_context)
  end

  @doc """
  Get available shortcuts.
  """
  def get_available_shortcuts(server) do
    GenServer.call(server, :get_available_shortcuts)
  end

  @doc """
  Generate shortcuts help.
  """
  def generate_shortcuts_help do
    GenServer.call(__MODULE__, :generate_shortcuts_help)
  end

  def generate_shortcuts_help(server) do
    GenServer.call(server, :generate_shortcuts_help)
  end

  @doc """
  Get shortcuts for context.
  """
  def get_shortcuts_for_context(server, context) do
    GenServer.call(server, {:get_shortcuts_for_context, context})
  end

  @doc """
  Set active context.
  """
  def set_active_context(server, context) do
    GenServer.call(server, {:set_active_context, context})
  end

  @doc """
  Check if shortcuts are enabled.
  """
  def enabled?(server) do
    GenServer.call(server, :enabled?)
  end

  @doc """
  Clear all shortcuts.
  """
  def clear_all(server) do
    GenServer.call(server, :clear_all)
  end

  @doc """
  Clear context shortcuts.
  """
  def clear_context(server, context) do
    GenServer.call(server, {:clear_context, context})
  end

  @doc """
  Set conflict resolution strategy.
  """
  def set_conflict_resolution(server, strategy) do
    GenServer.call(server, {:set_conflict_resolution, strategy})
  end

  @doc """
  Set enabled state.
  """
  def set_enabled(server, enabled) do
    GenServer.call(server, {:set_enabled, enabled})
  end

  @doc """
  Unregister a shortcut.
  """
  def unregister_shortcut(server, shortcut, context \\ :global) do
    GenServer.call(server, {:unregister_shortcut, shortcut, context})
  end

  # Server Callbacks

  @impl true
  def init_manager(_opts) do
    state = %__MODULE__{
      shortcuts: %{},
      active_context: :global,
      enabled: true,
      priority_maps: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_manager_call(:init_shortcuts, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_manager_call(
        {:register_shortcut, shortcut, name, callback, opts},
        _from,
        state
      ) do
    context = Keyword.get(opts, :context, :global)
    priority = Keyword.get(opts, :priority, 0)

    shortcut_entry = %{
      name: name,
      callback: callback,
      context: context,
      priority: priority,
      shortcut: shortcut
    }

    new_shortcuts =
      Map.put(state.shortcuts, {context, shortcut}, shortcut_entry)

    new_state = %{state | shortcuts: new_shortcuts}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:handle_keyboard_event, event}, _from, state) do
    result = process_keyboard_event(state, event)
    {:reply, result, state}
  end

  @impl true
  def handle_manager_call(:get_active_context, _from, state) do
    {:reply, state.active_context, state}
  end

  @impl true
  def handle_manager_call(:get_available_shortcuts, _from, state) do
    shortcuts =
      filter_shortcuts_by_context(state.shortcuts, state.active_context)

    {:reply, shortcuts, state}
  end

  @impl true
  def handle_manager_call(:generate_shortcuts_help, _from, state) do
    help_text = build_shortcuts_help(state.shortcuts, state.active_context)
    {:reply, help_text, state}
  end

  @impl true
  def handle_manager_call({:get_shortcuts_for_context, context}, _from, state) do
    shortcuts = filter_shortcuts_by_context(state.shortcuts, context)
    {:reply, shortcuts, state}
  end

  @impl true
  def handle_manager_call({:set_active_context, context}, _from, state) do
    new_state = %{state | active_context: context}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_manager_call(:clear_all, _from, state) do
    new_state = %{state | shortcuts: %{}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:clear_context, context}, _from, state) do
    new_shortcuts =
      state.shortcuts
      |> Enum.reject(fn {{ctx, _key}, _entry} -> ctx == context end)
      |> Map.new()

    new_state = %{state | shortcuts: new_shortcuts}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:set_conflict_resolution, strategy}, _from, state) do
    # Add conflict resolution strategy to state
    new_state = Map.put(state, :conflict_resolution, strategy)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:set_enabled, enabled}, _from, state) do
    new_state = %{state | enabled: enabled}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:unregister_shortcut, shortcut, context},
        _from,
        state
      ) do
    key = {context, shortcut}
    new_shortcuts = Map.delete(state.shortcuts, key)
    new_state = %{state | shortcuts: new_shortcuts}
    {:reply, :ok, new_state}
  end

  # Private Functions

  defp process_keyboard_event(state, event) do
    case state.enabled do
      false -> :not_handled
      true -> find_and_execute_shortcut(state, event)
    end
  end

  defp find_and_execute_shortcut(state, event) do
    key = {state.active_context, event}

    case Map.get(state.shortcuts, key) do
      nil ->
        # Try global context fallback
        global_key = {:global, event}

        case Map.get(state.shortcuts, global_key) do
          nil -> :not_handled
          entry -> execute_shortcut_callback(entry)
        end

      entry ->
        execute_shortcut_callback(entry)
    end
  end

  defp execute_shortcut_callback(entry) do
    try do
      case entry.callback do
        fun when is_function(fun, 0) -> fun.()
        fun when is_function(fun, 1) -> fun.(entry)
        {module, function, args} -> apply(module, function, args)
        _ -> :invalid_callback
      end

      :handled
    rescue
      error ->
        Log.module_warning("Shortcut callback error: #{inspect(error)}")
        :callback_error
    end
  end

  defp filter_shortcuts_by_context(shortcuts, context) do
    shortcuts
    |> Enum.filter(fn {{ctx, _key}, _entry} ->
      ctx == context or ctx == :global
    end)
    |> Map.new()
  end

  defp build_shortcuts_help(shortcuts, active_context) do
    relevant_shortcuts = filter_shortcuts_by_context(shortcuts, active_context)

    relevant_shortcuts
    |> Enum.map(fn {{_context, key}, entry} ->
      "#{format_key(key)}: #{entry.name}"
    end)
    |> Enum.sort()
    |> Enum.join("\n")
  end

  defp format_key(key) when is_binary(key), do: key
  defp format_key(key), do: inspect(key)
end
