defmodule Raxol.Core.Runtime.Events.Handlers do
  @moduledoc """
  Manages event handlers registration and execution in the Raxol system.

  This module is responsible for:
  * Registering event handlers for specific event types
  * Executing handlers when events occur
  * Managing the priority and order of handlers
  """

  require Logger

  @doc """
  Registers a new event handler for the specified event types.

  ## Parameters
  - `handler_id`: Unique identifier for the handler
  - `event_types`: List of event types the handler should receive
  - `handler_fun`: Function to call when an event occurs
  - `options`: Additional options for handler registration
    - `:priority` - Handler priority (default: 100, lower numbers run first)
    - `:filter` - Optional filter function to determine if events should be handled

  ## Returns
  `{:ok, handler_id}` if registration succeeded,
  `{:error, reason}` otherwise.
  """
  def register_handler(handler_id, event_types, handler_fun, options \\ []) do
    # Default options
    priority = Keyword.get(options, :priority, 100)
    filter = Keyword.get(options, :filter, fn _event -> true end)

    handler = %{
      id: handler_id,
      event_types: List.wrap(event_types),
      handler_fun: handler_fun,
      priority: priority,
      filter: filter
    }

    # Store the handler in the process dictionary or ETS table
    # This is a placeholder - in the real implementation, we'd use a more robust storage
    put_handler(handler_id, handler)

    {:ok, handler_id}
  end

  @doc """
  Unregisters an event handler.

  ## Parameters
  - `handler_id`: ID of the handler to remove

  ## Returns
  `:ok` if the handler was removed,
  `{:error, :not_found}` if the handler wasn't registered.
  """
  def unregister_handler(handler_id) do
    case get_handler(handler_id) do
      nil ->
        {:error, :not_found}

      _handler ->
        remove_handler(handler_id)
        :ok
    end
  end

  @doc """
  Executes all registered handlers for the given event.

  Handlers are executed in priority order (lowest to highest).
  Each handler can transform the event for the next handler.

  ## Parameters
  - `event`: The event to handle
  - `state`: The current application state

  ## Returns
  `{:ok, updated_event, updated_state}` if all handlers executed successfully,
  `{:error, reason, state}` if a handler failed.
  """
  def execute_handlers(event, state) do
    # Get all handlers for this event type
    handlers =
      get_all_handlers()
      |> Enum.filter(fn handler ->
        event.type in handler.event_types and handler.filter.(event)
      end)
      |> Enum.sort_by(fn handler -> handler.priority end)

    # Execute handlers in priority order
    try do
      Enum.reduce_while(handlers, {event, state}, fn handler,
                                                     {current_event,
                                                      current_state} ->
        case handler.handler_fun.(current_event, current_state) do
          {:ok, new_event, new_state} ->
            {:cont, {new_event, new_state}}

          {:stop, new_event, new_state} ->
            {:halt, {new_event, new_state}}

          {:error, reason} ->
            Logger.error("Handler error: #{inspect(reason)}")
            {:halt, {:error, reason, current_state}}
        end
      end)
      |> case do
        {updated_event, updated_state} ->
          {:ok, updated_event, updated_state}

        {:error, reason, state} ->
          {:error, reason, state}
      end
    rescue
      error ->
        Logger.error("Error executing handlers: #{inspect(error)}")
        {:error, {:handler_error, error}, state}
    end
  end

  # Private storage functions
  # In a real implementation, these would use ETS or another storage mechanism

  defp put_handler(id, handler) do
    # This is a placeholder implementation
    # In a real system, this would store in ETS or another global store
    Process.put({:handler, id}, handler)
  end

  defp get_handler(id) do
    # This is a placeholder implementation
    Process.get({:handler, id})
  end

  defp remove_handler(id) do
    # This is a placeholder implementation
    Process.delete({:handler, id})
  end

  defp get_all_handlers do
    # This is a placeholder implementation
    # In a real system, we'd query ETS or another storage
    Process.get()
    |> Enum.filter(fn {{type, _}, _} -> type == :handler end)
    |> Enum.map(fn {{_, _}, handler} -> handler end)
  end
end
