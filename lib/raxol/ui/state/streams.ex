defmodule Raxol.UI.State.Streams do
  @moduledoc """
  Reactive streams system for real-time data flow in Raxol UI.

  This module provides RxJS-like reactive programming capabilities with:
  - Observable streams of data
  - Operators for transforming data (map, filter, reduce, etc.)
  - Hot and cold observables
  - Backpressure handling
  - Error handling and retry strategies
  - Subscription management
  - Combining multiple streams

  ## Usage

      # Create an observable from a list
      numbers = Streams.from_list([1, 2, 3, 4, 5])
      
      # Transform the stream
      doubled = numbers
      |> Streams.map(fn x -> x * 2 end)
      |> Streams.filter(fn x -> rem(x, 4) == 0 end)
      
      # Subscribe to the stream
      subscription = Streams.subscribe(doubled, fn value ->
        IO.puts("Received: \#{value}")
      end)
      
      # Create streams from events
      click_stream = Streams.from_events(:click)
      |> Streams.debounce(300)
      |> Streams.map(fn event -> event.target end)
      
      # Combine multiple streams
      combined = Streams.combine_latest([stream1, stream2, stream3])
      |> Streams.map(fn [a, b, c] -> a + b + c end)
  """

  alias Raxol.UI.State.Store

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
      GenServer.cast(subject, {:next, value})
    end

    def error(subject, error) do
      GenServer.cast(subject, {:error, error})
    end

    def complete(subject) do
      GenServer.cast(subject, :complete)
    end

    def subscribe(subject, observer) do
      GenServer.call(subject, {:subscribe, observer})
    end

    @impl GenServer
    def init(state) do
      {:ok, state}
    end

    @impl GenServer
    def handle_cast({:next, value}, state) do
      if not state.completed and state.error == nil do
        Enum.each(state.observers, fn {_id, observer} ->
          try do
            observer.next.(value)
          catch
            kind, reason ->
              require Logger

              Logger.error(
                "Error in stream observer: #{inspect(kind)}, #{inspect(reason)}"
              )
          end
        end)
      end

      {:noreply, state}
    end

    @impl GenServer
    def handle_cast({:error, error}, state) do
      if not state.completed do
        Enum.each(state.observers, fn {_id, observer} ->
          try do
            observer.error.(error)
          catch
            kind, reason ->
              require Logger

              Logger.error(
                "Error in stream error handler: #{inspect(kind)}, #{inspect(reason)}"
              )
          end
        end)

        {:noreply, %{state | error: error}}
      else
        {:noreply, state}
      end
    end

    @impl GenServer
    def handle_cast(:complete, state) do
      if not state.completed and state.error == nil do
        Enum.each(state.observers, fn {_id, observer} ->
          try do
            observer.complete.()
          catch
            kind, reason ->
              require Logger

              Logger.error(
                "Error in stream complete handler: #{inspect(kind)}, #{inspect(reason)}"
              )
          end
        end)

        {:noreply, %{state | completed: true, observers: %{}}}
      else
        {:noreply, state}
      end
    end

    @impl GenServer
    def handle_call({:subscribe, observer}, _from, state) do
      cond do
        state.completed ->
          # Observable already completed, call complete immediately
          observer.complete.()
          {:reply, nil, state}

        state.error ->
          # Observable errored, call error immediately
          observer.error.(state.error)
          {:reply, nil, state}

        true ->
          # Add observer
          observer_id = System.unique_integer([:positive, :monotonic])
          new_observers = Map.put(state.observers, observer_id, observer)

          # Return unsubscribe function
          unsubscribe_fn = fn ->
            GenServer.call(self(), {:unsubscribe, observer_id})
          end

          {:reply, unsubscribe_fn, %{state | observers: new_observers}}
      end
    end

    @impl GenServer
    def handle_call({:unsubscribe, observer_id}, _from, state) do
      new_observers = Map.delete(state.observers, observer_id)
      {:reply, :ok, %{state | observers: new_observers}}
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
      Task.start(fn ->
        try do
          Enum.each(list, fn item ->
            observer.next.(item)
          end)

          observer.complete.()
        catch
          kind, reason ->
            observer.error.({kind, reason})
        end
      end)

      # Return unsubscribe function (task will complete anyway)
      fn -> :ok end
    end)
  end

  @doc """
  Creates an observable from a range of numbers.

  ## Examples

      numbers = Streams.from_range(1..10)
  """
  def from_range(range) do
    from_list(Enum.to_list(range))
  end

  @doc """
  Creates an observable that emits values at regular intervals.

  ## Examples

      # Emit every 1000ms
      timer = Streams.interval(1000)
      
      # Emit every 500ms with custom values
      heartbeat = Streams.interval(500, fn i -> "beat-\#{i}" end)
  """
  def interval(milliseconds, value_fn \\ fn i -> i end) do
    Observable.new(fn observer ->
      {:ok, pid} =
        Task.start(fn ->
          interval_loop(observer, milliseconds, value_fn, 0)
        end)

      # Return unsubscribe function
      fn ->
        Process.exit(pid, :normal)
      end
    end)
  end

  defp interval_loop(observer, ms, value_fn, counter) do
    observer.next.(value_fn.(counter))
    :timer.sleep(ms)
    interval_loop(observer, ms, value_fn, counter + 1)
  end

  @doc """
  Creates an observable that emits a single value after a delay.

  ## Examples

      delayed = Streams.timer(1000, "Hello after 1 second")
  """
  def timer(milliseconds, value) do
    Observable.new(fn observer ->
      {:ok, pid} =
        Task.start(fn ->
          :timer.sleep(milliseconds)
          observer.next.(value)
          observer.complete.()
        end)

      fn -> Process.exit(pid, :normal) end
    end)
  end

  @doc """
  Creates an observable from Store state changes.

  ## Examples

      user_stream = Streams.from_store_path([:user, :current])
      |> Streams.filter(fn user -> user != nil end)
  """
  def from_store_path(path, store \\ Store) do
    Observable.new(fn observer ->
      # Emit current value immediately
      current_value = Store.get_state(path, store)
      observer.next.(current_value)

      # Subscribe to changes
      unsubscribe_fn =
        Store.subscribe(
          path,
          fn new_value ->
            observer.next.(new_value)
          end,
          store
        )

      unsubscribe_fn
    end)
  end

  @doc """
  Creates an observable from UI events.

  ## Examples

      clicks = Streams.from_events(:click)
      key_presses = Streams.from_events(:keypress)
  """
  def from_events(event_type) do
    Observable.new(fn observer ->
      # Register event listener
      listener_id = System.unique_integer([:positive, :monotonic])

      # This would integrate with the actual event system
      event_listener = fn event ->
        observer.next.(event)
      end

      # Register with event system (placeholder)
      register_event_listener(event_type, listener_id, event_listener)

      # Return unsubscribe function
      fn ->
        unregister_event_listener(event_type, listener_id)
      end
    end)
  end

  @doc """
  Creates a hot observable subject that can emit values to multiple subscribers.

  ## Examples

      {:ok, subject} = Streams.create_subject()
      
      # Subscribe multiple observers
      Streams.subscribe(subject, fn x -> IO.puts("Observer 1: \#{x}") end)
      Streams.subscribe(subject, fn x -> IO.puts("Observer 2: \#{x}") end)
      
      # Emit values
      Subject.next(subject, "Hello")
      Subject.next(subject, "World")
  """
  def create_subject(opts \\ []) do
    Subject.start_link(opts)
  end

  ## Operators

  @doc """
  Maps each value in the stream to a new value.

  ## Examples

      doubled = stream |> Streams.map(fn x -> x * 2 end)
      strings = stream |> Streams.map(fn x -> to_string(x) end)
  """
  def map(%Observable{} = observable, mapper_fn)
      when is_function(mapper_fn, 1) do
    Observable.new(fn observer ->
      new_observer =
        Observer.new(
          fn value ->
            try do
              mapped_value = mapper_fn.(value)
              observer.next.(mapped_value)
            catch
              kind, reason ->
                observer.error.({kind, reason})
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

  ## Examples

      evens = stream |> Streams.filter(fn x -> rem(x, 2) == 0 end)
      non_nil = stream |> Streams.filter(fn x -> x != nil end)
  """
  def filter(%Observable{} = observable, predicate_fn)
      when is_function(predicate_fn, 1) do
    Observable.new(fn observer ->
      new_observer =
        Observer.new(
          fn value ->
            try do
              if predicate_fn.(value) do
                observer.next.(value)
              end
            catch
              kind, reason ->
                observer.error.({kind, reason})
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

  ## Examples

      first_five = stream |> Streams.take(5)
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

            if current < count do
              :counters.add(counter, 1, 1)
              observer.next.(value)

              if current + 1 >= count do
                observer.complete.()
              end
            end
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Skips the first N values from the stream.

  ## Examples

      skip_first_three = stream |> Streams.skip(3)
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

            if current >= count do
              observer.next.(value)
            end
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Debounces values, only emitting after a period of silence.

  ## Examples

      debounced = stream |> Streams.debounce(300)
  """
  def debounce(%Observable{} = observable, milliseconds) do
    Observable.new(fn observer ->
      timer_ref = :atomics.new(1, [])
      :atomics.put(timer_ref, 1, 0)

      new_observer =
        Observer.new(
          fn value ->
            # Cancel existing timer
            case :atomics.get(timer_ref, 1) do
              0 -> :ok
              old_timer -> Process.cancel_timer(old_timer)
            end

            # Set new timer
            new_timer =
              Process.send_after(self(), {:debounced_emit, value}, milliseconds)

            :atomics.put(timer_ref, 1, new_timer)
          end,
          observer.error,
          observer.complete
        )

      # Handle debounced emissions
      spawn(fn ->
        debounce_loop(observer)
      end)

      observable.subscribe_fn.(new_observer)
    end)
  end

  defp debounce_loop(observer) do
    receive do
      {:debounced_emit, value} ->
        observer.next.(value)
        debounce_loop(observer)
    end
  end

  @doc """
  Throttles values, emitting at most once per time period.

  ## Examples

      throttled = stream |> Streams.throttle(100)
  """
  def throttle(%Observable{} = observable, milliseconds) do
    Observable.new(fn observer ->
      last_emit = :atomics.new(1, [])
      :atomics.put(last_emit, 1, 0)

      new_observer =
        Observer.new(
          fn value ->
            now = System.monotonic_time(:millisecond)
            last = :atomics.get(last_emit, 1)

            if now - last >= milliseconds do
              :atomics.put(last_emit, 1, now)
              observer.next.(value)
            end
          end,
          observer.error,
          observer.complete
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  @doc """
  Reduces the stream to a single value using an accumulator function.

  ## Examples

      sum = stream |> Streams.reduce(0, fn x, acc -> x + acc end)
  """
  def reduce(%Observable{} = observable, initial_acc, reducer_fn)
      when is_function(reducer_fn, 2) do
    Observable.new(fn observer ->
      accumulator = :atomics.new(1, [])
      :atomics.put(accumulator, 1, initial_acc)

      new_observer =
        Observer.new(
          fn value ->
            current_acc = :atomics.get(accumulator, 1)
            new_acc = reducer_fn.(value, current_acc)
            :atomics.put(accumulator, 1, new_acc)
          end,
          observer.error,
          fn ->
            final_acc = :atomics.get(accumulator, 1)
            observer.next.(final_acc)
            observer.complete.()
          end
        )

      observable.subscribe_fn.(new_observer)
    end)
  end

  ## Combining Operators

  @doc """
  Merges multiple observables into one.

  ## Examples

      merged = Streams.merge([stream1, stream2, stream3])
  """
  def merge(observables) when is_list(observables) do
    Observable.new(fn observer ->
      completed_count = :counters.new(1, [])
      :counters.put(completed_count, 1, 0)
      total_count = length(observables)

      unsubscribe_fns =
        Enum.map(observables, fn obs ->
          new_observer =
            Observer.new(
              observer.next,
              observer.error,
              fn ->
                current = :counters.get(completed_count, 1)
                :counters.add(completed_count, 1, 1)

                if current + 1 >= total_count do
                  observer.complete.()
                end
              end
            )

          obs.subscribe_fn.(new_observer)
        end)

      # Return combined unsubscribe function
      fn ->
        Enum.each(unsubscribe_fns, fn unsubscribe_fn ->
          try do
            unsubscribe_fn.()
          catch
            _, _ -> :ok
          end
        end)
      end
    end)
  end

  @doc """
  Combines the latest values from multiple observables.

  ## Examples

      combined = Streams.combine_latest([stream1, stream2, stream3])
  """
  def combine_latest(observables) when is_list(observables) do
    Observable.new(fn observer ->
      # Track latest values from each observable
      latest_values = :ets.new(:latest_values, [:public])
      received_count = :counters.new(1, [])
      :counters.put(received_count, 1, 0)
      total_count = length(observables)

      unsubscribe_fns =
        observables
        |> Enum.with_index()
        |> Enum.map(fn {obs, index} ->
          new_observer =
            Observer.new(
              fn value ->
                # Update latest value for this observable
                :ets.insert(latest_values, {index, value})

                # Check if we've received at least one value from each observable
                current_count = :ets.info(latest_values, :size)

                if current_count == total_count do
                  # Emit combined values
                  combined_values =
                    0..(total_count - 1)
                    |> Enum.map(fn i ->
                      case :ets.lookup(latest_values, i) do
                        [{^i, val}] -> val
                        [] -> nil
                      end
                    end)

                  observer.next.(combined_values)
                end
              end,
              observer.error,
              observer.complete
            )

          obs.subscribe_fn.(new_observer)
        end)

      # Return combined unsubscribe function
      fn ->
        :ets.delete(latest_values)

        Enum.each(unsubscribe_fns, fn unsubscribe_fn ->
          try do
            unsubscribe_fn.()
          catch
            _, _ -> :ok
          end
        end)
      end
    end)
  end

  ## Subscription and Lifecycle

  @doc """
  Subscribes to an observable with a callback function.

  ## Examples

      subscription = Streams.subscribe(observable, fn value ->
        IO.puts("Received: \#{value}")
      end)
      
      # Unsubscribe
      Subscription.unsubscribe(subscription)
  """
  def subscribe(
        observable_or_subject,
        next_fn,
        error_fn \\ nil,
        complete_fn \\ nil
      )

  def subscribe(
        %Observable{} = observable,
        next_fn,
        error_fn,
        complete_fn
      ) do
    observer = Observer.new(next_fn, error_fn, complete_fn)
    subscription_id = System.unique_integer([:positive, :monotonic])

    unsubscribe_fn = observable.subscribe_fn.(observer)

    Subscription.new(subscription_id, unsubscribe_fn, observable)
  end

  def subscribe(
        %Subject{} = subject,
        next_fn,
        error_fn,
        complete_fn
      ) do
    observer = Observer.new(next_fn, error_fn, complete_fn)
    subscription_id = System.unique_integer([:positive, :monotonic])

    unsubscribe_fn = Subject.subscribe(subject, observer)

    if unsubscribe_fn do
      Subscription.new(subscription_id, unsubscribe_fn, subject)
    else
      # Subject already completed/errored
      nil
    end
  end

  @doc """
  Unsubscribes from an observable.
  """
  def unsubscribe(%Subscription{active: true} = subscription) do
    try do
      subscription.unsubscribe_fn.()
    catch
      _, _ -> :ok
    end

    %{subscription | active: false}
  end

  def unsubscribe(%Subscription{active: false} = subscription), do: subscription
  def unsubscribe(nil), do: nil

  # Placeholder functions for event system integration
  defp register_event_listener(_event_type, _listener_id, _callback) do
    # This would integrate with the actual UI event system
    :ok
  end

  defp unregister_event_listener(_event_type, _listener_id) do
    # This would integrate with the actual UI event system
    :ok
  end
end
