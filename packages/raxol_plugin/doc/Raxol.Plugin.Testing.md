# `Raxol.Plugin.Testing`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/plugin/testing.ex#L1)

Test helpers for Raxol plugins.

Provides utilities for exercising plugin callbacks in isolation
without starting the full plugin manager infrastructure.

## Usage

    use ExUnit.Case
    import Raxol.Plugin.Testing

    test "handles events" do
      {:ok, state} = setup_plugin(MyPlugin, %{key: "value"})
      assert_handles_event(MyPlugin, :some_event, state)
    end

# `assert_halts_event`

```elixir
@spec assert_halts_event(module(), term(), term()) :: :halt
```

Asserts that a plugin halts a given event.

Calls `module.filter_event(event, state)` and asserts the result is `:halt`.

## Examples

    assert_halts_event(MyPlugin, :blocked_event, state)

# `assert_handles_command`

```elixir
@spec assert_handles_command(module(), atom() | tuple(), list(), term()) ::
  {term(), term()}
```

Asserts that a plugin handles a command successfully.

Calls `module.handle_command(command, args, state)` and asserts the
result matches `{:ok, new_state, result}`. Returns `{new_state, result}`.

## Examples

    {new_state, result} = assert_handles_command(MyPlugin, :do_thing, [1, 2], state)

# `assert_handles_event`

```elixir
@spec assert_handles_event(module(), term(), term()) :: term()
```

Asserts that a plugin handles an event without halting.

Calls `module.filter_event(event, state)` and asserts the result
matches `{:ok, _}`. Returns the (possibly modified) event.

## Examples

    event = assert_handles_event(MyPlugin, :click, state)

# `setup_plugin`

```elixir
@spec setup_plugin(module(), map()) :: {:ok, term()} | {:error, term()}
```

Initializes a plugin module with the given config and returns its state.

Calls `module.init(config)` and asserts it returns `{:ok, state}`.

## Examples

    {:ok, state} = setup_plugin(MyPlugin, %{})

# `simulate_lifecycle`

```elixir
@spec simulate_lifecycle(module(), map()) :: [{atom(), term()}]
```

Runs a plugin through its full lifecycle: init -> enable -> disable -> terminate.

Asserts each step succeeds. Returns a list of `{callback, result}` tuples
for inspection.

## Examples

    steps = simulate_lifecycle(MyPlugin, %{option: true})
    assert length(steps) == 4

---

*Consult [api-reference.md](api-reference.md) for complete listing*
