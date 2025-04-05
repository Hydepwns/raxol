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

  alias Raxol.Core.Runtime.EventLoop

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      components: %{},  # component_id => component_state
      subscriptions: %{},  # subscription_id => component_id
      render_queue: []  # list of component_ids needing render
    }}
  end

  @impl true
  def handle_call({:mount, component_module, props}, _from, state) do
    component_id = inspect(component_module)
    
    # Initialize component
    initial_state = component_module.init(props)
    
    # Mount the component
    {mounted_state, commands} = component_module.mount(initial_state)
    
    # Store component state
    new_state = put_in(state.components[component_id], %{
      module: component_module,
      state: mounted_state,
      props: props
    })
    
    # Process any commands from mounting
    process_commands(commands, component_id, new_state)
    
    # Queue initial render
    new_state = update_in(new_state.render_queue, &[component_id | &1])
    
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
        # Update component state
        new_state = component.module.update(message, component.state)
        
        # Store updated state
        state = put_in(state.components[component_id].state, new_state)
        
        # Queue re-render
        state = update_in(state.render_queue, &[component_id | &1])
        
        {:reply, {:ok, new_state}, state}
    end
  end

  @impl true
  def handle_cast({:dispatch_event, event}, state) do
    # Dispatch event to all components
    state = Enum.reduce(state.components, state, fn {component_id, component}, acc ->
      {new_state, commands} = component.module.handle_event(event, component.state)
      
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

  # Private Helpers

  defp process_commands(commands, component_id, state) do
    Enum.reduce(commands, state, fn command, acc ->
      case command do
        {:command, cmd} ->
          # Handle component-specific commands
          handle_component_command(cmd, component_id, acc)
          
        {:schedule, msg, delay} ->
          # Schedule delayed message
          EventLoop.schedule_once(delay, fn ->
            update(component_id, msg)
          end)
          acc
          
        {:broadcast, msg} ->
          # Broadcast message to all components
          Enum.each(acc.components, fn {id, _} ->
            update(id, msg)
          end)
          acc
          
        _ ->
          acc
      end
    end)
  end

  defp handle_component_command(command, component_id, state) do
    case command do
      {:subscribe, events} when is_list(events) ->
        # Set up event subscription
        {:ok, sub_id} = Subscription.events(events)
        put_in(state.subscriptions[sub_id], component_id)
        
      {:unsubscribe, sub_id} ->
        # Remove subscription
        Subscription.unsubscribe(sub_id)
        update_in(state.subscriptions, &Map.delete(&1, sub_id))
        
      _ ->
        state
    end
  end

  defp cleanup_subscriptions(component_id, state) do
    # Find and remove all subscriptions for this component
    {to_remove, remaining} = Enum.split_with(state.subscriptions, fn {_, cid} ->
      cid == component_id
    end)
    
    # Unsubscribe from each
    Enum.each(to_remove, fn {sub_id, _} ->
      Subscription.unsubscribe(sub_id)
    end)
    
    # Update state
    %{state | subscriptions: Map.new(remaining)}
  end
end 