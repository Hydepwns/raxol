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

  # Server Callbacks

  @impl true
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

  @impl true
  def handle_call({:mount, component_module, props}, _from, state) do
    # Generate a unique ID
    component_id = inspect(component_module) <> "-" <> UUID.uuid4()

    # Initialize component
    initial_state = component_module.init(props)

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

    # Queue initial render
    new_state = update_in(new_state.render_queue, &[component_id | &1])

    # Emit component_queued_for_render event if runtime_pid is set
    if new_state.runtime_pid,
      do:
        send(
          new_state.runtime_pid,
          {:component_queued_for_render, component_id}
        )

    {:reply, {:ok, component_id}, new_state}
  end

  @impl true
  def handle_call({:unmount, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        # Call unmount callback
        final_state = component.module.unmount(component.state)

        # Cleanup subscriptions
        state = cleanup_subscriptions(component_id, state)

        # Remove component
        state = update_in(state.components, &Map.delete(&1, component_id))

        {:reply, {:ok, final_state}, state}
    end
  end

  @impl true
  def handle_call({:update, component_id, message}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        # Call update callback
        {new_state, commands} =
          component.module.update(message, component.state)

        # Store updated state
        state = put_in(state.components[component_id].state, new_state)

        # Process any commands from update
        state = process_commands(commands, component_id, state)

        # Queue re-render if state changed
        state =
          if new_state != component.state do
            update_in(state.render_queue, &[component_id | &1])
          else
            state
          end

        {:reply, {:ok, new_state}, state}
    end
  end

  @impl true
  def handle_call(:get_and_clear_render_queue, _from, state) do
    # Get current queue and clear it
    queue = state.render_queue
    new_state = %{state | render_queue: []}
    {:reply, queue, new_state}
  end

  @impl true
  def handle_call({:get_component, component_id}, _from, state) do
    component = Map.get(state.components, component_id)
    {:reply, component, state}
  end

  @impl true
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
        # Destructure return value, ignore commands from info update
        {new_state, _commands} =
          component.module.update(message, component.state)

        # Store updated state (only the state map)
        state = put_in(state.components[component_id].state, new_state)

        # Queue re-render
        state = update_in(state.render_queue, &[component_id | &1])

        {:noreply, state}
    end
  end

  @impl true
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
          update_in(acc.render_queue, &[component_id | &1])
        else
          acc
        end
      end)

    {:noreply, state}
  end

  @impl true
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

        update_in(state_with_updated_comp.render_queue, &[id | &1])
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
