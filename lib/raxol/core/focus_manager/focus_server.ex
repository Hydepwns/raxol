defmodule Raxol.Core.FocusManager.FocusServer do
  @moduledoc """
  GenServer implementation for focus management in Raxol terminal UI applications.

  This server provides a pure functional approach to focus management, eliminating
  Process dictionary usage and implementing proper OTP supervision patterns.

  ## Features
  - Tab-based keyboard navigation with proper state management
  - Focus history tracking in GenServer state
  - Focus ring rendering support
  - Screen reader announcements via events
  - Supervised state management with fault tolerance

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    focusables: %{group_name => [focusable_components]},
    active_element: String.t() | nil,
    focus_history: [String.t()],
    last_group: atom() | nil,
    focus_change_handlers: [function()]
  }
  ```
  """

  use GenServer
  require Logger
  alias Raxol.Core.Events.EventManager, as: EventManager

  @default_state %{
    focusables: %{},
    active_element: nil,
    focus_history: [],
    last_group: nil,
    focus_change_handlers: []
  }

  # Client API

  @doc """
  Starts the FocusManager server with optional initial state.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    initial_state = Keyword.get(opts, :initial_state, @default_state)
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Registers a focusable component with the focus manager.
  """
  def register_focusable(
        server \\ __MODULE__,
        component_id,
        tab_index,
        opts \\ []
      ) do
    GenServer.call(server, {:register_focusable, component_id, tab_index, opts})
  end

  @doc """
  Unregisters a focusable component.
  """
  def unregister_focusable(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:unregister_focusable, component_id})
  end

  @doc """
  Sets the initial focus to a specific component.
  """
  def set_initial_focus(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:set_initial_focus, component_id})
  end

  @doc """
  Sets focus to a specific component.
  """
  def set_focus(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:set_focus, component_id})
  end

  @doc """
  Moves focus to the next focusable element.
  """
  def focus_next(server \\ __MODULE__, opts \\ []) do
    GenServer.call(server, {:focus_next, opts})
  end

  @doc """
  Moves focus to the previous focusable element.
  """
  def focus_previous(server \\ __MODULE__, opts \\ []) do
    GenServer.call(server, {:focus_previous, opts})
  end

  @doc """
  Gets the ID of the currently focused element.
  """
  def get_focused_element(server \\ __MODULE__) do
    GenServer.call(server, :get_focused_element)
  end

  @doc """
  Gets the focus history.
  """
  def get_focus_history(server \\ __MODULE__) do
    GenServer.call(server, :get_focus_history)
  end

  @doc """
  Checks if a component has focus.
  """
  def has_focus?(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:has_focus, component_id})
  end

  @doc """
  Returns to the previously focused element.
  """
  def return_to_previous(server \\ __MODULE__) do
    GenServer.call(server, :return_to_previous)
  end

  @doc """
  Enables a previously disabled focusable component.
  """
  def enable_component(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:enable_component, component_id})
  end

  @doc """
  Disables a focusable component.
  """
  def disable_component(server \\ __MODULE__, component_id) do
    GenServer.call(server, {:disable_component, component_id})
  end

  @doc """
  Registers a handler function to be called when focus changes.
  """
  def register_focus_change_handler(server \\ __MODULE__, handler_fun)
      when is_function(handler_fun, 2) do
    GenServer.call(server, {:register_focus_change_handler, handler_fun})
  end

  @doc """
  Unregisters a focus change handler function.
  """
  def unregister_focus_change_handler(server \\ __MODULE__, handler_fun)
      when is_function(handler_fun, 2) do
    GenServer.call(server, {:unregister_focus_change_handler, handler_fun})
  end

  @doc """
  Gets the next focusable element after the given one.
  """
  def get_next_focusable(server \\ __MODULE__, current_focus_id) do
    GenServer.call(server, {:get_next_focusable, current_focus_id})
  end

  @doc """
  Gets the previous focusable element before the given one.
  """
  def get_previous_focusable(server \\ __MODULE__, current_focus_id) do
    GenServer.call(server, {:get_previous_focusable, current_focus_id})
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
  def handle_call(
        {:register_focusable, component_id, tab_index, opts},
        _from,
        state
      ) do
    group = Keyword.get(opts, :group, :default)
    disabled = Keyword.get(opts, :disabled, false)
    announce = Keyword.get(opts, :announce, nil)

    focusable = %{
      id: component_id,
      tab_index: tab_index,
      group: group,
      disabled: disabled,
      announce: announce
    }

    updated_focusables =
      Map.update(
        state.focusables,
        group,
        [focusable],
        fn existing ->
          [focusable | existing]
          |> Enum.sort_by(& &1.tab_index)
        end
      )

    new_state = %{state | focusables: updated_focusables}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unregister_focusable, component_id}, _from, state) do
    updated_focusables =
      state.focusables
      |> Enum.map(fn {group, components} ->
        updated_components =
          Enum.reject(components, fn c -> c.id == component_id end)

        {group, updated_components}
      end)
      |> Enum.into(%{})

    new_state = %{state | focusables: updated_focusables}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_initial_focus, component_id}, _from, state) do
    new_state = handle_initial_focus_update(state, component_id)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_focus, component_id}, _from, state) do
    new_state = do_set_focus(state, component_id)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:focus_next, opts}, _from, state) do
    new_state = do_focus_next(state, opts)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:focus_previous, opts}, _from, state) do
    new_state = do_focus_previous(state, opts)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_focused_element, _from, state) do
    {:reply, state.active_element, state}
  end

  @impl GenServer
  def handle_call(:get_focus_history, _from, state) do
    {:reply, state.focus_history, state}
  end

  @impl GenServer
  def handle_call({:has_focus, component_id}, _from, state) do
    {:reply, state.active_element == component_id, state}
  end

  @impl GenServer
  def handle_call(:return_to_previous, _from, state) do
    new_state = do_return_to_previous(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:enable_component, component_id}, _from, state) do
    new_state = update_component_state(state, component_id, :disabled, false)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:disable_component, component_id}, _from, state) do
    new_state = update_component_state(state, component_id, :disabled, true)

    # If this component is currently focused, move focus elsewhere
    new_state = handle_disabled_focus(new_state, component_id)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_focus_change_handler, handler_fun}, _from, state) do
    new_handlers = [handler_fun | state.focus_change_handlers]
    new_state = %{state | focus_change_handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unregister_focus_change_handler, handler_fun}, _from, state) do
    new_handlers = List.delete(state.focus_change_handlers, handler_fun)
    new_state = %{state | focus_change_handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_next_focusable, current_focus_id}, _from, state) do
    next_id = calculate_next_focusable(state, current_focus_id)
    {:reply, next_id, state}
  end

  @impl GenServer
  def handle_call({:get_previous_focusable, current_focus_id}, _from, state) do
    prev_id = calculate_previous_focusable(state, current_focus_id)
    {:reply, prev_id, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private Helper Functions

  @spec do_set_focus(map(), String.t() | integer()) :: any()
  defp do_set_focus(state, component_id) do
    old_focus = state.active_element
    apply_focus_change(state, old_focus, component_id)
  end

  @spec do_focus_next(map(), keyword()) :: any()
  defp do_focus_next(state, opts) do
    navigate_focus(state, opts, :next)
  end

  @spec do_focus_previous(map(), keyword()) :: any()
  defp do_focus_previous(state, opts) do
    navigate_focus(state, opts, :previous)
  end

  @spec do_return_to_previous(map()) :: any()
  defp do_return_to_previous(state) do
    case state.focus_history do
      [prev | rest] when is_binary(prev) ->
        component = find_component(state.focusables, prev)

        # Update state
        new_state = %{
          state
          | active_element: prev,
            focus_history: rest
        }

        # Send focus change event
        EventManager.dispatch({:focus_change, state.active_element, prev})

        # Call registered handlers
        Enum.each(new_state.focus_change_handlers, fn handler ->
          handler.(state.active_element, prev)
        end)

        # Announce focus change if configured
        announce_if_configured(component)

        new_state

      _ ->
        state
    end
  end

  @spec update_component_state(map(), String.t() | integer(), any(), any()) ::
          any()
  defp update_component_state(state, component_id, field, value) do
    updated_focusables =
      state.focusables
      |> Enum.map(fn {group, components} ->
        updated_components =
          Enum.map(components, fn component ->
            update_component_field(component, component_id, field, value)
          end)

        {group, updated_components}
      end)
      |> Enum.into(%{})

    %{state | focusables: updated_focusables}
  end

  @spec find_component(any(), String.t() | integer()) :: any()
  defp find_component(focusables, component_id) do
    focusables
    |> Map.values()
    |> List.flatten()
    |> Enum.find(fn c -> c.id == component_id end)
  end

  @spec find_next_enabled_component(any(), any(), any()) :: any()
  defp find_next_enabled_component([], _current_index, _wrap), do: nil

  @spec find_next_enabled_component(any(), any(), any()) :: any()
  defp find_next_enabled_component(components, current_index, wrap) do
    component_count = length(components)
    start_index = calculate_next_start_index(current_index, component_count)

    find_enabled_component_from_index(
      components,
      start_index,
      1,
      component_count,
      wrap
    )
  end

  @spec find_prev_enabled_component(any(), any(), any()) :: any()
  defp find_prev_enabled_component([], _current_index, _wrap), do: nil

  @spec find_prev_enabled_component(any(), any(), any()) :: any()
  defp find_prev_enabled_component(components, current_index, wrap) do
    component_count = length(components)

    start_index =
      calculate_previous_start_index(current_index, component_count, wrap)

    find_enabled_component_from_index(
      components,
      start_index,
      -1,
      component_count,
      wrap
    )
  end

  @spec find_enabled_component_from_index(
          any(),
          any(),
          any(),
          non_neg_integer(),
          any()
        ) :: any()
  defp find_enabled_component_from_index(
         _components,
         start_index,
         _step,
         count,
         _wrap
       )
       when start_index < 0 or start_index >= count,
       do: nil

  @spec find_enabled_component_from_index(
          any(),
          any(),
          any(),
          non_neg_integer(),
          any()
        ) :: any()
  defp find_enabled_component_from_index(
         components,
         start_index,
         step,
         count,
         wrap
       ) do
    Enum.reduce_while(0..(count - 1), nil, fn i, _acc ->
      index = rem(start_index + i * step + count, count)
      component = Enum.at(components, index)

      check_component_iteration(component, i, count, wrap)
    end)
  end

  @spec calculate_next_focusable(map(), String.t() | integer()) :: any()
  defp calculate_next_focusable(state, current_focus_id) do
    group = state.last_group || :default
    components = Map.get(state.focusables, group, [])

    current_index = get_component_index(components, current_focus_id)

    next_component =
      find_next_enabled_component(components, current_index, true)

    extract_component_id(next_component)
  end

  @spec calculate_previous_focusable(map(), String.t() | integer()) :: any()
  defp calculate_previous_focusable(state, current_focus_id) do
    group = state.last_group || :default
    components = Map.get(state.focusables, group, [])

    current_index = get_prev_component_index(components, current_focus_id)

    prev_component =
      find_prev_enabled_component(components, current_index, true)

    extract_component_id(prev_component)
  end

  # Helper functions for pattern matching refactoring

  @spec determine_focus_group(any(), any()) :: any()
  defp determine_focus_group(group_opt, _last_group) when group_opt != nil,
    do: group_opt

  @spec determine_focus_group(any(), any()) :: any()
  defp determine_focus_group(_group_opt, last_group) when last_group != nil,
    do: last_group

  @spec determine_focus_group(any(), any()) :: any()
  defp determine_focus_group(_group_opt, _last_group), do: :default

  @spec calculate_previous_start_index(any(), any(), any()) :: any()
  defp calculate_previous_start_index(nil, component_count, _wrap),
    do: component_count - 1

  @spec calculate_previous_start_index(any(), any(), any()) :: any()
  defp calculate_previous_start_index(current_index, component_count, true)
       when current_index <= 0,
       do: component_count - 1

  @spec calculate_previous_start_index(any(), any(), any()) :: any()
  defp calculate_previous_start_index(current_index, _component_count, false)
       when current_index <= 0,
       do: -1

  @spec calculate_previous_start_index(any(), any(), any()) :: any()
  defp calculate_previous_start_index(current_index, _component_count, _wrap),
    do: current_index - 1

  @spec check_component_iteration(any(), any(), any(), any()) :: any()
  defp check_component_iteration(%{disabled: true}, _i, _count, _wrap),
    do: {:cont, nil}

  @spec check_component_iteration(any(), any(), any(), any()) :: any()
  defp check_component_iteration(component, _i, _count, _wrap)
       when component != nil do
    {:halt, component}
  end

  @spec check_component_iteration(any(), any(), non_neg_integer(), any()) ::
          any()
  defp check_component_iteration(_component, i, count, false)
       when i == count - 1,
       do: {:halt, nil}

  @spec check_component_iteration(any(), any(), non_neg_integer(), any()) ::
          any()
  defp check_component_iteration(_component, i, count, _wrap)
       when i == count - 1,
       do: {:halt, nil}

  @spec check_component_iteration(any(), any(), any(), any()) :: any()
  defp check_component_iteration(_component, _i, _count, _wrap),
    do: {:cont, nil}

  # New helper functions for refactored code
  @spec handle_initial_focus_update(any(), String.t() | integer()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_initial_focus_update(
         %{active_element: current} = state,
         component_id
       )
       when current == component_id,
       do: state

  @spec handle_initial_focus_update(map(), String.t() | integer()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_initial_focus_update(state, component_id) do
    do_set_focus(state, component_id)
  end

  @spec apply_focus_change(any(), any(), any()) :: any()
  defp apply_focus_change(
         %{active_element: old_focus} = state,
         old_focus,
         old_focus
       ),
       do: state

  @spec apply_focus_change(map(), any(), String.t() | integer()) :: any()
  defp apply_focus_change(state, old_focus, component_id) do
    component = find_component(state.focusables, component_id)
    process_focus_change(state, old_focus, component_id, component)
  end

  @spec process_focus_change(map(), any(), String.t() | integer(), any()) ::
          any()
  defp process_focus_change(state, _old_focus, _component_id, nil), do: state

  @spec process_focus_change(map(), any(), String.t() | integer(), any()) ::
          any()
  defp process_focus_change(state, old_focus, component_id, component) do
    # Update focus history
    updated_history = build_focus_history(old_focus, state.focus_history)

    # Update state
    new_state = %{
      state
      | active_element: component_id,
        focus_history: updated_history,
        last_group: component.group
    }

    # Send focus change event
    EventManager.dispatch({:focus_change, old_focus, component_id})

    # Call registered handlers
    Enum.each(new_state.focus_change_handlers, fn handler ->
      handler.(old_focus, component_id)
    end)

    # Announce focus change if configured
    announce_if_configured(component)

    new_state
  end

  @spec build_focus_history(any(), any()) :: any()
  defp build_focus_history(nil, history), do: history

  @spec build_focus_history(any(), any()) :: any()
  defp build_focus_history(old_focus, history) do
    [old_focus | history] |> Enum.take(10)
  end

  @spec announce_if_configured(any()) :: any()
  defp announce_if_configured(%{announce: nil}), do: :ok

  @spec announce_if_configured(any()) :: any()
  defp announce_if_configured(%{announce: announcement}) do
    EventManager.dispatch({:accessibility_announce, announcement})
  end

  @spec announce_if_configured(any()) :: any()
  defp announce_if_configured(_), do: :ok

  @spec handle_disabled_focus(any(), String.t() | integer()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_disabled_focus(
         %{active_element: component_id} = state,
         component_id
       ) do
    do_focus_next(state, [])
  end

  @spec handle_disabled_focus(map(), String.t() | integer()) ::
          {:ok, any()}
          | {:error, any()}
          | {:reply, any(), any()}
          | {:noreply, any()}
  defp handle_disabled_focus(state, _component_id), do: state

  @spec navigate_focus(any(), keyword(), any()) :: any()
  defp navigate_focus(%{active_element: nil} = state, _opts, _direction),
    do: state

  @spec navigate_focus(map(), keyword(), any()) :: any()
  defp navigate_focus(state, opts, direction) do
    group_opt = Keyword.get(opts, :group, nil)
    wrap = Keyword.get(opts, :wrap, true)

    group = determine_focus_group(group_opt, state.last_group)
    components = Map.get(state.focusables, group, [])

    current_index =
      Enum.find_index(components, &(&1.id == state.active_element))

    next_component =
      find_component_by_direction(components, current_index, wrap, direction)

    update_focus_with_component(state, next_component)
  end

  @spec find_component_by_direction(any(), any(), any(), any()) :: any()
  defp find_component_by_direction(components, current_index, wrap, :next) do
    find_next_enabled_component(components, current_index, wrap)
  end

  @spec find_component_by_direction(any(), any(), any(), any()) :: any()
  defp find_component_by_direction(components, current_index, wrap, :previous) do
    find_prev_enabled_component(components, current_index, wrap)
  end

  @spec update_focus_with_component(map(), any()) :: any()
  defp update_focus_with_component(state, nil), do: state

  @spec update_focus_with_component(map(), any()) :: any()
  defp update_focus_with_component(state, component) do
    do_set_focus(state, component.id)
  end

  @spec update_component_field(any(), String.t() | integer(), any(), any()) ::
          any()
  defp update_component_field(
         %{id: component_id} = component,
         component_id,
         field,
         value
       ) do
    Map.put(component, field, value)
  end

  @spec update_component_field(any(), String.t() | integer(), any(), any()) ::
          any()
  defp update_component_field(component, _component_id, _field, _value),
    do: component

  @spec calculate_next_start_index(any(), any()) :: any()
  defp calculate_next_start_index(nil, _component_count), do: 0

  @spec calculate_next_start_index(any(), any()) :: any()
  defp calculate_next_start_index(current_index, component_count) do
    rem(current_index + 1, component_count)
  end

  @spec get_component_index(any(), any()) :: any() | nil
  defp get_component_index(_components, nil), do: -1

  @spec get_component_index(any(), String.t() | integer()) :: any() | nil
  defp get_component_index(components, current_focus_id) do
    Enum.find_index(components, fn c -> c.id == current_focus_id end) || -1
  end

  @spec get_prev_component_index(any(), any()) :: any() | nil
  defp get_prev_component_index(components, nil), do: length(components)

  @spec get_prev_component_index(any(), String.t() | integer()) :: any() | nil
  defp get_prev_component_index(components, current_focus_id) do
    Enum.find_index(components, fn c -> c.id == current_focus_id end) || -1
  end

  @spec extract_component_id(any()) :: any()
  defp extract_component_id(nil), do: nil
  @spec extract_component_id(any()) :: any()
  defp extract_component_id(component), do: component.id
end
