defmodule Raxol.Core.Events.Manager do
  @moduledoc """
  Event manager for handling and dispatching events in Raxol applications.
  
  This module provides a simple event system that allows:
  - Registering event handlers
  - Dispatching events
  - Handling events
  
  ## Usage
  
  ```elixir
  # Initialize the event manager
  EventManager.init()
  
  # Register an event handler
  EventManager.register_handler(:click, MyModule, :handle_click)
  
  # Dispatch an event
  EventManager.dispatch({:click, %{x: 10, y: 20}})
  ```
  """
  
  @doc """
  Initialize the event manager.
  
  ## Examples
  
      iex> EventManager.init()
      :ok
  """
  def init do
    # Initialize event handlers registry
    Process.put(:event_handlers, %{})
    :ok
  end
  
  @doc """
  Register an event handler.
  
  ## Parameters
  
  * `event_type` - The type of event to handle
  * `module` - The module containing the handler function
  * `function` - The function to call when the event occurs
  
  ## Examples
  
      iex> EventManager.register_handler(:click, MyModule, :handle_click)
      :ok
  """
  def register_handler(event_type, module, function) when is_atom(event_type) and is_atom(module) and is_atom(function) do
    # Get current handlers
    handlers = Process.get(:event_handlers) || %{}
    
    # Get handlers for this event type
    event_handlers = Map.get(handlers, event_type, [])
    
    # Add the new handler if not already registered
    updated_handlers =
      if {module, function} in event_handlers do
        event_handlers
      else
        [{module, function} | event_handlers]
      end
    
    # Update the registry
    updated_registry = Map.put(handlers, event_type, updated_handlers)
    Process.put(:event_handlers, updated_registry)
    
    :ok
  end
  
  @doc """
  Unregister an event handler.
  
  ## Parameters
  
  * `event_type` - The type of event
  * `module` - The module containing the handler function
  * `function` - The function that was registered
  
  ## Examples
  
      iex> EventManager.unregister_handler(:click, MyModule, :handle_click)
      :ok
  """
  def unregister_handler(event_type, module, function) when is_atom(event_type) and is_atom(module) and is_atom(function) do
    # Get current handlers
    handlers = Process.get(:event_handlers) || %{}
    
    # Get handlers for this event type
    event_handlers = Map.get(handlers, event_type, [])
    
    # Remove the handler
    updated_handlers = Enum.reject(event_handlers, fn {m, f} -> m == module and f == function end)
    
    # Update the registry
    updated_registry = Map.put(handlers, event_type, updated_handlers)
    Process.put(:event_handlers, updated_registry)
    
    :ok
  end
  
  @doc """
  Dispatch an event to all registered handlers.
  
  ## Parameters
  
  * `event` - The event to dispatch
  
  ## Examples
  
      iex> EventManager.dispatch({:click, %{x: 10, y: 20}})
      :ok
      
      iex> EventManager.dispatch(:accessibility_high_contrast)
      :ok
  """
  def dispatch(event) do
    # Extract event type from event
    event_type = extract_event_type(event)
    
    # Get handlers for this event type
    handlers = Process.get(:event_handlers) || %{}
    event_handlers = Map.get(handlers, event_type, [])
    
    # Call each handler
    Enum.each(event_handlers, fn {module, function} ->
      apply(module, function, [event])
    end)
    
    :ok
  end
  
  @doc """
  Get all registered event handlers.
  
  ## Examples
  
      iex> EventManager.get_handlers()
      %{click: [{MyModule, :handle_click}]}
  """
  def get_handlers do
    Process.get(:event_handlers) || %{}
  end
  
  @doc """
  Clear all event handlers.
  
  ## Examples
  
      iex> EventManager.clear_handlers()
      :ok
  """
  def clear_handlers do
    Process.put(:event_handlers, %{})
    :ok
  end
  
  # Private functions
  
  defp extract_event_type(event) when is_atom(event), do: event
  defp extract_event_type({event_type, _data}) when is_atom(event_type), do: event_type
  defp extract_event_type(_), do: :unknown
end 