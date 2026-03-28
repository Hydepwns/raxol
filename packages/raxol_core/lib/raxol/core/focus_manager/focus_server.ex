defmodule Raxol.Core.FocusManager.FocusServer do
  @moduledoc """
  GenServer implementation for focus management.

  Provides accessibility focus management with tab ordering,
  focus history, and component registration.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  defstruct [
    :focusable_components,
    :current_focus,
    :focus_history,
    :focus_handlers,
    :enabled_components,
    :tab_order
  ]

  @type t :: %__MODULE__{
          focusable_components: map(),
          current_focus: binary() | nil,
          focus_history: list(),
          focus_handlers: list(),
          enabled_components: MapSet.t(),
          tab_order: list()
        }

  # Client API
  # BaseManager provides start_link/1 and start_link/2 automatically

  @doc """
  Register a focusable component.
  """
  def register_focusable(server, component_id, tab_index, opts \\ []) do
    GenServer.call(server, {:register_focusable, component_id, tab_index, opts})
  end

  @doc """
  Unregister a focusable component.
  """
  def unregister_focusable(server, component_id) do
    GenServer.call(server, {:unregister_focusable, component_id})
  end

  @doc """
  Set initial focus.
  """
  def set_initial_focus(server, component_id) do
    GenServer.call(server, {:set_initial_focus, component_id})
  end

  @doc """
  Set focus to a component.
  """
  def set_focus(server, component_id) do
    GenServer.call(server, {:set_focus, component_id})
  end

  @doc """
  Focus next component in tab order.
  """
  def focus_next(server, opts \\ []) do
    GenServer.call(server, {:focus_next, opts})
  end

  @doc """
  Focus previous component in tab order.
  """
  def focus_previous(server, opts \\ []) do
    GenServer.call(server, {:focus_previous, opts})
  end

  @doc """
  Get currently focused element.
  """
  def get_focused_element(server) do
    GenServer.call(server, :get_focused_element)
  end

  @doc """
  Get focus history.
  """
  def get_focus_history(server) do
    GenServer.call(server, :get_focus_history)
  end

  @doc """
  Get next focusable component.
  """
  def get_next_focusable(server, current_focus_id) do
    GenServer.call(server, {:get_next_focusable, current_focus_id})
  end

  @doc """
  Get previous focusable component.
  """
  def get_previous_focusable(server, current_focus_id) do
    GenServer.call(server, {:get_previous_focusable, current_focus_id})
  end

  @doc """
  Check if component has focus.
  """
  def has_focus?(server, component_id) do
    GenServer.call(server, {:has_focus?, component_id})
  end

  @doc """
  Return to previous focus.
  """
  def return_to_previous(server) do
    GenServer.call(server, :return_to_previous)
  end

  @doc """
  Enable a component for focus.
  """
  def enable_component(server, component_id) do
    GenServer.call(server, {:enable_component, component_id})
  end

  @doc """
  Disable a component from focus.
  """
  def disable_component(server, component_id) do
    GenServer.call(server, {:disable_component, component_id})
  end

  @doc """
  Register focus change handler.
  """
  def register_focus_change_handler(server, handler_fun) do
    GenServer.call(server, {:register_focus_change_handler, handler_fun})
  end

  @doc """
  Unregister focus change handler.
  """
  def unregister_focus_change_handler(server, handler_fun) do
    GenServer.call(server, {:unregister_focus_change_handler, handler_fun})
  end

  # Server Callbacks

  @impl true
  def init_manager(_opts) do
    state = %__MODULE__{
      focusable_components: %{},
      current_focus: nil,
      focus_history: [],
      focus_handlers: [],
      enabled_components: MapSet.new(),
      tab_order: []
    }

    {:ok, state}
  end

  @impl true
  def handle_manager_call(
        {:register_focusable, component_id, tab_index, opts},
        _from,
        state
      ) do
    component_info = %{
      id: component_id,
      tab_index: tab_index,
      opts: opts
    }

    new_components =
      Map.put(state.focusable_components, component_id, component_info)

    new_enabled = MapSet.put(state.enabled_components, component_id)
    new_tab_order = rebuild_tab_order(new_components)

    new_state = %{
      state
      | focusable_components: new_components,
        enabled_components: new_enabled,
        tab_order: new_tab_order
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:unregister_focusable, component_id}, _from, state) do
    new_components = Map.delete(state.focusable_components, component_id)
    new_enabled = MapSet.delete(state.enabled_components, component_id)
    new_tab_order = rebuild_tab_order(new_components)

    # Remove from current focus if it was focused
    new_current_focus =
      case state.current_focus do
        ^component_id -> nil
        other -> other
      end

    new_state = %{
      state
      | focusable_components: new_components,
        enabled_components: new_enabled,
        tab_order: new_tab_order,
        current_focus: new_current_focus
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:set_initial_focus, component_id}, _from, state) do
    case validate_component_focusable(state, component_id) do
      true ->
        new_state = %{state | current_focus: component_id}
        notify_focus_change(new_state, nil, component_id)
        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :component_not_focusable}, state}
    end
  end

  @impl true
  def handle_manager_call({:set_focus, component_id}, _from, state) do
    case validate_component_focusable(state, component_id) do
      true ->
        old_focus = state.current_focus
        new_history = add_to_history(state.focus_history, old_focus)

        new_state = %{
          state
          | current_focus: component_id,
            focus_history: new_history
        }

        notify_focus_change(new_state, old_focus, component_id)
        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :component_not_focusable}, state}
    end
  end

  @impl true
  def handle_manager_call({:focus_next, _opts}, _from, state) do
    next_component = find_next_component(state)

    case next_component do
      nil ->
        {:reply, {:error, :no_next_component}, state}

      component_id ->
        old_focus = state.current_focus
        new_history = add_to_history(state.focus_history, old_focus)

        new_state = %{
          state
          | current_focus: component_id,
            focus_history: new_history
        }

        notify_focus_change(new_state, old_focus, component_id)
        {:reply, {:ok, component_id}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:focus_previous, _opts}, _from, state) do
    prev_component = find_previous_component(state)

    case prev_component do
      nil ->
        {:reply, {:error, :no_previous_component}, state}

      component_id ->
        old_focus = state.current_focus
        new_history = add_to_history(state.focus_history, old_focus)

        new_state = %{
          state
          | current_focus: component_id,
            focus_history: new_history
        }

        notify_focus_change(new_state, old_focus, component_id)
        {:reply, {:ok, component_id}, new_state}
    end
  end

  @impl true
  def handle_manager_call(:get_focused_element, _from, state) do
    {:reply, state.current_focus, state}
  end

  @impl true
  def handle_manager_call(:get_focus_history, _from, state) do
    {:reply, state.focus_history, state}
  end

  @impl true
  def handle_manager_call({:get_next_focusable, current_focus_id}, _from, state) do
    next_component =
      find_next_component(%{state | current_focus: current_focus_id})

    {:reply, next_component, state}
  end

  @impl true
  def handle_manager_call(
        {:get_previous_focusable, current_focus_id},
        _from,
        state
      ) do
    prev_component =
      find_previous_component(%{state | current_focus: current_focus_id})

    {:reply, prev_component, state}
  end

  @impl true
  def handle_manager_call({:has_focus?, component_id}, _from, state) do
    has_focus = state.current_focus == component_id
    {:reply, has_focus, state}
  end

  @impl true
  def handle_manager_call(:return_to_previous, _from, state) do
    case state.focus_history do
      [previous | rest] ->
        old_focus = state.current_focus

        new_state = %{
          state
          | current_focus: previous,
            focus_history: rest
        }

        notify_focus_change(new_state, old_focus, previous)
        {:reply, {:ok, previous}, new_state}

      [] ->
        {:reply, {:error, :no_previous_focus}, state}
    end
  end

  @impl true
  def handle_manager_call({:enable_component, component_id}, _from, state) do
    new_enabled = MapSet.put(state.enabled_components, component_id)
    new_state = %{state | enabled_components: new_enabled}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:disable_component, component_id}, _from, state) do
    new_enabled = MapSet.delete(state.enabled_components, component_id)

    # Remove focus if currently focused
    new_current_focus =
      case state.current_focus do
        ^component_id -> nil
        other -> other
      end

    new_state = %{
      state
      | enabled_components: new_enabled,
        current_focus: new_current_focus
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:register_focus_change_handler, handler_fun},
        _from,
        state
      ) do
    new_handlers = [handler_fun | state.focus_handlers]
    new_state = %{state | focus_handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:unregister_focus_change_handler, handler_fun},
        _from,
        state
      ) do
    new_handlers = List.delete(state.focus_handlers, handler_fun)
    new_state = %{state | focus_handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  # Private Functions

  defp validate_component_focusable(state, component_id) do
    Map.has_key?(state.focusable_components, component_id) and
      MapSet.member?(state.enabled_components, component_id)
  end

  defp rebuild_tab_order(components) do
    components
    |> Map.values()
    |> Enum.sort_by(& &1.tab_index)
    |> Enum.map(& &1.id)
  end

  defp find_next_component(state) do
    case state.current_focus do
      nil ->
        # No current focus, return first component
        Enum.find(
          state.tab_order,
          &MapSet.member?(state.enabled_components, &1)
        )

      current ->
        current_index = Enum.find_index(state.tab_order, &(&1 == current))

        case current_index do
          nil ->
            # Current focus not in tab order, return first
            Enum.find(
              state.tab_order,
              &MapSet.member?(state.enabled_components, &1)
            )

          index ->
            # Find next enabled component after current
            state.tab_order
            |> Enum.drop(index + 1)
            |> Enum.find(&MapSet.member?(state.enabled_components, &1))
            |> find_next_or_wrap_to_first(
              state.tab_order,
              state.enabled_components
            )
        end
    end
  end

  defp find_previous_component(state) do
    case state.current_focus do
      nil ->
        # No current focus, return last component
        state.tab_order
        |> Enum.reverse()
        |> Enum.find(&MapSet.member?(state.enabled_components, &1))

      current ->
        current_index = Enum.find_index(state.tab_order, &(&1 == current))

        case current_index do
          nil ->
            # Current focus not in tab order, return last
            state.tab_order
            |> Enum.reverse()
            |> Enum.find(&MapSet.member?(state.enabled_components, &1))

          0 ->
            # At first position, wrap to last
            state.tab_order
            |> Enum.reverse()
            |> Enum.find(&MapSet.member?(state.enabled_components, &1))

          index ->
            # Find previous enabled component before current
            state.tab_order
            |> Enum.take(index)
            |> Enum.reverse()
            |> Enum.find(&MapSet.member?(state.enabled_components, &1))
        end
    end
  end

  defp add_to_history(history, nil), do: history

  defp add_to_history(history, focus_id) do
    [focus_id | Enum.take(history, 9)]
  end

  defp notify_focus_change(state, old_focus, new_focus) do
    Enum.each(state.focus_handlers, fn handler ->
      try do
        handler.(old_focus, new_focus)
      rescue
        error ->
          Log.warning("Focus change handler error: #{inspect(error)}")
      end
    end)
  end

  defp find_next_or_wrap_to_first(
         found_component,
         tab_order,
         enabled_components
       ) do
    case found_component do
      nil ->
        # Wrap around to first
        Enum.find(tab_order, &MapSet.member?(enabled_components, &1))

      component ->
        component
    end
  end
end
