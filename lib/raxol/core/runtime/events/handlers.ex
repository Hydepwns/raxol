defmodule Raxol.Core.Runtime.Events.Handlers do
  @moduledoc '''
  Manages event handlers registration and execution in the Raxol system.

  This module is responsible for:
  * Registering event handlers for specific event types
  * Executing handlers when events occur
  * Managing the priority and order of handlers
  '''

  require Raxol.Core.Runtime.Log

  @doc '''
  Registers a new event handler for the specified event types.
  '''
  def register_handler(handler_id, event_types, handler_fun, options \\ []) do
    priority = Keyword.get(options, :priority, 100)
    filter = Keyword.get(options, :filter, fn _event -> true end)

    handler = %{
      id: handler_id,
      event_types: List.wrap(event_types),
      handler_fun: handler_fun,
      priority: priority,
      filter: filter
    }

    put_handler(handler_id, handler)

    {:ok, handler_id}
  end

  @doc '''
  Unregisters an event handler.

  ## Parameters
  - `handler_id`: ID of the handler to remove
  '''
  def unregister_handler(handler_id) do
    case get_handler(handler_id) do
      nil ->
        {:error, :not_found}

      _handler ->
        remove_handler(handler_id)
        :ok
    end
  end

  @doc '''
  Executes all registered handlers for the given event.
  Handlers are executed in priority order (lowest to highest).
  Each handler can transform the event for the next handler.
  '''
  def execute_handlers(event, state) do
    handlers = get_relevant_handlers(event)
    execute_handlers_in_order(handlers, event, state)
  end

  defp get_relevant_handlers(event) do
    get_all_handlers()
    |> Enum.filter(fn handler ->
      event.type in handler.event_types and handler.filter.(event)
    end)
    |> Enum.sort_by(fn handler -> handler.priority end)
  end

  defp execute_handlers_in_order(handlers, event, state) do
    try do
      Enum.reduce_while(handlers, {event, state}, &execute_single_handler/2)
      |> case do
        {updated_event, updated_state} -> {:ok, updated_event, updated_state}
        {:error, reason, state} -> {:error, reason, state}
      end
    rescue
      error ->
        log_handler_error(error, event, state, __STACKTRACE__)
        {:error, {:handler_error, error}, state}
    end
  end

  defp execute_single_handler(handler, {current_event, current_state}) do
    case handler.handler_fun.(current_event, current_state) do
      {:ok, new_event, new_state} -> {:cont, {new_event, new_state}}
      {:stop, new_event, new_state} -> {:halt, {new_event, new_state}}
      {:error, reason} ->
        log_handler_error(reason, current_event, current_state, [])
        {:halt, {:error, reason, current_state}}
    end
  end

  defp log_handler_error(error, event, state, stacktrace) do
    try do
      Raxol.Core.Runtime.Log.error_with_stacktrace(
        "Handler error",
        error,
        stacktrace,
        %{module: __MODULE__, event: event, state: state}
      )
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Failed to log handler error: #{inspect(e)}",
          %{module: __MODULE__, event: event, state: state}
        )
    end
  end

  defp put_handler(id, handler) do
    Process.put({:handler, id}, handler)
  end

  defp get_handler(id) do
    Process.get({:handler, id})
  end

  defp remove_handler(id) do
    Process.delete({:handler, id})
  end

  defp get_all_handlers do
    Process.get()
    |> Enum.filter(fn
      {{:handler, _id}, _value} -> true
      _ -> false
    end)
    |> Enum.map(fn {{_, _}, handler} -> handler end)
  end
end
