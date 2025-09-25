defmodule Raxol.UI.State.Streams do
  alias Raxol.Core.Runtime.ProcessStore

  @moduledoc """
  Reactive streams system for real-time data flow in Raxol UI.

  Refactored version with pure functional error handling patterns.
  All try/catch blocks have been replaced with with statements and proper error tuples.

  This module provides RxJS-like reactive programming capabilities with:
  - Observable streams of data
  - Operators for transforming data (map, filter, reduce, etc.)
  - Hot and cold observables
  - Backpressure handling
  - Functional error handling and retry strategies
  - Subscription management
  - Combining multiple streams
  """

  alias Raxol.UI.State.Store

  require Logger

  # Observable definition
  defmodule Observable do
    @enforce_keys [:subscribe_fn]
    defstruct [:subscribe_fn, :metadata, :operators]

    def new(subscribe_fn, metadata \\ %{}) do
      %__MODULE__{
        subscribe_fn: subscribe_fn,
        metadata: metadata,
        operators: []
      }
    end
  end

  # Observer functions
  defmodule Observer do
    defstruct [:next, :error, :complete]

    def new(next_fn, error_fn \\ nil, complete_fn \\ nil) do
      %__MODULE__{
        next: next_fn || fn _ -> :ok end,
        error: error_fn || fn _ -> :ok end,
        complete: complete_fn || fn -> :ok end
      }
    end
  end

  # Subscription handle
  defmodule Subscription do
    defstruct [:id, :unsubscribe_fn, :observable, :active]

    def new(id, unsubscribe_fn, observable) do
      %__MODULE__{
        id: id,
        unsubscribe_fn: unsubscribe_fn,
        observable: observable,
        active: true
      }
    end
  end

  # Subject for hot observables
  defmodule Subject do
    use GenServer

    defstruct [:observers, :completed, :error]

    def start_link(opts \\ []) do
      GenServer.start_link(
        __MODULE__,
        %__MODULE__{
          observers: %{},
          completed: false,
          error: nil
        },
        opts
      )
    end

    def next(subject, value) do
      GenServer.call(subject, {:next, value})
    end

    def error(subject, error) do
      GenServer.call(subject, {:error, error})
    end

    def complete(subject) do
      GenServer.call(subject, :complete)
    end

    def subscribe(subject, observer) do
      GenServer.call(subject, {:subscribe, observer})
    end

    @impl GenServer
    def init(state) do
      {:ok, state}
    end

    @impl GenServer
    def handle_call({:next, value}, _from, state) do
      with false <- state.completed,
           nil <- state.error do
        # Notify all observers with functional error handling
        state.observers
        |> Map.values()
        |> Enum.each(fn observer ->
          _ = safe_call_observer(observer.next, value)
        end)

        {:reply, :ok, state}
      else
        true -> {:reply, {:error, :completed}, state}
        error -> {:reply, {:error, error}, state}
      end
    end

    @impl GenServer
    def handle_call({:error, error}, _from, state) do
      with false <- state.completed do
        # Notify all observers of error
        state.observers
        |> Map.values()
        |> Enum.each(fn observer ->
          _ = safe_call_observer(observer.error, error)
        end)

        {:reply, :ok, %{state | error: error, completed: true}}
      else
        _ -> {:reply, {:error, :already_completed}, state}
      end
    end

    @impl GenServer
    def handle_call(:complete, _from, state) do
      with false <- state.completed,
           nil <- state.error do
        # Notify all observers of completion
        state.observers
        |> Map.values()
        |> Enum.each(fn observer ->
          _ = safe_call_observer(observer.complete)
        end)

        {:reply, :ok, %{state | completed: true}}
      else
        _ -> {:reply, {:error, :already_completed}, state}
      end
    end

    @impl GenServer
    def handle_call({:subscribe, observer}, _from, state) do
      with false <- state.completed do
        observer_id = System.unique_integer([:positive, :monotonic])
        new_observers = Map.put(state.observers, observer_id, observer)

        # Return unsubscribe function
        unsubscribe_fn = fn ->
          GenServer.call(self(), {:unsubscribe, observer_id})
        end

        {:reply, {:ok, unsubscribe_fn}, %{state | observers: new_observers}}
      else
        true when state.error != nil ->
          # If already errored, notify immediately
          _ = safe_call_observer(observer.error, state.error)
          {:reply, {:ok, fn -> :ok end}, state}

        true ->
          # If already completed, notify immediately
          _ = safe_call_observer(observer.complete)
          {:reply, {:ok, fn -> :ok end}, state}
      end
    end

    @impl GenServer
    def handle_call({:unsubscribe, observer_id}, _from, state) do
      new_observers = Map.delete(state.observers, observer_id)
      {:reply, :ok, %{state | observers: new_observers}}
    end

    # Safe observer calling helper
    defp safe_call_observer(observer_fn, value \\ nil) do
      with {:ok, _} <- Raxol.UI.State.Streams.safe_apply(observer_fn, value) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("Observer function failed: #{inspect(reason)}")
          :ok
      end
    end
  end

  ## Observable Creation Functions

  @doc """
  Creates an observable from a list of values.

  ## Examples

      numbers = Streams.from_list([1, 2, 3, 4, 5])
      Streams.subscribe(numbers, fn x -> IO.puts(x) end)
  """
  def from_list(list) when is_list(list) do
    Observable.new(fn observer ->
      {:ok, _pid} =
        Task.start(fn ->
          emit_list_safely(list, observer)
        end)

      # Return unsubscribe function (task will complete anyway)
      fn -> :ok end
    end)
  end

  defp emit_list_safely(list, observer) do
    result =
      list
      |> Enum.reduce_while(:ok, fn item, _acc ->
        case safe_apply(observer.next, item) do
          {:ok, _} ->
            {:cont, :ok}

          {:error, reason} ->
            safe_apply(observer.error, {:error, reason})
            {:halt, {:error, reason}}
        end
      end)

    case result do
      :ok -> safe_apply(observer.complete)
      _ -> :ok
    end
  end

  @doc """
  Creates an observable from a range of numbers.
  """
  def from_range(range) do
    from_list(Enum.to_list(range))
  end

  @doc """
  Creates an observable that emits values at regular intervals.
  """
  def interval(milliseconds, value_fn \\ fn i -> i end) do
    Observable.new(fn observer ->
      {:ok, pid} =
        {:ok, _pid} =
        Task.start(fn ->
          interval_loop_safe(observer, milliseconds, value_fn, 0)
        end)

      # Return unsubscribe function
      fn ->
        Process.exit(pid, :normal)
      end
    end)
  end

  defp interval_loop_safe(observer, ms, value_fn, counter) do
    with {:ok, value} <- safe_apply(value_fn, counter),
         {:ok, _} <- safe_apply(observer.next, value) do
      :timer.sleep(ms)
      interval_loop_safe(observer, ms, value_fn, counter + 1)
    else
      {:error, reason} ->
        safe_apply(observer.error, {:error, reason})
    end
  end

  @doc """
  Creates an observable that emits a single value after a delay.
  """
  def timer(milliseconds, value) do
    Observable.new(fn observer ->
      {:ok, pid} =
        {:ok, _pid} =
        Task.start(fn ->
          :timer.sleep(milliseconds)

          with {:ok, _} <- safe_apply(observer.next, value) do
            safe_apply(observer.complete)
          else
            {:error, reason} ->
              safe_apply(observer.error, {:error, reason})
          end
        end)

      fn -> Process.exit(pid, :normal) end
    end)
  end

  @doc """
  Creates an observable from Store state changes.
  """
  def from_store_path(path, store \\ Store) do
    Observable.new(fn observer ->
      # Emit current value immediately
      with {:ok, current_value} <- safe_get_store_state(path, store),
           {:ok, _} <- safe_apply(observer.next, current_value) do
        # Subscribe to changes
        subscribe_to_store_safely(path, observer, store)
      else
        {:error, reason} ->
          safe_apply(observer.error, {:error, reason})
          fn -> :ok end
      end
    end)
  end

  defp safe_get_store_state(path, store) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      case Process.whereis(store) do
        nil ->
          {:error, :store_not_found}

        _pid ->
          {:ok, Store.get_state(path, store)}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp subscribe_to_store_safely(path, observer, store) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      Store.subscribe(
        path,
        fn new_value ->
          safe_apply(observer.next, new_value)
        end,
        store
      )
    end)
    |> case do
      {:ok, result} ->
        result

      {:error, error} ->
        Logger.error("Store subscription failed: #{inspect(error)}")
        fn -> :ok end
    end
  end

  @doc """
  Creates an observable from UI events.
  """
  def from_events(_event_type) do
    Observable.new(fn observer ->
      # Register event listener with safe handler
      _event_handler = fn event ->
        safe_apply(observer.next, event)
      end

      # This would integrate with the actual event system
      # For now, returning a placeholder unsubscribe function
      fn -> :ok end
    end)
  end

  ## Operators

  @doc """
  Transforms values in the stream using a mapping function.
  """
  def map(%Observable{} = observable, mapper_fn)
      when is_function(mapper_fn, 1) do
    Observable.new(fn observer ->
      new_observer =
        Observer.new(
          fn value ->
            with {:ok, mapped_value} <- safe_apply(mapper_fn, value),
                 {:ok, _} <- safe_apply(observer.next, mapped_value) do
              :ok
            else
              {:error, reason} ->
                safe_apply(observer.error, {:error, reason})
            end
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Filters values in the stream based on a predicate.
  """
  def filter(%Observable{} = observable, predicate_fn)
      when is_function(predicate_fn, 1) do
    Observable.new(fn observer ->
      new_observer =
        Observer.new(
          fn value ->
            with {:ok, should_emit} <- safe_apply(predicate_fn, value) do
              emit_if_predicate_matches(should_emit, observer, value)
              :ok
            else
              {:error, reason} ->
                safe_apply(observer.error, {:error, reason})
            end
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Takes only the first N values from the stream.
  """
  def take(%Observable{} = observable, count)
      when is_integer(count) and count > 0 do
    Observable.new(fn observer ->
      counter = :counters.new(1, [])
      :counters.put(counter, 1, 0)

      new_observer =
        Observer.new(
          fn value ->
            current = :counters.get(counter, 1)
            handle_take_value(current, count, counter, observer, value)
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Skips the first N values from the stream.
  """
  def skip(%Observable{} = observable, count)
      when is_integer(count) and count >= 0 do
    Observable.new(fn observer ->
      counter = :counters.new(1, [])
      :counters.put(counter, 1, 0)

      new_observer =
        Observer.new(
          fn value ->
            current = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)

            emit_if_skip_threshold_reached(current, count, observer, value)
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Debounces values, only emitting after a period of silence.
  """
  def debounce(%Observable{} = observable, milliseconds) do
    Observable.new(fn observer ->
      {:ok, debouncer} =
        Raxol.UI.State.Streams.DebouncerServer.start_link(
          observer,
          milliseconds
        )

      new_observer =
        Observer.new(
          fn value ->
            Raxol.UI.State.Streams.DebouncerServer.emit(debouncer, value)
          end,
          fn error ->
            Raxol.UI.State.Streams.DebouncerServer.stop(debouncer)
            safe_apply(observer.error, error)
          end,
          fn ->
            Raxol.UI.State.Streams.DebouncerServer.stop(debouncer)
            safe_apply(observer.complete)
          end
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  # Debouncer GenServer for managing debounced emissions
  defmodule DebouncerServer do
    use GenServer

    def start_link(observer, delay) do
      GenServer.start_link(__MODULE__, {observer, delay})
    end

    def emit(server, value) do
      _ = GenServer.cast(server, {:emit, value})
      :ok
    end

    def stop(server) do
      GenServer.stop(server, :normal)
    end

    @impl GenServer
    def init({observer, delay}) do
      {:ok, %{observer: observer, delay: delay, timer: nil, last_value: nil}}
    end

    @impl GenServer
    def handle_cast({:emit, value}, state) do
      # Cancel existing timer if present
      _ = Raxol.UI.State.Streams.cancel_existing_timer(state.timer)

      # Start new timer
      timer = Process.send_after(self(), :flush, state.delay)
      {:noreply, %{state | timer: timer, last_value: value}}
    end

    @impl GenServer
    def handle_info(:flush, state) do
      Raxol.UI.State.Streams.emit_debounced_value(
        state.last_value,
        state.observer
      )

      {:noreply, %{state | timer: nil, last_value: nil}}
    end
  end

  @doc """
  Reduces values in the stream to a single value.
  """
  def reduce(%Observable{} = observable, initial, reducer_fn)
      when is_function(reducer_fn, 2) do
    Observable.new(fn observer ->
      accumulator = :atomics.new(1, [])
      # Use as a reference holder
      :atomics.put(accumulator, 1, 0)
      acc_ref = make_ref()
      _ = ProcessStore.put({:stream_accumulator, acc_ref}, initial)

      new_observer =
        Observer.new(
          fn value ->
            current_acc = ProcessStore.get({:stream_accumulator, acc_ref})

            with {:ok, new_acc} <- safe_apply_2(reducer_fn, current_acc, value) do
              _ = ProcessStore.put({:stream_accumulator, acc_ref}, new_acc)
              :ok
            else
              {:error, reason} ->
                safe_apply(observer.error, {:error, reason})
            end
          end,
          observer.error,
          fn ->
            final_value = ProcessStore.get({:stream_accumulator, acc_ref})
            _ = ProcessStore.delete({:stream_accumulator, acc_ref})
            safe_apply(observer.next, final_value)
            safe_apply(observer.complete)
          end
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Combines latest values from multiple streams.
  """
  def combine_latest(observables) when is_list(observables) do
    Observable.new(fn observer ->
      {:ok, combiner} =
        Raxol.UI.State.Streams.CombinerServer.start_link(observables, observer)

      # Subscribe to all observables
      subscriptions =
        observables
        |> Enum.with_index()
        |> Enum.map(fn {obs, index} ->
          obs.subscribe_fn.(
            Observer.new(
              fn value ->
                Raxol.UI.State.Streams.CombinerServer.update(
                  combiner,
                  index,
                  value
                )
              end,
              fn error ->
                Raxol.UI.State.Streams.CombinerServer.error(combiner, error)
              end,
              fn ->
                Raxol.UI.State.Streams.CombinerServer.complete(combiner, index)
              end
            )
          )
        end)

      # Return unsubscribe function
      fn ->
        Enum.each(subscriptions, fn unsub -> unsub.() end)
        GenServer.stop(combiner)
      end
    end)
  end

  # Combiner GenServer for managing combined streams
  defmodule CombinerServer do
    use GenServer

    def start_link(observables, observer) do
      GenServer.start_link(__MODULE__, {length(observables), observer})
    end

    def update(server, index, value) do
      _ = GenServer.cast(server, {:update, index, value})
      :ok
    end

    def error(server, error) do
      _ = GenServer.cast(server, {:error, error})
      :ok
    end

    def complete(server, index) do
      _ = GenServer.cast(server, {:complete, index})
      :ok
    end

    @impl GenServer
    def init({count, observer}) do
      {:ok,
       %{
         values: List.duplicate(nil, count),
         has_value: List.duplicate(false, count),
         completed: List.duplicate(false, count),
         observer: observer,
         errored: false
       }}
    end

    @impl GenServer
    def handle_cast({:update, index, value}, state) do
      handle_combiner_update(state, index, value)
    end

    @impl GenServer
    def handle_cast({:error, error}, state) do
      handle_combiner_error(state, error)
    end

    @impl GenServer
    def handle_cast({:complete, index}, state) do
      new_completed = List.replace_at(state.completed, index, true)

      complete_if_all_streams_done(new_completed, state.errored, state.observer)

      {:noreply, %{state | completed: new_completed}}
    end

    # Helper functions
    defp handle_combiner_update(%{errored: true} = state, _index, _value),
      do: {:noreply, state}

    defp handle_combiner_update(state, index, value) do
      new_values = List.replace_at(state.values, index, value)
      new_has_value = List.replace_at(state.has_value_flags, index, true)

      case Enum.all?(new_has_value) do
        true ->
          Raxol.UI.State.Streams.safe_apply(state.observer.next, new_values)

          {:noreply,
           %{state | values: new_values, has_value_flags: new_has_value}}

        false ->
          {:noreply,
           %{state | values: new_values, has_value_flags: new_has_value}}
      end
    end

    defp handle_combiner_error(%{errored: true} = state, _error),
      do: {:noreply, state}

    defp handle_combiner_error(state, error) do
      Raxol.UI.State.Streams.safe_apply(state.observer.error, error)
      {:noreply, %{state | errored: true}}
    end

    defp complete_if_all_streams_done(completed_flags, errored, observer) do
      case {Enum.all?(completed_flags), errored} do
        {true, false} -> Raxol.UI.State.Streams.safe_apply(observer.complete)
        _ -> :ok
      end
    end
  end

  @doc """
  Subscribes to an observable with an observer or simple next function.
  """
  def subscribe(%Observable{} = observable, observer_or_fn) do
    observer =
      case observer_or_fn do
        %Observer{} = obs -> obs
        fun when is_function(fun, 1) -> Observer.new(fun)
        _ -> raise ArgumentError, "Invalid observer"
      end

    subscription_id = System.unique_integer([:positive, :monotonic])
    unsubscribe_fn = observable.subscribe_fn.(observer)

    Subscription.new(subscription_id, unsubscribe_fn, observable)
  end

  @doc """
  Unsubscribes from an observable.
  """
  def unsubscribe(%Subscription{} = subscription) do
    unsubscribe_if_active(subscription)
  end

  ## Helper functions for safe function application

  @doc false
  def safe_apply(fun, arg \\ nil) when is_function(fun) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      arity = :erlang.fun_info(fun, :arity) |> elem(1)

      case arity do
        0 -> {:ok, fun.()}
        1 -> {:ok, fun.(arg)}
        _ -> {:error, :invalid_function_arity}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, thrown}} -> {:error, {:throw, thrown}}
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  def safe_apply_2(fun, arg1, arg2) when is_function(fun, 2) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      fun.(arg1, arg2)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, thrown}} -> {:error, {:throw, thrown}}
      {:error, error} -> {:error, error}
    end
  end

  ## Private helper functions for pattern matching refactoring

  defp emit_if_predicate_matches(true, observer, value),
    do: safe_apply(observer.next, value)

  defp emit_if_predicate_matches(false, _observer, _value), do: :ok

  defp handle_take_value(current, count, counter, observer, value)
       when current < count do
    :counters.add(counter, 1, 1)
    safe_apply(observer.next, value)
    complete_if_count_reached(current + 1, count, observer)
  end

  defp handle_take_value(_current, _count, _counter, _observer, _value), do: :ok

  defp complete_if_count_reached(new_count, count, observer)
       when new_count >= count do
    safe_apply(observer.complete)
  end

  defp complete_if_count_reached(_new_count, _count, _observer), do: :ok

  defp emit_if_skip_threshold_reached(current, count, observer, value)
       when current >= count do
    safe_apply(observer.next, value)
  end

  defp emit_if_skip_threshold_reached(_current, _count, _observer, _value),
    do: :ok

  def cancel_existing_timer(nil), do: :ok
  def cancel_existing_timer(timer), do: Process.cancel_timer(timer)

  def emit_debounced_value(nil, _observer), do: :ok

  def emit_debounced_value(value, observer) do
    Raxol.UI.State.Streams.safe_apply(observer.next, value)
  end

  # Unused functions - commented out to reduce warnings
  # defp handle_combiner_update(%{errored: true} = state, _index, _value),
  #   do: {:noreply, state}

  # defp handle_combiner_update(state, index, value) do
  #   new_values = List.replace_at(state.values, index, value)
  #   new_has_value = List.replace_at(state.has_value, index, true)

  #   # Emit if all streams have emitted at least once
  #   emit_combined_if_all_ready(new_has_value, new_values, state.observer)

  #   {:noreply, %{state | values: new_values, has_value: new_has_value}}
  # end

  # defp emit_combined_if_all_ready(has_value_flags, values, observer) do
  #   case Enum.all?(has_value_flags) do
  #     true -> Raxol.UI.State.Streams.safe_apply(observer.next, values)
  #     false -> :ok
  #   end
  # end

  # defp handle_combiner_error(%{errored: true} = state, _error),
  #   do: {:noreply, state}

  # defp handle_combiner_error(state, error) do
  #   Raxol.UI.State.Streams.safe_apply(state.observer.error, error)
  #   {:noreply, %{state | errored: true}}
  # end

  # defp complete_if_all_streams_done(completed_flags, errored, observer) do
  #   case {Enum.all?(completed_flags), errored} do
  #     {true, false} -> Raxol.UI.State.Streams.safe_apply(observer.complete)
  #     _ -> :ok
  #   end
  # end

  defp unsubscribe_if_active(%{active: false} = subscription), do: subscription

  defp unsubscribe_if_active(subscription) do
    subscription.unsubscribe_fn.()
    %{subscription | active: false}
  end
end
