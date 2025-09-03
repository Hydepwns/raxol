defmodule Raxol.Core.UXRefinement.Server do
  @moduledoc """
  GenServer for managing UX refinement state.

  This server maintains all UX refinement state in a supervised, fault-tolerant manner,
  replacing the Process dictionary usage with proper OTP patterns.
  """

  use GenServer

  require Raxol.Core.Runtime.Log

  defstruct [
    :features,
    :hints,
    :metadata,
    :hint_config,
    :focus_ring_config
  ]

  # Client API

  @doc """
  Starts the UX refinement server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initialize the UX refinement system.
  """
  def init_system(server \\ __MODULE__) do
    GenServer.call(server, :init_system)
  end

  @doc """
  Enable a UX refinement feature.
  """
  def enable_feature(server \\ __MODULE__, feature, opts \\ [], user_prefs) do
    GenServer.call(server, {:enable_feature, feature, opts, user_prefs})
  end

  @doc """
  Disable a UX refinement feature.
  """
  def disable_feature(server \\ __MODULE__, feature) do
    GenServer.call(server, {:disable_feature, feature})
  end

  @doc """
  Check if a feature is enabled.
  """
  def feature_enabled?(server \\ __MODULE__, feature) do
    GenServer.call(server, {:feature_enabled?, feature})
  end

  @doc """
  Register a hint for a component.
  """
  def register_hint(server \\ __MODULE__, component_id, hint) do
    GenServer.call(server, {:register_hint, component_id, hint})
  end

  @doc """
  Register comprehensive hints for a component.
  """
  def register_component_hint(server \\ __MODULE__, component_id, hint_info) do
    GenServer.call(server, {:register_component_hint, component_id, hint_info})
  end

  @doc """
  Get the hint for a component.
  """
  def get_hint(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:get_hint, component_id})
  end

  @doc """
  Get a specific hint level for a component.
  """
  def get_component_hint(server \\ __MODULE__, component_id, level) do
    GenServer.call(server, {:get_component_hint, component_id, level})
  end

  @doc """
  Get shortcuts for a component.
  """
  def get_component_shortcuts(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:get_component_shortcuts, component_id})
  end

  @doc """
  Register accessibility metadata for a component.
  """
  def register_accessibility_metadata(
        server \\ __MODULE__,
        component_id,
        metadata
      ) do
    GenServer.call(
      server,
      {:register_accessibility_metadata, component_id, metadata}
    )
  end

  @doc """
  Get accessibility metadata for a component.
  """
  def get_accessibility_metadata(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:get_accessibility_metadata, component_id})
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      features: MapSet.new(),
      hints: %{},
      metadata: %{},
      hint_config: nil,
      focus_ring_config: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:init_system, _from, state) do
    # Initialize Events Manager
    Raxol.Core.Events.Manager.init()

    new_state = %{state | features: MapSet.new(), hints: %{}, metadata: %{}}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:enable_feature, feature, opts, user_prefs}, _from, state) do
    {result, new_state} = do_enable_feature(feature, opts, user_prefs, state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:disable_feature, feature}, _from, state) do
    {result, new_state} = do_disable_feature(feature, state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:feature_enabled?, feature}, _from, state) do
    enabled = MapSet.member?(state.features, feature)
    {:reply, enabled, state}
  end

  @impl GenServer
  def handle_call({:register_hint, component_id, hint}, _from, state) do
    new_state = do_register_hint(component_id, hint, state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(
        {:register_component_hint, component_id, hint_info},
        _from,
        state
      ) do
    new_state = do_register_component_hint(component_id, hint_info, state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_hint, component_id}, _from, state) do
    hint = get_hint_from_state(component_id, :basic, state)
    {:reply, hint, state}
  end

  @impl GenServer
  def handle_call({:get_component_hint, component_id, level}, _from, state) do
    hint = get_hint_from_state(component_id, level, state)
    {:reply, hint, state}
  end

  @impl GenServer
  def handle_call({:get_component_shortcuts, component_id}, _from, state) do
    shortcuts = get_shortcuts_from_state(component_id, state)
    {:reply, shortcuts, state}
  end

  @impl GenServer
  def handle_call(
        {:register_accessibility_metadata, component_id, metadata},
        _from,
        state
      ) do
    new_state =
      if MapSet.member?(state.features, :accessibility) do
        accessibility_module().register_element_metadata(component_id, metadata)
        %{state | metadata: Map.put(state.metadata, component_id, metadata)}
      else
        Raxol.Core.Runtime.Log.debug(
          "[UXRefinement] Accessibility not enabled, metadata registration skipped for #{component_id}"
        )

        state
      end

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_accessibility_metadata, component_id}, _from, state) do
    metadata =
      if MapSet.member?(state.features, :accessibility) do
        Map.get(state.metadata, component_id)
      else
        nil
      end

    {:reply, metadata, state}
  end

  # Private Functions

  defp do_enable_feature(:focus_management, _opts, user_prefs, state) do
    ensure_feature_enabled(:events, user_prefs, state)

    new_state = %{
      state
      | features: MapSet.put(state.features, :focus_management)
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:keyboard_navigation, _opts, user_prefs, state) do
    state = ensure_feature_enabled(:focus_management, user_prefs, state)
    Raxol.Core.KeyboardNavigator.init()

    new_state = %{
      state
      | features: MapSet.put(state.features, :keyboard_navigation)
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:hints, _opts, _user_prefs, state) do
    hint_config = Raxol.UI.Components.HintDisplay.init(%{})

    new_state = %{
      state
      | features: MapSet.put(state.features, :hints),
        hint_config: hint_config,
        hints: %{}
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:focus_ring, opts, user_prefs, state) do
    state = ensure_feature_enabled(:focus_management, user_prefs, state)
    focus_ring_opts = if is_list(opts) and opts == [], do: %{}, else: opts
    focus_ring_config = Raxol.UI.Components.FocusRing.init(focus_ring_opts)

    new_state = %{
      state
      | features: MapSet.put(state.features, :focus_ring),
        focus_ring_config: focus_ring_config
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:accessibility, opts, user_prefs, state) do
    state = ensure_feature_enabled(:events, user_prefs, state)
    accessibility_module().enable(opts, user_prefs)

    focus_manager_module().register_focus_change_handler(fn old, new ->
      handle_accessibility_focus_change(old, new, user_prefs, state)
    end)

    new_state = %{
      state
      | features: MapSet.put(state.features, :accessibility),
        metadata: %{}
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:keyboard_shortcuts, _opts, user_prefs, state) do
    keyboard_shortcuts_module().init()
    state = ensure_feature_enabled(:events, user_prefs, state)

    new_state = %{
      state
      | features: MapSet.put(state.features, :keyboard_shortcuts)
    }

    {:ok, new_state}
  end

  defp do_enable_feature(:events, _opts, _user_prefs, state) do
    Raxol.Core.Events.Manager.init()
    new_state = %{state | features: MapSet.put(state.features, :events)}
    {:ok, new_state}
  end

  defp do_enable_feature(unknown, _opts, _user_prefs, state) do
    {{:error, "Unknown feature: #{unknown}"}, state}
  end

  defp do_disable_feature(:hints, state) do
    new_state = %{
      state
      | features: MapSet.delete(state.features, :hints),
        hints: %{},
        hint_config: nil
    }

    {:ok, new_state}
  end

  defp do_disable_feature(:focus_ring, state) do
    new_state = %{
      state
      | features: MapSet.delete(state.features, :focus_ring),
        focus_ring_config: nil
    }

    {:ok, new_state}
  end

  defp do_disable_feature(:accessibility, state) do
    accessibility_module().disable(nil)

    focus_manager_module().unregister_focus_change_handler(fn old, new ->
      handle_accessibility_focus_change(old, new, nil, state)
    end)

    new_state = %{
      state
      | features: MapSet.delete(state.features, :accessibility),
        metadata: %{}
    }

    {:ok, new_state}
  end

  defp do_disable_feature(:keyboard_shortcuts, state) do
    keyboard_shortcuts_module().cleanup()

    new_state = %{
      state
      | features: MapSet.delete(state.features, :keyboard_shortcuts)
    }

    {:ok, new_state}
  end

  defp do_disable_feature(:events, state) do
    if MapSet.member?(state.features, :accessibility) ||
         MapSet.member?(state.features, :keyboard_shortcuts) do
      {{:error,
        "Cannot disable events while accessibility or keyboard shortcuts are enabled"},
       state}
    else
      Raxol.Core.Events.Manager.cleanup()
      new_state = %{state | features: MapSet.delete(state.features, :events)}
      {:ok, new_state}
    end
  end

  defp do_disable_feature(feature, state) do
    new_state = %{state | features: MapSet.delete(state.features, feature)}
    {:ok, new_state}
  end

  defp ensure_feature_enabled(feature, user_prefs, state) do
    if MapSet.member?(state.features, feature) do
      state
    else
      {_result, new_state} = do_enable_feature(feature, [], user_prefs, state)
      new_state
    end
  end

  defp do_register_hint(component_id, hint, state) when is_binary(hint) do
    do_register_component_hint(component_id, %{basic: hint}, state)
  end

  defp do_register_component_hint(component_id, hint_info, state)
       when is_binary(hint_info) do
    do_register_component_hint(component_id, %{basic: hint_info}, state)
  end

  defp do_register_component_hint(component_id, hint_info, state)
       when is_map(hint_info) do
    normalized_hint = normalize_hint_info(hint_info)
    new_hints = Map.put(state.hints, component_id, normalized_hint)

    # Register shortcuts if available
    maybe_register_shortcuts(component_id, normalized_hint, state)

    %{state | hints: new_hints}
  end

  defp get_hint_from_state(component_id, level, state) do
    case Map.get(state.hints, component_id) do
      nil -> nil
      hint_info -> Map.get(hint_info, level) || hint_info.basic
    end
  end

  defp get_shortcuts_from_state(component_id, state) do
    case Map.get(state.hints, component_id) do
      nil -> []
      hint_info -> hint_info.shortcuts || []
    end
  end

  defp normalize_hint_info(hint_info) when is_map(hint_info) do
    Map.merge(
      %{basic: nil, detailed: nil, examples: nil, shortcuts: []},
      hint_info
    )
  end

  defp normalize_hint_info(hint) when is_binary(hint) do
    %{basic: hint, detailed: nil, examples: nil, shortcuts: []}
  end

  defp maybe_register_shortcuts(component_id, %{shortcuts: shortcuts}, state)
       when is_list(shortcuts) do
    if MapSet.member?(state.features, :keyboard_shortcuts) do
      ks_module = keyboard_shortcuts_module()

      Enum.each(shortcuts, fn
        {key, description} when is_binary(key) and is_binary(description) ->
          shortcut_name = "#{component_id}_shortcut_#{key}"

          callback = fn ->
            Raxol.Core.Runtime.Log.debug(
              "Shortcut activated for #{component_id}: #{description}"
            )

            focus_manager_module().set_focus(component_id)
            :ok
          end

          ks_module.register_shortcut(key, shortcut_name, callback,
            description: description,
            context: component_id
          )

        _invalid ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Invalid shortcut format for component #{component_id}",
            %{}
          )
      end)
    end
  end

  defp maybe_register_shortcuts(_component_id, _hint_info, _state), do: :ok

  defp handle_accessibility_focus_change(
         old_focus,
         new_focus,
         user_prefs,
         state
       ) do
    if MapSet.member?(state.features, :accessibility) do
      metadata = Map.get(state.metadata, new_focus) || %{}
      label = Map.get(metadata, :label, new_focus)

      announcement =
        if is_nil(old_focus) do
          "Focus set to #{label}"
        else
          old_label =
            Map.get(state.metadata, old_focus, %{})
            |> Map.get(:label, old_focus)

          "Focus moved from #{old_label} to #{label}"
        end

      accessibility_module().announce(
        announcement,
        [priority: :low],
        user_prefs
      )
    end

    :ok
  end

  # Module helpers
  defp focus_manager_module do
    Application.get_env(:raxol, :focus_manager_impl, Raxol.Core.FocusManager)
  end

  defp accessibility_module do
    Application.get_env(:raxol, :accessibility_impl, Raxol.Core.Accessibility)
  end

  defp keyboard_shortcuts_module do
    Application.get_env(
      :raxol,
      :keyboard_shortcuts_module,
      Raxol.Core.KeyboardShortcuts
    )
  end
end
