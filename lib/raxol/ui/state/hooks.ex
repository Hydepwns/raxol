defmodule Raxol.UI.State.Hooks do
  @moduledoc """
  React-style hooks system for Raxol UI components.

  Hooks allow you to use state and other features in functional components without
  writing a class-based component. They provide a more direct API to the concepts
  you already know: state, lifecycle, context, and refs.

  ## Available Hooks

  - `use_state/1` - Adds local state to a component
  - `use_effect/2` - Performs side effects and cleanup
  - `use_context/1` - Subscribes to context changes
  - `use_reducer/3` - Manages complex state with a reducer function
  - `use_memo/2` - Memoizes expensive calculations
  - `use_callback/2` - Memoizes functions to prevent unnecessary re-renders
  - `use_ref/1` - Creates a mutable reference
  - `use_imperative_handle/3` - Customizes instance values exposed to parent components

  ## Usage in Components

      defmodule MyComponent do
        use Raxol.UI.Components.Base.Component
        import Raxol.UI.State.Hooks
        
        def render(props, context) do
          # State hook
          {count, set_count} = use_state(0)
          
          # Effect hook for side effects
          use_effect(fn ->
            IO.puts("Count changed to: \#{count}")
            
            # Cleanup function (optional)
            fn -> IO.puts("Cleaning up effect") end
          end, [count])
          
          # Context hook
          theme = use_context(:theme_context)
          
          # Memoized computation
          expensive_value = use_memo(fn ->
            expensive_calculation(count)
          end, [count])
          
          button(
            label: "Count: \#{count}",
            on_click: fn -> set_count.(count + 1) end,
            theme: theme.colors.primary
          )
        end
      end
  """

  alias Raxol.UI.State.{Store, Context}

  # Hook state management
  defmodule HookState do
    @enforce_keys [:component_id, :hooks, :hook_index]
    defstruct [:component_id, :hooks, :hook_index, :effects, :cleanup_fns]

    def new(component_id) do
      %__MODULE__{
        component_id: component_id,
        hooks: %{},
        hook_index: 0,
        effects: [],
        cleanup_fns: []
      }
    end

    def next_hook_index(state) do
      %{state | hook_index: state.hook_index + 1}
    end

    def reset_hook_index(state) do
      %{state | hook_index: 0}
    end
  end

  # Individual hook state
  defmodule Hook do
    defstruct [:type, :value, :deps, :cleanup, :memoized]
  end

  @doc """
  useState hook - adds local state to a component.

  ## Examples

      {count, set_count} = use_state(0)
      {user, set_user} = use_state(%{name: "", email: ""})
      
      # Update state
      set_count.(count + 1)
      set_user.(fn user -> %{user | name: "John"} end)
  """
  def use_state(initial_value) do
    component_id = get_current_component_id()
    hook_state = get_hook_state(component_id)

    hook_key = hook_state.hook_index
    current_hook = Map.get(hook_state.hooks, hook_key)

    {current_value, updated_hooks} =
      case current_hook do
        nil ->
          # First time - initialize state
          new_hook = %Hook{type: :state, value: initial_value}
          {initial_value, Map.put(hook_state.hooks, hook_key, new_hook)}

        %Hook{type: :state, value: value} ->
          # Existing state
          {value, hook_state.hooks}
      end

    # Update hook state
    updated_hook_state =
      %{hook_state | hooks: updated_hooks}
      |> HookState.next_hook_index()

    set_hook_state(component_id, updated_hook_state)

    # Create setter function
    setter = fn new_value ->
      update_state_hook(component_id, hook_key, new_value)
    end

    {current_value, setter}
  end

  @doc """
  useEffect hook - performs side effects.

  ## Examples

      # Effect that runs on every render
      use_effect(fn ->
        IO.puts("Component rendered")
      end)
      
      # Effect with dependencies
      use_effect(fn ->
        fetch_user_data(user_id)
      end, [user_id])
      
      # Effect with cleanup
      use_effect(fn ->
        timer = :timer.send_interval(1000, self(), :tick)
        
        # Cleanup function
        fn -> :timer.cancel(timer) end
      end, [])
  """
  def use_effect(effect_fn, deps \\ []) when is_function(effect_fn) do
    component_id = get_current_component_id()
    hook_state = get_hook_state(component_id)

    hook_key = hook_state.hook_index
    current_hook = Map.get(hook_state.hooks, hook_key)

    should_run_effect =
      case current_hook do
        nil ->
          # First time - always run
          true

        %Hook{type: :effect, deps: old_deps} ->
          # Check if dependencies changed
          deps != old_deps
      end

    updated_hooks =
      if should_run_effect do
        # Clean up previous effect if exists
        if current_hook && current_hook.cleanup do
          try do
            current_hook.cleanup.()
          catch
            kind, reason ->
              require Logger

              Logger.error(
                "Error cleaning up effect: #{inspect(kind)}, #{inspect(reason)}"
              )
          end
        end

        # Run new effect
        cleanup_fn =
          try do
            case effect_fn.() do
              cleanup when is_function(cleanup, 0) -> cleanup
              _ -> nil
            end
          catch
            kind, reason ->
              require Logger

              Logger.error(
                "Error running effect: #{inspect(kind)}, #{inspect(reason)}"
              )

              nil
          end

        new_hook = %Hook{type: :effect, deps: deps, cleanup: cleanup_fn}
        Map.put(hook_state.hooks, hook_key, new_hook)
      else
        hook_state.hooks
      end

    # Update hook state
    updated_hook_state =
      %{hook_state | hooks: updated_hooks}
      |> HookState.next_hook_index()

    set_hook_state(component_id, updated_hook_state)

    :ok
  end

  @doc """
  useContext hook - subscribes to context changes.

  ## Examples

      theme = use_context(:theme_context)
      user = use_context(:user_context)
  """
  def use_context(context_name) do
    render_context = get_current_render_context()
    Context.use_context(render_context, context_name)
  end

  @doc """
  useReducer hook - manages complex state with a reducer function.

  ## Examples

      reducer = fn
        {:increment}, count -> count + 1
        {:decrement}, count -> count - 1
        {:set, value}, _count -> value
      end
      
      {state, dispatch} = use_reducer(reducer, 0)
      
      # Update state
      dispatch.({:increment})
      dispatch.({:set, 42})
  """
  def use_reducer(reducer_fn, initial_state, init_fn \\ nil)
      when is_function(reducer_fn, 2) do
    component_id = get_current_component_id()
    hook_state = get_hook_state(component_id)

    hook_key = hook_state.hook_index
    current_hook = Map.get(hook_state.hooks, hook_key)

    {current_state, updated_hooks} =
      case current_hook do
        nil ->
          # First time - initialize state
          initial =
            if init_fn && is_function(init_fn, 1) do
              init_fn.(initial_state)
            else
              initial_state
            end

          new_hook = %Hook{type: :reducer, value: {reducer_fn, initial}}
          {initial, Map.put(hook_state.hooks, hook_key, new_hook)}

        %Hook{type: :reducer, value: {_reducer, state}} ->
          # Existing reducer state
          {state, hook_state.hooks}
      end

    # Update hook state
    updated_hook_state =
      %{hook_state | hooks: updated_hooks}
      |> HookState.next_hook_index()

    set_hook_state(component_id, updated_hook_state)

    # Create dispatch function
    dispatch = fn action ->
      update_reducer_hook(component_id, hook_key, reducer_fn, action)
    end

    {current_state, dispatch}
  end

  @doc """
  useMemo hook - memoizes expensive calculations.

  ## Examples

      expensive_value = use_memo(fn ->
        expensive_calculation(data)
      end, [data])
      
      filtered_items = use_memo(fn ->
        Enum.filter(items, filter_fn)
      end, [items, filter_fn])
  """
  def use_memo(computation_fn, deps) when is_function(computation_fn, 0) do
    component_id = get_current_component_id()
    hook_state = get_hook_state(component_id)

    hook_key = hook_state.hook_index
    current_hook = Map.get(hook_state.hooks, hook_key)

    {memoized_value, updated_hooks} =
      case current_hook do
        nil ->
          # First time - compute value
          value = computation_fn.()
          new_hook = %Hook{type: :memo, value: value, deps: deps}
          {value, Map.put(hook_state.hooks, hook_key, new_hook)}

        %Hook{type: :memo, value: cached_value, deps: old_deps} ->
          if deps == old_deps do
            # Dependencies haven't changed - return cached value
            {cached_value, hook_state.hooks}
          else
            # Dependencies changed - recompute
            new_value = computation_fn.()
            updated_hook = %Hook{type: :memo, value: new_value, deps: deps}
            {new_value, Map.put(hook_state.hooks, hook_key, updated_hook)}
          end
      end

    # Update hook state
    updated_hook_state =
      %{hook_state | hooks: updated_hooks}
      |> HookState.next_hook_index()

    set_hook_state(component_id, updated_hook_state)

    memoized_value
  end

  @doc """
  useCallback hook - memoizes functions.

  ## Examples

      handle_click = use_callback(fn ->
        on_click.(item.id)
      end, [item.id, on_click])
      
      memoized_handler = use_callback(fn event ->
        handle_event(event, state)
      end, [state])
  """
  def use_callback(callback_fn, deps) when is_function(callback_fn) do
    use_memo(fn -> callback_fn end, deps)
  end

  @doc """
  useRef hook - creates a mutable reference.

  ## Examples

      input_ref = use_ref(nil)
      
      # Access current value
      current_input = input_ref.current
      
      # Update reference
      input_ref.current = new_input_element
  """
  def use_ref(initial_value \\ nil) do
    component_id = get_current_component_id()
    hook_state = get_hook_state(component_id)

    hook_key = hook_state.hook_index
    current_hook = Map.get(hook_state.hooks, hook_key)

    {ref_agent, updated_hooks} =
      case current_hook do
        nil ->
          # First time - create agent for mutable reference
          {:ok, agent} = Agent.start_link(fn -> %{current: initial_value} end)
          new_hook = %Hook{type: :ref, value: agent}
          {agent, Map.put(hook_state.hooks, hook_key, new_hook)}

        %Hook{type: :ref, value: agent} ->
          # Existing ref
          {agent, hook_state.hooks}
      end

    # Update hook state
    updated_hook_state =
      %{hook_state | hooks: updated_hooks}
      |> HookState.next_hook_index()

    set_hook_state(component_id, updated_hook_state)

    # Create ref object with current property
    %{
      current: Agent.get(ref_agent, & &1.current),
      set_current: fn value ->
        Agent.update(ref_agent, fn _state -> %{current: value} end)
      end
    }
  end

  @doc """
  Custom hook for managing form state.

  ## Examples

      {form_state, update_field, reset_form} = use_form(%{
        name: "",
        email: "",
        age: 0
      })
      
      # Update individual field
      update_field.(:name, "John Doe")
      
      # Reset form
      reset_form.()
  """
  def use_form(initial_values) do
    {state, set_state} = use_state(initial_values)

    update_field =
      use_callback(
        fn field, value ->
          set_state.(fn current_state ->
            Map.put(current_state, field, value)
          end)
        end,
        [set_state]
      )

    reset_form =
      use_callback(
        fn ->
          set_state.(initial_values)
        end,
        [initial_values, set_state]
      )

    {state, update_field, reset_form}
  end

  @doc """
  Custom hook for managing toggle state (boolean on/off).

  ## Examples

      {is_open, toggle, set_open, set_closed} = use_toggle(false)
      
      # Toggle state
      toggle.()
      
      # Set specific state
      set_open.()
      set_closed.()
  """
  def use_toggle(initial_value \\ false) do
    {state, set_state} = use_state(initial_value)

    toggle =
      use_callback(
        fn ->
          set_state.(not state)
        end,
        [state, set_state]
      )

    set_true =
      use_callback(
        fn ->
          set_state.(true)
        end,
        [set_state]
      )

    set_false =
      use_callback(
        fn ->
          set_state.(false)
        end,
        [set_state]
      )

    {state, toggle, set_true, set_false}
  end

  @doc """
  Custom hook for managing async data fetching.

  ## Examples

      {data, loading, error, refetch} = use_async(fn ->
        HTTPoison.get("https://api.example.com/users")
      end, [])
      
      cond do
        loading ->
          text("Loading...")
        error ->
          text("Error: \#{error}")
        true ->
          render_user_list(data)
      end
  """
  def use_async(fetch_fn, deps \\ []) when is_function(fetch_fn, 0) do
    {data, set_data} = use_state(nil)
    {loading, set_loading} = use_state(false)
    {error, set_error} = use_state(nil)

    fetch_data =
      use_callback(
        fn ->
          set_loading.(true)
          set_error.(nil)

          Task.async(fn ->
            try do
              result = fetch_fn.()
              send(self(), {:async_result, :success, result})
            catch
              kind, reason ->
                send(self(), {:async_result, :error, {kind, reason}})
            end
          end)
        end,
        [fetch_fn]
      )

    # Effect to handle async results
    use_effect(fn ->
      receive do
        {:async_result, :success, result} ->
          set_data.(result)
          set_loading.(false)

        {:async_result, :error, error_info} ->
          set_error.(error_info)
          set_loading.(false)
      after
        # Don't block if no message
        0 -> :ok
      end
    end)

    # Auto-fetch on mount and when dependencies change
    use_effect(
      fn ->
        fetch_data.()
      end,
      deps
    )

    {data, loading, error, fetch_data}
  end

  # Private helper functions

  defp get_current_component_id do
    # Get component ID from process dictionary or generate one
    case Process.get(:current_component_id) do
      nil ->
        id = System.unique_integer([:positive, :monotonic])
        Process.put(:current_component_id, id)
        id

      id ->
        id
    end
  end

  defp get_current_render_context do
    Process.get(:current_render_context, %{})
  end

  defp get_hook_state(component_id) do
    Store.get_state([:hooks, component_id], HookState.new(component_id))
  end

  defp set_hook_state(component_id, hook_state) do
    Store.update_state([:hooks, component_id], hook_state)
  end

  defp update_state_hook(component_id, hook_key, new_value) do
    hook_state = get_hook_state(component_id)

    current_hook = Map.get(hook_state.hooks, hook_key)

    if current_hook do
      actual_new_value =
        case new_value do
          fun when is_function(fun, 1) ->
            # Functional update
            fun.(current_hook.value)

          value ->
            # Direct value
            value
        end

      updated_hook = %{current_hook | value: actual_new_value}
      updated_hooks = Map.put(hook_state.hooks, hook_key, updated_hook)
      updated_hook_state = %{hook_state | hooks: updated_hooks}

      set_hook_state(component_id, updated_hook_state)

      # Trigger re-render
      request_component_update(component_id)
    end
  end

  defp update_reducer_hook(component_id, hook_key, reducer_fn, action) do
    hook_state = get_hook_state(component_id)
    current_hook = Map.get(hook_state.hooks, hook_key)

    if current_hook do
      {_reducer, current_state} = current_hook.value
      new_state = reducer_fn.(action, current_state)

      updated_hook = %{current_hook | value: {reducer_fn, new_state}}
      updated_hooks = Map.put(hook_state.hooks, hook_key, updated_hook)
      updated_hook_state = %{hook_state | hooks: updated_hooks}

      set_hook_state(component_id, updated_hook_state)

      # Trigger re-render
      request_component_update(component_id)
    end
  end

  defp request_component_update(component_id) do
    # Send update message to component process
    case Process.get(:component_process) do
      nil ->
        # No component process, trigger immediate update
        send(self(), {:component_update, component_id})

      pid ->
        send(pid, {:component_update, component_id})
    end
  end

  @doc """
  Cleans up all hooks for a component (called when component unmounts).
  """
  def cleanup_hooks(component_id) do
    hook_state = get_hook_state(component_id)

    # Clean up effects
    Enum.each(hook_state.hooks, fn {_key, hook} ->
      if hook.type == :effect && hook.cleanup do
        try do
          hook.cleanup.()
        catch
          kind, reason ->
            require Logger

            Logger.error(
              "Error cleaning up hook: #{inspect(kind)}, #{inspect(reason)}"
            )
        end
      end

      # Clean up refs (stop agents)
      if hook.type == :ref && is_pid(hook.value) do
        Agent.stop(hook.value)
      end
    end)

    # Remove hook state
    Store.delete_state([:hooks, component_id])
  end

  @doc """
  Resets hook index at the beginning of each render.
  Called automatically by the component system.
  """
  def reset_hooks_for_render(component_id) do
    hook_state = get_hook_state(component_id)
    updated_hook_state = HookState.reset_hook_index(hook_state)
    set_hook_state(component_id, updated_hook_state)
  end
end
