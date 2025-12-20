defmodule Raxol.Core.Utils.Debounce do
  @moduledoc """
  Purely functional debounce utilities for delayed operations.

  This module provides a composable way to debounce operations within GenServers
  without spreading timer management code throughout the codebase.

  ## Usage in GenServer State

  Add a debounce field to your state and use the functions to manage it:

      defmodule MyServer do
        use GenServer
        alias Raxol.Core.Utils.Debounce

        defstruct [:data, :debounce]

        def init(_) do
          {:ok, %__MODULE__{data: %{}, debounce: Debounce.new()}}
        end

        def handle_call({:update, value}, _from, state) do
          new_state = %{state | data: value}
          # Schedule save after 1 second, cancels any pending save
          {debounce, _ref} = Debounce.schedule(state.debounce, :save, 1000)
          {:reply, :ok, %{new_state | debounce: debounce}}
        end

        def handle_info({:debounce, :save}, state) do
          do_save(state.data)
          {:noreply, %{state | debounce: Debounce.clear(state.debounce, :save)}}
        end
      end

  ## Key Design Decisions

  - **Purely functional**: All functions return new state, no side effects except scheduling
  - **Composable**: Works with any GenServer state structure
  - **Explicit**: Timer refs are tracked, making cancellation reliable
  - **Idiomatic**: Uses pattern matching and tuples, not exceptions
  """

  alias Raxol.Core.Utils.TimerManager

  @type t :: %__MODULE__{
          timers: %{term() => reference()},
          ids: %{term() => integer()}
        }

  defstruct timers: %{}, ids: %{}

  @doc """
  Creates a new debounce state.

  ## Examples

      iex> Debounce.new()
      %Debounce{timers: %{}, ids: %{}}
  """
  @spec new() :: %__MODULE__{timers: %{}, ids: %{}}
  def new, do: %__MODULE__{}

  @doc """
  Schedules a debounced operation.

  Cancels any existing timer for the given key and schedules a new one.
  The message sent will be `{:debounce, key}`.

  Returns the updated debounce state and the timer reference.

  ## Examples

      # Schedule a save operation after 1 second
      {debounce, ref} = Debounce.schedule(debounce, :save, 1000)

      # Schedule with custom message (sent as {:debounce, key, data})
      {debounce, ref} = Debounce.schedule(debounce, :save, 1000, data: changes)
  """
  @spec schedule(t(), term(), non_neg_integer(), keyword()) ::
          {t(), reference()}
  def schedule(debounce, key, delay_ms, opts \\ []) do
    # Cancel existing timer if any
    debounce = cancel(debounce, key)

    # Generate unique ID to handle race conditions
    id = System.unique_integer([:positive])

    # Build the message
    message =
      case Keyword.get(opts, :data) do
        nil -> {:debounce, key, id}
        data -> {:debounce, key, id, data}
      end

    # Schedule new timer
    ref = TimerManager.send_after(message, delay_ms)

    new_debounce = %{
      debounce
      | timers: Map.put(debounce.timers, key, ref),
        ids: Map.put(debounce.ids, key, id)
    }

    {new_debounce, ref}
  end

  @doc """
  Cancels a pending debounced operation.

  Returns the updated debounce state.

  ## Examples

      debounce = Debounce.cancel(debounce, :save)
  """
  @spec cancel(t(), term()) :: t()
  def cancel(debounce, key) do
    case Map.get(debounce.timers, key) do
      nil ->
        debounce

      ref ->
        TimerManager.safe_cancel(ref)

        %{
          debounce
          | timers: Map.delete(debounce.timers, key),
            ids: Map.delete(debounce.ids, key)
        }
    end
  end

  @doc """
  Clears a debounce entry after it has fired.

  Call this in your handle_info after processing the debounced message.

  ## Examples

      def handle_info({:debounce, :save, id}, state) do
        if Debounce.valid?(state.debounce, :save, id) do
          do_save(state.data)
          {:noreply, %{state | debounce: Debounce.clear(state.debounce, :save)}}
        else
          # Stale timer, ignore
          {:noreply, state}
        end
      end
  """
  @spec clear(t(), term()) :: t()
  def clear(debounce, key) do
    %{
      debounce
      | timers: Map.delete(debounce.timers, key),
        ids: Map.delete(debounce.ids, key)
    }
  end

  @doc """
  Checks if a debounce message is still valid (not stale).

  Use this to ignore messages from cancelled timers.

  ## Examples

      def handle_info({:debounce, :save, id}, state) do
        if Debounce.valid?(state.debounce, :save, id) do
          do_save(state.data)
        end
        {:noreply, state}
      end
  """
  @spec valid?(t(), term(), integer()) :: boolean()
  def valid?(debounce, key, id) do
    Map.get(debounce.ids, key) == id
  end

  @doc """
  Checks if there's a pending operation for the given key.

  ## Examples

      if Debounce.pending?(debounce, :save) do
        Logger.debug("Save is pending")
      end
  """
  @spec pending?(t(), term()) :: boolean()
  def pending?(debounce, key) do
    Map.has_key?(debounce.timers, key)
  end

  @doc """
  Cancels all pending debounced operations.

  Useful in GenServer terminate callbacks.

  ## Examples

      def terminate(_reason, state) do
        Debounce.cancel_all(state.debounce)
        :ok
      end
  """
  @spec cancel_all(t()) :: t()
  def cancel_all(debounce) do
    Enum.each(debounce.timers, fn {_key, ref} ->
      TimerManager.safe_cancel(ref)
    end)

    %__MODULE__{}
  end

  @doc """
  Returns all pending debounce keys.

  ## Examples

      keys = Debounce.pending_keys(debounce)
      # => [:save, :sync]
  """
  @spec pending_keys(t()) :: [term()]
  def pending_keys(debounce) do
    Map.keys(debounce.timers)
  end

  @doc """
  Immediately triggers a pending debounced operation.

  Cancels the timer and returns `{:fire, key}` if there was a pending operation,
  or `:nothing` if there was no pending operation.

  The caller is responsible for executing the operation.

  ## Examples

      case Debounce.fire_now(debounce, :save) do
        {:fire, :save, debounce} ->
          do_save(state.data)
          %{state | debounce: debounce}

        {:nothing, debounce} ->
          state
      end
  """
  @spec fire_now(t(), term()) :: {:fire, term(), t()} | {:nothing, t()}
  def fire_now(debounce, key) do
    case Map.get(debounce.timers, key) do
      nil ->
        {:nothing, debounce}

      _ref ->
        {:fire, key, cancel(debounce, key)}
    end
  end
end
