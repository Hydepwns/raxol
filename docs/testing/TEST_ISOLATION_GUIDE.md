# Test Isolation Guide

## Current Issues

Tests fail when run in the full suite but pass individually due to:
- Dynamic module loading/reloading from plugin fixtures
- Shared global process state
- Process name conflicts
- Test execution order dependencies

## Recommended Fixes

### 1. Isolate Plugin Tests with Module Prefixes

**Problem**: Plugin fixtures redefine the same module names repeatedly.

**Solution**: Use unique module names per test or sandbox modules.

```elixir
# In plugin_server_test.exs
setup do
  # Generate unique module prefix for this test
  test_id = :erlang.unique_integer([:positive])
  module_prefix = "TestPlugin#{test_id}"

  {:ok, pid} = PluginServer.start_link(
    name: :"PluginServer#{test_id}",  # Unique name
    plugin_paths: [],
    auto_load: false
  )

  on_exit(fn ->
    if Process.alive?(pid), do: GenServer.stop(pid)
  end)

  %{plugin_server: pid, module_prefix: module_prefix}
end
```

### 2. Use ExUnit's `start_supervised/2` for Process Management

**Problem**: Tests manually start/stop GenServers, causing conflicts.

**Solution**: Let ExUnit manage process lifecycle.

```elixir
# Before (problematic)
setup do
  case Process.whereis(SessionBridge) do
    nil -> {:ok, _pid} = SessionBridge.start_link([])
    _pid -> :ok
  end
  :ok
end

# After (isolated)
setup do
  # ExUnit will automatically stop this after the test
  _pid = start_supervised!(SessionBridge)
  :ok
end
```

### 3. Make Global Processes Test-Specific

**Problem**: `test_helper.exs` starts global processes that tests share.

**Solution**: Start processes in individual test `setup` blocks instead.

```elixir
# test_helper.exs - REMOVE global process starts
# - Don't start EventManager globally
# - Don't start Registry globally
# - Don't start ProcessStore globally

# individual_test.exs - ADD per-test isolation
setup do
  # Each test gets its own registry
  registry_name = :"test_registry_#{:erlang.unique_integer([:positive])}"
  start_supervised!({Registry, keys: :duplicate, name: registry_name})

  # Each test gets its own event manager
  event_manager_name = :"test_event_manager_#{:erlang.unique_integer([:positive])}"
  start_supervised!({Raxol.Core.Events.EventManager, name: event_manager_name})

  %{registry: registry_name, event_manager: event_manager_name}
end
```

### 4. Add Explicit Module Loading Checks

**Problem**: `function_exported?` races with dynamic compilation.

**Solution**: Ensure modules are loaded before checking.

```elixir
# Before
test "defines handle_in/3 callback" do
  assert function_exported?(RaxolWeb.TerminalChannel, :handle_in, 3)
end

# After
test "defines handle_in/3 callback" do
  # Ensure module is fully loaded
  Code.ensure_loaded!(RaxolWeb.TerminalChannel)
  # Small delay to ensure compilation is complete
  Process.sleep(10)
  assert function_exported?(RaxolWeb.TerminalChannel, :handle_in, 3)
end
```

### 5. Use `:async true` Where Safe

**Problem**: Tests run sequentially even when they could be parallel.

**Solution**: Enable async for tests without shared state.

```elixir
# Safe for async (no global state, no named processes)
defmodule Raxol.SomeTest do
  use ExUnit.Case, async: true  # ✓ Safe

  test "pure function" do
    assert MyModule.add(1, 2) == 3
  end
end

# Not safe for async (uses named processes)
defmodule Raxol.PluginServerTest do
  use ExUnit.Case, async: false  # ✗ Required

  test "starts plugin server" do
    {:ok, _} = PluginServer.start_link(name: PluginServer)
  end
end
```

### 6. Clean Up Dynamic Modules

**Problem**: Plugin tests leave modules defined in memory.

**Solution**: Purge modules after tests.

```elixir
setup do
  loaded_modules = []

  on_exit(fn ->
    # Purge all modules loaded during test
    Enum.each(loaded_modules, fn mod ->
      :code.purge(mod)
      :code.delete(mod)
    end)
  end)

  %{loaded_modules: loaded_modules}
end
```

## Priority Actions

### High Priority (Do First)

1. **Update TerminalChannel and Presence Tests**
   - Add `Code.ensure_loaded!` before `function_exported?` checks
   - Use unique process names in setup

2. **Fix Plugin Tests**
   - Use `start_supervised!` for PluginServer
   - Generate unique module names per test

### Medium Priority

3. **Refactor test_helper.exs**
   - Move global process starts to helper functions
   - Let individual tests opt-in to needed services

4. **Add Test Utilities**
   - Create `TestHelpers.start_test_registry/0`
   - Create `TestHelpers.start_test_event_manager/0`

### Low Priority

5. **Enable More Async Tests**
   - Audit tests for async safety
   - Convert safe tests to `async: true`

## Example: Complete Fix for TerminalChannelTest

```elixir
defmodule RaxolWeb.TerminalChannelTest do
  use ExUnit.Case, async: false

  # Use unique names for test processes
  setup do
    test_id = :erlang.unique_integer([:positive])

    # Start supervised processes with unique names
    session_bridge = start_supervised!(
      {Raxol.Web.SessionBridge, name: :"SessionBridge#{test_id}"}
    )

    persistent_store = start_supervised!(
      {Raxol.Web.PersistentStore, name: :"PersistentStore#{test_id}"}
    )

    # Ensure module is loaded
    Code.ensure_loaded!(RaxolWeb.TerminalChannel)

    %{
      session_bridge: session_bridge,
      persistent_store: persistent_store
    }
  end

  describe "module structure" do
    test "module exists" do
      assert Code.ensure_loaded?(RaxolWeb.TerminalChannel)
    end

    test "defines handle_in/3 callback" do
      # Module already loaded in setup
      assert function_exported?(RaxolWeb.TerminalChannel, :handle_in, 3)
    end
  end
end
```

## Testing the Fixes

After applying fixes, verify with:

```bash
# Run full suite 5 times to catch flakiness
for i in {1..5}; do
  echo "Run $i"
  env TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --seed $RANDOM
done

# Run specific flaky tests repeatedly
env TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test \
  test/raxol_web/channels/terminal_channel_test.exs \
  test/raxol_web/presence_test.exs \
  --seed $RANDOM \
  --repeat-until-failure 10
```
