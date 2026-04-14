# `Raxol.Core.Utils.Debounce`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/debounce.ex#L1)

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

# `t`

```elixir
@type t() :: %Raxol.Core.Utils.Debounce{
  ids: %{required(term()) =&gt; integer()},
  timers: %{required(term()) =&gt; reference()}
}
```

# `cancel`

```elixir
@spec cancel(t(), term()) :: t()
```

Cancels a pending debounced operation.

Returns the updated debounce state.

## Examples

    debounce = Debounce.cancel(debounce, :save)

# `cancel_all`

```elixir
@spec cancel_all(t()) :: t()
```

Cancels all pending debounced operations.

Useful in GenServer terminate callbacks.

## Examples

    def terminate(_reason, state) do
      Debounce.cancel_all(state.debounce)
      :ok
    end

# `clear`

```elixir
@spec clear(t(), term()) :: t()
```

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

# `fire_now`

```elixir
@spec fire_now(t(), term()) :: {:fire, term(), t()} | {:nothing, t()}
```

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

# `new`

```elixir
@spec new() :: %Raxol.Core.Utils.Debounce{ids: %{}, timers: %{}}
```

Creates a new debounce state.

## Examples

    iex> Debounce.new()
    %Debounce{timers: %{}, ids: %{}}

# `pending?`

```elixir
@spec pending?(t(), term()) :: boolean()
```

Checks if there's a pending operation for the given key.

## Examples

    if Debounce.pending?(debounce, :save) do
      Logger.debug("Save is pending")
    end

# `pending_keys`

```elixir
@spec pending_keys(t()) :: [term()]
```

Returns all pending debounce keys.

## Examples

    keys = Debounce.pending_keys(debounce)
    # => [:save, :sync]

# `schedule`

```elixir
@spec schedule(t(), term(), non_neg_integer(), keyword()) :: {t(), reference()}
```

Schedules a debounced operation.

Cancels any existing timer for the given key and schedules a new one.
The message sent will be `{:debounce, key}`.

Returns the updated debounce state and the timer reference.

## Examples

    # Schedule a save operation after 1 second
    {debounce, ref} = Debounce.schedule(debounce, :save, 1000)

    # Schedule with custom message (sent as {:debounce, key, data})
    {debounce, ref} = Debounce.schedule(debounce, :save, 1000, data: changes)

# `valid?`

```elixir
@spec valid?(t(), term(), integer()) :: boolean()
```

Checks if a debounce message is still valid (not stale).

Use this to ignore messages from cancelled timers.

## Examples

    def handle_info({:debounce, :save, id}, state) do
      if Debounce.valid?(state.debounce, :save, id) do
        do_save(state.data)
      end
      {:noreply, state}
    end

---

*Consult [api-reference.md](api-reference.md) for complete listing*
