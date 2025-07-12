defmodule Raxol.Core.Runtime.ComponentManager do
  @moduledoc """
  Manages component lifecycle and state in the Raxol runtime system.

  This module is responsible for:
  * Mounting and unmounting components
  * Managing component state
  * Handling event dispatch to components
  * Managing component subscriptions
  * Coordinating updates and renders
  """

  use GenServer
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  alias UUID
  alias Raxol.Core.Runtime.Subscription

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Setter for runtime_pid (for tests)
  def set_runtime_pid(pid) do
    GenServer.cast(__MODULE__, {:set_runtime_pid, pid})
  end

  def mount(component_module, props \\ %{}) do
    GenServer.call(__MODULE__, {:mount, component_module, props})
  end

  def unmount(component_id) do
    GenServer.call(__MODULE__, {:unmount, component_id})
  end

  def update(component_id, message) do
    GenServer.call(__MODULE__, {:update, component_id, message})
  end

  @doc """
  Directly sets the state for a component (for testing purposes).
  """
  @spec set_component_state(String.t(), map()) :: :ok | {:error, :not_found}
  def set_component_state(component_id, new_state) do
    GenServer.call(__MODULE__, {:set_component_state, component_id, new_state})
  end

  def dispatch_event(event) do
    GenServer.cast(__MODULE__, {:dispatch_event, event})
  end

  @doc """
  Retrieves the current render queue and clears it.
  """
  @spec get_render_queue() :: list(String.t())
  def get_render_queue() do
    GenServer.call(__MODULE__, :get_and_clear_render_queue)
  end

  @doc """
  Retrieves a specific component's data by its ID.
  """
  @spec get_component(String.t()) :: map() | nil
  def get_component(component_id) do
    GenServer.call(__MODULE__, {:get_component, component_id})
  end

  @doc """
  Retrieves all components' data.
  """
  @spec get_all_components() :: map()
  def get_all_components() do
    GenServer.call(__MODULE__, :get_all_components)
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    runtime_pid = Keyword.get(opts, :runtime_pid, nil)

    {:ok,
     %{
       # component_id => component_state
       components: %{},
       # subscription_id => component_id
       subscriptions: %{},
       # list of component_ids needing render
       render_queue: [],
       # PID to send events to (for tests or runtime)
       runtime_pid: runtime_pid
     }}
  end

  @impl GenServer
  def handle_call({:mount, component_module, props}, _from, state) do
    # Validate component module
    if not is_atom(component_module) or
         not Code.ensure_loaded?(component_module) do
      {:reply, {:error, :invalid_component}, state}
    else
      try do
        # Generate a unique ID
        component_id = inspect(component_module) <> "-" <> UUID.uuid4()

        # Initialize component
        case component_module.init(props) do
          {:ok, initial_state} ->
            mount_component(
              component_module,
              initial_state,
              props,
              component_id,
              state
            )

          {:error, reason} ->
            {:reply, {:error, reason}, state}

          initial_state when is_map(initial_state) ->
            mount_component(
              component_module,
              initial_state,
              props,
              component_id,
              state
            )

          _ ->
            {:reply, {:error, :invalid_init_return}, state}
        end
      rescue
        e ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Component init failed: #{inspect(e)}",
            %{component: component_module}
          )

          {:reply, {:error, :init_failed}, state}
      end
    end
  end

  defp mount_component(
         component_module,
         initial_state,
         props,
         component_id,
         state
       ) do
    # Mount the component
    {mounted_state, commands} = component_module.mount(initial_state)

    # Store component state
    new_state =
      put_in(state.components[component_id], %{
        module: component_module,
        state: mounted_state,
        props: props
      })

    # Process any commands from mounting
    process_commands(commands, component_id, new_state)

    # Queue initial render (avoid duplicates)
    new_state =
      update_in(new_state.render_queue, fn queue ->
        if component_id in queue do
          queue
        else
          [component_id | queue]
        end
      end)

    # Emit component_queued_for_render event if runtime_pid is set
    if new_state.runtime_pid,
      do:
        send(
          new_state.runtime_pid,
          {:component_queued_for_render, component_id}
        )

    {:reply, {:ok, component_id}, new_state}
  end

  @impl GenServer
  def handle_call({:unmount, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        # Call unmount callback
        final_state = component.module.unmount(component.state)

        # Cleanup subscriptions
        state = cleanup_subscriptions(component_id, state)

        # Remove component from components map
        state = update_in(state.components, &Map.delete(&1, component_id))

        # Remove component from render queue
        state =
          update_in(
            state.render_queue,
            &Enum.reject(&1, fn id -> id == component_id end)
          )

        {:reply, {:ok, final_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:update, component_id, message}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        try do
          # Call update callback
          case component.module.update(message, component.state) do
            {new_state, commands} when is_map(new_state) ->
              # Store updated state
              state = put_in(state.components[component_id].state, new_state)

              # Process any commands from update
              state = process_commands(commands, component_id, state)

              # Queue re-render if state changed
              state =
                if new_state != component.state do
                  update_in(state.render_queue, fn queue ->
                    if component_id in queue do
                      queue
                    else
                      [component_id | queue]
                    end
                  end)
                else
                  state
                end

              # Send component_updated message if runtime_pid is set
              if state.runtime_pid do
                send(state.runtime_pid, {:component_updated, component_id})
              end

              {:reply, {:ok, new_state}, state}

            new_state when is_map(new_state) ->
              # Handle case where update returns just state (no commands)
              state = put_in(state.components[component_id].state, new_state)

              # Queue re-render if state changed
              state =
                if new_state != component.state do
                  update_in(state.render_queue, fn queue ->
                    if component_id in queue do
                      queue
                    else
                      [component_id | queue]
                    end
                  end)
                else
                  state
                end

              # Send component_updated message if runtime_pid is set
              if state.runtime_pid do
                send(state.runtime_pid, {:component_updated, component_id})
              end

              {:reply, {:ok, new_state}, state}

            _ ->
              {:reply, {:error, :invalid_component_return}, state}
          end
        rescue
          e ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "Component update failed: #{inspect(e)}",
              %{component_id: component_id, message: message}
            )

            {:reply, {:error, :component_error}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:set_component_state, component_id, new_state}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        # Update the state directly in the components map
        state = put_in(state.components[component_id].state, new_state)
        # Queue re-render if state changed
        state =
          if new_state != component.state do
            update_in(state.render_queue, fn queue ->
              if component_id in queue do
                queue
              else
                [component_id | queue]
              end
            end)
          else
            state
          end

        # Send component_updated message if runtime_pid is set
        if state.runtime_pid do
          send(state.runtime_pid, {:component_updated, component_id})
        end

        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call(:get_and_clear_render_queue, _from, state) do
    # Get current queue and clear it
    queue = state.render_queue
    new_state = %{state | render_queue: []}
    {:reply, queue, new_state}
  end

  @impl GenServer
  def handle_call({:get_component, component_id}, _from, state) do
    component = Map.get(state.components, component_id)
    {:reply, component, state}
  end

  @impl GenServer
  def handle_call(:get_all_components, _from, state) do
    {:reply, state.components, state}
  end

  @impl GenServer
  def handle_info({:update, component_id, message}, state) do
    case Map.get(state.components, component_id) do
      nil ->
        # Component might have been unmounted before message arrived
        Raxol.Core.Runtime.Log.warning_with_context(
          "Received scheduled update for unknown component: #{component_id}",
          %{}
        )

        {:noreply, state}

      component ->
        # Reuse update logic (similar to handle_call)
        try do
          case component.module.update(message, component.state) do
            {new_state, _commands} when is_map(new_state) ->
              # Update component state and queue re-render
              state =
                update_component_state_and_queue_render(
                  state,
                  component_id,
                  new_state
                )

              {:noreply, state}

            new_state when is_map(new_state) ->
              # Handle case where update returns just state (no commands)
              state =
                update_component_state_and_queue_render(
                  state,
                  component_id,
                  new_state
                )

              {:noreply, state}

            _ ->
              {:noreply, state}
          end
        rescue
          e ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "Component update failed in handle_info: #{inspect(e)}",
              %{component_id: component_id, message: message}
            )

            {:noreply, state}
        end
    end
  end

  @impl GenServer
  def handle_info({:update, component_id, message, _timer_id}, state) do
    # Handle scheduled updates with timer_id (for compatibility)
    handle_info({:update, component_id, message}, state)
  end

  @impl GenServer
  def handle_cast({:dispatch_event, event}, state) do
    # Dispatch event to all components
    state =
      Enum.reduce(state.components, state, fn {component_id, component}, acc ->
        {new_state, commands} =
          component.module.handle_event(event, component.state)

        # Update component state
        acc = put_in(acc.components[component_id].state, new_state)

        # Process any commands from event handling
        process_commands(commands, component_id, acc)

        # Queue re-render if state changed
        if new_state != component.state do
          update_component_state_and_queue_render(acc, component_id, new_state)
        else
          acc
        end
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_runtime_pid, pid}, state) do
    {:noreply, %{state | runtime_pid: pid}}
  end

  # Private Helpers

  defp process_commands(commands, component_id, state) do
    Enum.reduce(commands, state, fn command, acc ->
      case command do
        {:command, cmd} ->
          # Handle component-specific commands
          handle_component_command(cmd, component_id, acc)

        {:schedule, msg, delay} ->
          # Schedule delayed message using Process.send_after
          timer_id = System.unique_integer([:positive])

          Process.send_after(
            self(),
            {:update, component_id, msg, timer_id},
            delay
          )

          # Store timer_id in state if needed
          acc

        {:broadcast, msg} ->
          # Use Enum.reduce to iterate and update the state (accumulator)
          broadcast_update(msg, component_id, acc)

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Unknown command type: #{inspect(command)}",
            %{}
          )

          acc
      end
    end)
  end

  defp broadcast_update(msg, source_component_id, state) do
    Enum.reduce(Map.keys(state.components), state, fn id, acc_state ->
      if id == source_component_id do
        acc_state
      else
        update_component_in_broadcast(id, msg, acc_state)
      end
    end)
  end

  defp update_component_in_broadcast(id, msg, state) do
    case Map.get(state.components, id) do
      nil ->
        state

      component ->
        {updated_comp_state, _commands} =
          component.module.update(msg, component.state)

        updated_component = %{component | state: updated_comp_state}

        state_with_updated_comp =
          put_in(state.components[id], updated_component)

        update_component_state_and_queue_render(
          state_with_updated_comp,
          id,
          updated_comp_state
        )
    end
  end

  defp handle_component_command(command, component_id, state) do
    case command do
      {:subscribe, events} when list?(events) ->
        handle_subscription_command(events, component_id, state)

      {:unsubscribe, sub_id} ->
        handle_unsubscribe_command(sub_id, state)

      _ ->
        state
    end
  end

  # Helper function to update component state and queue re-render
  defp update_component_state_and_queue_render(state, component_id, new_state) do
    # Update component state
    state = put_in(state.components[component_id].state, new_state)

    # Queue re-render
    state =
      update_in(state.render_queue, fn queue ->
        if component_id in queue do
          queue
        else
          [component_id | queue]
        end
      end)

    # Send component_updated message if runtime_pid is set
    if state.runtime_pid do
      send(state.runtime_pid, {:component_updated, component_id})
    end

    state
  end

  defp handle_subscription_command(events, component_id, state) do
    {:ok, sub_id} =
      Subscription.start(%Subscription{type: :events, data: events}, %{
        pid: self()
      })

    put_in(state.subscriptions[sub_id], component_id)
  end

  defp handle_unsubscribe_command(sub_id, state) do
    case Subscription.stop(sub_id) do
      :ok ->
        update_in(state.subscriptions, &Map.delete(&1, sub_id))

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Failed to stop subscription #{inspect(sub_id)}: #{inspect(reason)}",
          %{}
        )

        update_in(state.subscriptions, &Map.delete(&1, sub_id))
    end
  end

  defp cleanup_subscriptions(component_id, state) do
    # Find and remove all subscriptions for this component
    {to_remove, remaining} =
      Enum.split_with(state.subscriptions, fn {_, cid} ->
        cid == component_id
      end)

    # Unsubscribe from each using aliased Subscription module
    Enum.each(to_remove, fn {sub_id, _} ->
      case Subscription.stop(sub_id) do
        :ok ->
          :ok

        {:error, reason} ->
          require Raxol.Core.Runtime.Log

          Raxol.Core.Runtime.Log.warning_with_context(
            "Failed to stop subscription #{inspect(sub_id)}: #{inspect(reason)}",
            %{}
          )

        _ ->
          # Handle any other return values
          :ok
      end
    end)

    # Update state
    %{state | subscriptions: Map.new(remaining)}
  end
end
