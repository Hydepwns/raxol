defmodule Raxol.Architecture.CQRS.CommandDispatcher do
  @moduledoc """
  Command dispatcher for CQRS pattern implementation.

  Handles command routing, middleware processing, and handler management
  in a functional programming style.
  """

  use GenServer
  alias Raxol.Core.Runtime.Log
  defstruct [
    :handlers,
    :middleware,
    :statistics
  ]

  @type command :: any()
  @type handler :: module()
  @type middleware :: module()
  @type statistics :: %{
          commands_processed: non_neg_integer(),
          commands_failed: non_neg_integer(),
          handlers_registered: non_neg_integer(),
          middleware_count: non_neg_integer()
        }

  # Client API

  @doc """
  Starts the command dispatcher.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Add middleware to the dispatcher.
  """
  def add_middleware(middleware) when is_atom(middleware) do
    GenServer.call(__MODULE__, {:add_middleware, middleware})
  end

  @doc """
  Register a command handler.
  """
  def register_handler(command, handler)
      when is_atom(command) and is_atom(handler) do
    GenServer.call(__MODULE__, {:register_handler, command, handler})
  end

  @doc """
  Dispatch a command through the middleware chain to its handler.
  """
  def dispatch(command) do
    GenServer.call(__MODULE__, {:dispatch, command})
  end

  @doc """
  List all registered handlers.
  """
  def list_handlers do
    GenServer.call(__MODULE__, :list_handlers)
  end

  @doc """
  Get dispatcher statistics.
  """
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Remove a handler for a command.
  """
  def unregister_handler(command) when is_atom(command) do
    GenServer.call(__MODULE__, {:unregister_handler, command})
  end

  @doc """
  Remove middleware from the dispatcher.
  """
  def remove_middleware(middleware) when is_atom(middleware) do
    GenServer.call(__MODULE__, {:remove_middleware, middleware})
  end

  # Server callbacks

  @impl true
  def init([]) do
    state = %__MODULE__{
      handlers: %{},
      middleware: [],
      statistics: %{
        commands_processed: 0,
        commands_failed: 0,
        handlers_registered: 0,
        middleware_count: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_middleware, middleware}, _from, state) do
    case validate_middleware(middleware) do
      :ok ->
        new_middleware = [middleware | state.middleware]
        new_stats = Map.update!(state.statistics, :middleware_count, &(&1 + 1))
        new_state = %{state | middleware: new_middleware, statistics: new_stats}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:register_handler, command, handler}, _from, state) do
    case validate_handler(handler) do
      :ok ->
        new_handlers = Map.put(state.handlers, command, handler)

        new_stats =
          Map.update!(state.statistics, :handlers_registered, &(&1 + 1))

        new_state = %{state | handlers: new_handlers, statistics: new_stats}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:dispatch, command}, _from, state) do
    command_type = get_command_type(command)

    case Map.get(state.handlers, command_type) do
      nil ->
        new_stats = Map.update!(state.statistics, :commands_failed, &(&1 + 1))
        new_state = %{state | statistics: new_stats}
        {:reply, {:error, :handler_not_found}, new_state}

      handler ->
        case execute_command_pipeline(command, handler, state.middleware) do
          {:ok, result} ->
            new_stats =
              Map.update!(state.statistics, :commands_processed, &(&1 + 1))

            new_state = %{state | statistics: new_stats}
            {:reply, {:ok, result}, new_state}

          {:error, reason} ->
            new_stats =
              Map.update!(state.statistics, :commands_failed, &(&1 + 1))

            new_state = %{state | statistics: new_stats}
            {:reply, {:error, reason}, new_state}
        end
    end
  end

  @impl true
  def handle_call(:list_handlers, _from, state) do
    handlers_list =
      Enum.map(state.handlers, fn {command, handler} ->
        %{command: command, handler: handler}
      end)

    {:reply, handlers_list, state}
  end

  @impl true
  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end

  @impl true
  def handle_call({:unregister_handler, command}, _from, state) do
    new_handlers = Map.delete(state.handlers, command)

    new_stats =
      Map.update!(state.statistics, :handlers_registered, &max(0, &1 - 1))

    new_state = %{state | handlers: new_handlers, statistics: new_stats}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:remove_middleware, middleware}, _from, state) do
    new_middleware = Enum.reject(state.middleware, &(&1 == middleware))

    new_stats =
      Map.update!(state.statistics, :middleware_count, &max(0, &1 - 1))

    new_state = %{state | middleware: new_middleware, statistics: new_stats}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp get_command_type(command) when is_atom(command), do: command
  defp get_command_type(command) when is_struct(command), do: command.__struct__
  defp get_command_type(%{__type__: type}), do: type
  defp get_command_type(_), do: :unknown_command

  defp execute_command_pipeline(command, handler, middleware) do
    middleware
    |> Enum.reverse()
    |> Enum.reduce(
      fn -> execute_handler(handler, command) end,
      fn current_middleware, next_fn ->
        fn -> apply_middleware(current_middleware, command, next_fn) end
      end
    )
    |> apply([])
  rescue
    error ->
      Log.module_error("Command execution failed: #{inspect(error)}")
      {:error, {:execution_failed, error}}
  end

  defp apply_middleware(middleware, command, next_fn) do
    case function_exported?(middleware, :call, 2) do
      true ->
        middleware.call(command, next_fn)

      false ->
        Log.module_warning(
          "Middleware #{middleware} does not implement call/2, skipping"
        )

        next_fn.()
    end
  rescue
    error ->
      Log.module_error("Middleware #{middleware} failed: #{inspect(error)}")
      {:error, {:middleware_failed, middleware, error}}
  end

  defp execute_handler(handler, command) do
    case function_exported?(handler, :handle, 1) do
      true ->
        handler.handle(command)

      false ->
        case function_exported?(handler, :call, 1) do
          true ->
            handler.call(command)

          false ->
            Log.module_error(
              "Handler #{handler} does not implement handle/1 or call/1"
            )

            {:error, {:invalid_handler, handler}}
        end
    end
  rescue
    error ->
      Log.module_error("Handler #{handler} failed: #{inspect(error)}")
      {:error, {:handler_failed, handler, error}}
  end

  defp validate_middleware(middleware) do
    cond do
      not is_atom(middleware) ->
        {:error, :middleware_must_be_atom}

      not function_exported?(middleware, :call, 2) ->
        {:error, :middleware_must_implement_call_2}

      true ->
        :ok
    end
  end

  defp validate_handler(handler) do
    cond do
      not is_atom(handler) ->
        {:error, :handler_must_be_atom}

      not (function_exported?(handler, :handle, 1) or
               function_exported?(handler, :call, 1)) ->
        {:error, :handler_must_implement_handle_1_or_call_1}

      true ->
        :ok
    end
  end
end
