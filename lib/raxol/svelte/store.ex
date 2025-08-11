defmodule Raxol.Svelte.Store do
  @moduledoc """
  Svelte-style reactive stores for Raxol.

  Provides writable stores, derived stores, and reactive subscriptions
  similar to Svelte's store API but leveraging Elixir's GenServer and PubSub.

  ## Example

      defmodule Counter do
        use Raxol.Svelte.Store
        
        store :count, 0
        store :step, 1
        
        derive :doubled, fn %{count: c} -> c * 2 end
        derive :message, fn %{count: c, doubled: d} -> 
          "Count: \#{c}, Doubled: \#{d}"
        end
      end
      
      # Usage
      Counter.set(:count, 10)
      Counter.update(:count, & &1 + 1)
      value = Counter.get(:count)
      Counter.subscribe(:count, fn value -> IO.puts("Count changed: \#{value}") end)
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger

      @stores %{}
      @derivations %{}
      @before_compile Raxol.Svelte.Store

      import Raxol.Svelte.Store

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @impl GenServer
      def init(_opts) do
        state = %{
          values: @stores,
          subscribers: %{},
          derivations: @derivations
        }

        # Initialize derived values
        state = update_derivations(state)

        {:ok, state}
      end
    end
  end

  @doc """
  Define a writable store with an initial value.
  """
  defmacro store(name, initial_value) do
    quote do
      @stores Map.put(@stores, unquote(name), unquote(initial_value))

      @doc "Get the current value of #{unquote(name)}"
      def get(unquote(name)) do
        GenServer.call(__MODULE__, {:get, unquote(name)})
      end

      @doc "Set #{unquote(name)} to a new value"
      def set(unquote(name), value) do
        GenServer.call(__MODULE__, {:set, unquote(name), value})
      end

      @doc "Update #{unquote(name)} with a function"
      def update(unquote(name), fun) when is_function(fun, 1) do
        GenServer.call(__MODULE__, {:update, unquote(name), fun})
      end

      @doc "Subscribe to changes in #{unquote(name)}"
      def subscribe(unquote(name), callback) when is_function(callback, 1) do
        GenServer.call(__MODULE__, {:subscribe, unquote(name), callback})
      end

      @doc "Unsubscribe from #{unquote(name)}"
      def unsubscribe(unquote(name), callback_id) do
        GenServer.call(__MODULE__, {:unsubscribe, unquote(name), callback_id})
      end
    end
  end

  @doc """
  Define a derived store that automatically updates when dependencies change.
  """
  defmacro derive(name, compute_fn) do
    quote do
      @derivations Map.put(@derivations, unquote(name), unquote(compute_fn))
      @stores Map.put(@stores, unquote(name), nil)

      @doc "Get the derived value of #{unquote(name)}"
      def get(unquote(name)) do
        GenServer.call(__MODULE__, {:get, unquote(name)})
      end

      @doc "Subscribe to changes in derived #{unquote(name)}"
      def subscribe(unquote(name), callback) when is_function(callback, 1) do
        GenServer.call(__MODULE__, {:subscribe, unquote(name), callback})
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Handle get calls
      @impl GenServer
      def handle_call({:get, name}, _from, state) do
        value = get_in(state, [:values, name])
        {:reply, value, state}
      end

      # Handle set calls
      @impl GenServer
      def handle_call({:set, name, value}, _from, state) do
        state =
          state
          |> put_in([:values, name], value)
          |> update_derivations()
          |> notify_subscribers(name)

        {:reply, :ok, state}
      end

      # Handle update calls
      @impl GenServer
      def handle_call({:update, name, fun}, _from, state) do
        current = get_in(state, [:values, name])
        new_value = fun.(current)

        state =
          state
          |> put_in([:values, name], new_value)
          |> update_derivations()
          |> notify_subscribers(name)

        {:reply, new_value, state}
      end

      # Handle subscribe calls
      @impl GenServer
      def handle_call({:subscribe, name, callback}, _from, state) do
        id = make_ref()

        subscribers =
          state.subscribers
          |> Map.update(name, [{id, callback}], fn subs ->
            [{id, callback} | subs]
          end)

        state = %{state | subscribers: subscribers}

        # Immediately call the callback with current value
        callback.(get_in(state, [:values, name]))

        {:reply, id, state}
      end

      # Handle unsubscribe calls
      @impl GenServer
      def handle_call({:unsubscribe, name, callback_id}, _from, state) do
        subscribers =
          state.subscribers
          |> Map.update(name, [], fn subs ->
            Enum.reject(subs, fn {id, _} -> id == callback_id end)
          end)

        state = %{state | subscribers: subscribers}
        {:reply, :ok, state}
      end

      # Update all derived values
      defp update_derivations(state) do
        Enum.reduce(@derivations, state, fn {name, compute_fn}, acc ->
          old_value = get_in(acc, [:values, name])
          new_value = compute_fn.(acc.values)

          if old_value != new_value do
            acc
            |> put_in([:values, name], new_value)
            |> notify_subscribers(name)
          else
            acc
          end
        end)
      end

      # Notify all subscribers of a value change
      defp notify_subscribers(state, name) do
        value = get_in(state, [:values, name])

        subscribers = Map.get(state.subscribers, name, [])

        # Run callbacks asynchronously to avoid blocking
        Enum.each(subscribers, fn {_id, callback} ->
          Task.start(fn -> callback.(value) end)
        end)

        state
      end

      # Get all current store values
      def get_all() do
        GenServer.call(__MODULE__, :get_all)
      end

      @impl GenServer
      def handle_call(:get_all, _from, state) do
        {:reply, state.values, state}
      end

      # Batch updates for efficiency
      def batch(updates) when is_list(updates) do
        GenServer.call(__MODULE__, {:batch, updates})
      end

      @impl GenServer
      def handle_call({:batch, updates}, _from, state) do
        state =
          Enum.reduce(updates, state, fn {name, value}, acc ->
            put_in(acc, [:values, name], value)
          end)

        state = update_derivations(state)

        # Notify all affected subscribers
        Enum.each(updates, fn {name, _} ->
          notify_subscribers(state, name)
        end)

        {:reply, :ok, state}
      end

      # Default GenServer callbacks to satisfy behaviour requirements
      @impl GenServer
      def handle_cast(_msg, state) do
        {:noreply, state}
      end

      @impl GenServer
      def terminate(_reason, _state) do
        :ok
      end

      @impl GenServer
      def code_change(_old_vsn, state, _extra) do
        {:ok, state}
      end
    end
  end
end
