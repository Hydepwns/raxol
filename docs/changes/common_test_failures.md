# Common Test Failures in Raxol

This document outlines common types of test failures encountered in the Raxol project, along with their typical causes and solutions. This can help developers and future AI agents in diagnosing and fixing test suite issues more efficiently.

## 1. `Mox.UnexpectedCallError`

- **Description**: This error indicates that a mocked function was called during a test run, but no prior expectation for this call was set using `Mox.expect/3`, `Mox.stub/3`, or `Mox.stub_with/2`.
- **Example**:

  ```
  ** (Mox.UnexpectedCallError) no expectation defined for MyMockModule.my_function/1 in process #PID<...> with args [...]
  ```

- **Common Cause**:
  - The test setup (e.g., within a `setup` block or the test function itself) did not anticipate a specific call to a mocked module that occurs in the code path being tested.
  - If mocks are defined in one process (e.g., the main test process) but called from another (e.g., a GenServer managed by the `PluginManager`), global mock setup (`setup :set_mox_global` and ensuring mocks are passed correctly) might be necessary.
- **Solution**:
  - Carefully trace the code path executed by the test.
  - Before the code that triggers the call to the mocked function is executed, ensure you have a corresponding `Mox.expect/3` (if you want to verify the call happens) or `Mox.stub/3` / `Mox.stub_with/2` (if you just want to provide a return value without strict verification).
  - Pay close attention to the process in which the mock is called versus where it's defined, especially when testing asynchronous code or GenServers.

## 2. `FunctionClauseError`

- **Description**: This error occurs when a function is called with arguments (in terms of type, number, or pattern) that do not match any of its defined function clauses.
- **Example**:

  ```
  ** (FunctionClauseError) no function clause matching in MyModule.my_function/2
  Args: ("an_atom_instead_of_a_map", %{key: "value"})
  Attempted function clause: def my_function(param1_map, param2_map) when is_map(param1_map) and is_map(param2_map)
  ```

- **Common Cause**:
  - Passing an argument of an incorrect type (e.g., a string where a map is expected).
  - Passing the wrong number of arguments.
  - The value of an argument doesn't match a specific pattern in any clause (e.g., expecting `{:ok, value}` but receiving `{:error, reason}`).
- **Solution**:
  - Examine the error message carefully. It usually shows the arguments passed and the function clauses it attempted to match.
  - Check the function definition in the source code to understand its expected arguments and patterns.
  - Verify the call site in the test (or the code being tested) to ensure the arguments are correct.

## 3. `KeyError`

- **Description**: This error happens when your code tries to access a key in a map that does not exist.
- **Example**:

  ```
  ** (KeyError) key :my_expected_key not found in: %{another_key: "value"}
  ```

- **Common Cause**:
  - A typo in the key name when trying to access it.
  - An assumption that a key will always be present in a map, but a certain code path leads to its absence.
  - Data transformation steps might have removed or renamed the key.
- **Solution**:
  - Double-check the spelling of the key.
  - Before accessing a key directly (e.g., `my_map.my_key` or `my_map[:my_key]`), consider using `Map.has_key?(my_map, :my_key)` to check for its presence or `Map.get(my_map, :my_key, default_value)` to provide a fallback if it might be missing.
  - Inspect the map's contents just before the point of failure to understand its actual structure.

## 4. Assertion Failures

- **Description**: These are a broad category where a specific `assert` or `refute` statement in a test fails because the actual outcome of the code execution did not match the test's expectation.
- **Examples**:
  - `Assertion with == failed` / `Expected left to be equal to right`
  - `Expected truthy, got false` (or `Expected falsy, got true`)
  - `Assertion with in failed` (expected an element to be in a list, or a substring in a string)
- **Common Cause**:
  - A logic error in the function or module being tested.
  - The test's assertion is incorrect or makes wrong assumptions about the expected behavior.
  - Changes in one part of the system inadvertently affecting the behavior of another part covered by the test.
  - Incorrect test setup leading to an unexpected state.
- **Solution**:
  - Carefully read the assertion failure message, which usually shows the expected and actual values.
  - Debug the code path that the test is exercising. Use `IO.inspect/2` or a debugger to understand the state of variables at different points.
  - Review the test's setup and the assertion itself to ensure they accurately reflect the intended behavior of the code.
  - Consider if recent changes elsewhere could have impacted this test.

## 5. `FunctionClauseError` in `IO.chardata_to_string/1` (during Path operations)

- **Description**: This specific `FunctionClauseError` occurs if `IO.chardata_to_string/1` is called with `nil`, often indirectly through path manipulation functions like `Path.join/2` or `Path.wildcard/1`.
- **Example from Plugin Loading**:

  ```
  [error] [Elixir.Raxol.Core.Runtime.Plugins.Loader] Error during plugin discovery: %FunctionClauseError{module: IO, function: :chardata_to_string, arity: 1, kind: nil, args: nil, clauses: nil}
  ```

- **Common Cause**:
  - A module attribute (e.g., `@default_plugin_path`) used to provide a default path is referenced but not defined, causing it to default to `nil`.
  - Configuration providing a path (e.g., for plugin directories) is missing or incorrectly results in `nil`, which is then used in path operations.
- **Solution**:
  - Ensure any module attributes used for default paths are correctly defined before use.
  - Verify that configuration providing paths is correctly loaded and supplies valid string paths, not `nil`.
  - Trace how path arguments are constructed and passed to `Path` module functions to ensure they are always binaries (strings).

## Note on Plugin Command Handler Errors (`UndefinedFunctionError` / `FunctionClauseError`)

A common pattern for errors when testing plugin commands involves mismatches between how the `CommandHelper` calls a plugin's command handler and how the plugin defines that handler.

- **Cause**: The `CommandHelper` uses `apply(plugin_module, :handle_command, [command_name_atom, args_list, current_plugin_state])`. This means plugins _must_ define their command handlers as `handle_command(command_name, args_list, state)`.
  - If a plugin defines `handle_command/2` (e.g., `handle_command(args_list, state)`), it will result in an `UndefinedFunctionError` for `handle_command/3`.
  - If a plugin defines `handle_command/3` but the first argument doesn't match the `command_name_atom` (e.g., `handle_command([arg1, arg2], other_arg, state)` instead of `handle_command(:my_command_name, [arg1, arg2], state)`), it can lead to a `FunctionClauseError` as no clause matches the specific command name atom.
- **Solution**:
  - Always define plugin command handlers with three arguments: `command_name` (atom), `args_list` (list of arguments for that specific command), and `state` (the plugin's current state).
  - Ensure the first argument in the function clause correctly matches the atom version of the command name being dispatched.
  - Verify the `args_list` pattern matches the arity and types declared in the plugin's `get_commands/0` for that command.

By systematically addressing these common error types, we can improve the stability and reliability of the Raxol test suite.

## 6. Unhandled Exits in `on_exit` Handlers

- **Description**: Tests may fail not because of an issue in the code being tested or an incorrect assertion, but because an unhandled error occurs within an `on_exit` callback, typically used for test cleanup. This crashes the `on_exit` process, and ExUnit reports this as a test failure.
- **Example (from `test/raxol/runtime_test.exs` before fix)**:

  ```
  ** (exit) exited in: GenServer.stop(#PID<...>, :shutdown, :infinity)
      ** (EXIT) no process: the process is not alive or there's no process currently associated with the given name...
      stacktrace:
    (elixir 1.18.3) lib/gen_server.ex:1089: GenServer.stop/3
    test/raxol/runtime_test.exs:XXX: anonymous fn/1 in Raxol.RuntimeTest.__ex_unit_setup_0/1
    ...
  ```

- **Common Cause**:
  - Attempting to stop processes (e.g., Supervisors or GenServers via `Supervisor.stop/3` or `GenServer.stop/3`) in `on_exit` that might have already been stopped by the test itself, leading to `:noproc` errors.
  - The shutdown sequence of the supervisor/GenServer being stopped is not perfectly clean and raises an exception that `Supervisor.stop/3` or `GenServer.stop/3` doesn't handle internally, causing it to exit.
  - Other cleanup operations (like file deletion or ETS table operations) failing due to unexpected state.
- **Solution**:

  - Wrap potentially problematic cleanup operations within `on_exit` handlers in `try...catch` blocks. This allows the error to be logged without crashing the entire `on_exit` handler, thus preventing it from masking the true test result.

    ```elixir
    on_exit(fn ->
      try do
        # Potentially problematic cleanup, e.g., stopping a supervisor
        Supervisor.stop(supervisor_pid, :shutdown, :infinity)
      catch
        :exit, reason ->
          Logger.error("[TEST on_exit] Cleanup failed: #{inspect(reason)}")
      end
      # Other cleanup steps
    end)
    ```

  - Ensure that state assumptions made in `on_exit` (e.g., a process is still running) are valid or handled gracefully.
  - While catching the error allows tests to pass, the logged error should ideally be investigated to make the underlying shutdown or cleanup more robust if it indicates a real issue.

## 7. Issues with Mocked Callbacks in Event Systems

- **Description**: Tests involving an event system (like `EventManager`) where a mocked module's `init` function is supposed to register a callback handler can be tricky. If the mock's `init` is stubbed (e.g., using `Mox.stub/3`), interactions within that stub (like calling `EventManager.register_handler/3`) might not behave as expected, leading to the event handler not being correctly registered or called.
- **Example Scenario**:
  - A module `MySystem` calls `feature_module.init()` when a feature is enabled.
  - `feature_module.init()` is responsible for calling `EventManager.register_handler(..., feature_module, :handle_event_callback)`.
  - In a test, `feature_module` is mocked (`MockedFeatureModule`).
  - `Mox.stub(MockedFeatureModule, :init, fn -> EventManager.register_handler(..., MockedFeatureModule, :handle_event_callback); :ok end)` is set up.
  - `Mox.expect(MockedFeatureModule, :handle_event_callback, fn _event -> ... end)` is also set up.
  - An event is dispatched via `EventManager.dispatch/1`, but the expectation on `:handle_event_callback` is not met, and `assert_received` for messages sent from the callback fails.
- **Common Cause**:
  - The context or timing of `EventManager.register_handler/3` when called from _within_ the anonymous function of `Mox.stub/3` for the mock's `:init` might lead to the handler not being properly associated with the test process or the `EventManager`'s state for that process.
  - The `EventManager.init()` (which typically clears handlers for the current process) might be called after the problematic registration attempt if the order of operations is not carefully managed.
- **Solution**:

  - **Manual Handler Registration in Test**: Instead of relying on the mocked `init` function to register the handler, perform the registration explicitly in the test _after_ the event system has been initialized and _before_ the feature depending on the mock is enabled.
    1. Initialize the event system (e.g., `MySystem.enable_feature(:events)` which calls `EventManager.init()`).
    2. Directly call `EventManager.register_handler(:my_event, MockedFeatureModule, :handle_event_callback)` in the test.
    3. Stub the mock's `init` function to be a simple no-op (e.g., `Mox.stub(MockedFeatureModule, :init, fn -> :ok end)`).
    4. Enable the feature that uses the mock (e.g., `MySystem.enable_feature(:the_feature_using_mock)`), which will now call the simple stubbed `:init`.
    5. Set up `Mox.expect` for `MockedFeatureModule.handle_event_callback/1` as usual.
  - This approach gives the test more direct control over the handler registration, ensuring it happens in the correct sequence and process context.

    ```elixir
    # In your test:
    # Ensure EventManager is initialized for the test process
    UXRefinement.enable_feature(:events) # Or whatever initializes your EventManager

    # Manually register the mock's handler
    EventManager.register_handler(
      :keyboard_event,
      Raxol.Mocks.KeyboardShortcutsMock, # Your mock module
      :handle_keyboard_event            # The function to be called
    )

    # Stub the mock's init to prevent it from trying to register again or doing other work
    Mox.stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

    # Enable the feature that uses the mock; its init (now stubbed) will be called
    UXRefinement.enable_feature(:keyboard_shortcuts)

    # Set up your expectation for the handler
    Mox.expect(Raxol.Mocks.KeyboardShortcutsMock, :handle_keyboard_event, fn event_payload ->
      # ... assertions and actions ...
      send(self(), :mock_handler_called)
      :ok
    end)

    # Dispatch the event
    EventManager.dispatch({:keyboard_event, %Event{...}})

    assert_received :mock_handler_called
    Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    ```
