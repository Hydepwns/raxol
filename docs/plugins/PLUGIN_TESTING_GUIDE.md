# Plugin Testing Guide

**Version**: v1.6.0
**Last Updated**: 2025-09-26
**Target**: Plugin developers

## Overview

This guide covers comprehensive testing strategies for Raxol plugins, including unit testing, integration testing, and testing patterns specific to the plugin system architecture.

## Testing Environment Setup

### Required Dependencies

```elixir
# In your plugin's mix.exs
defp deps do
  [
    {:raxol, "~> 1.5", only: [:dev, :test]},
    {:ex_unit, "~> 1.15", only: :test},
    {:mox, "~> 1.0", only: :test}  # For mocking
  ]
end
```

### Test Configuration

```elixir
# config/test.exs
import Config

config :logger, level: :warning

config :raxol, :test_mode, true

# Plugin-specific test config
config :my_plugin,
  test_data_path: "test/fixtures",
  mock_external_services: true
```

## Unit Testing Patterns

### Basic Plugin Structure Tests

```elixir
defmodule MyPluginTest do
  use ExUnit.Case, async: true

  alias MyPlugin

  describe "plugin manifest" do
    test "returns valid manifest structure" do
      manifest = MyPlugin.manifest()

      # Required fields
      assert is_binary(manifest.name)
      assert is_binary(manifest.version)
      assert is_binary(manifest.description)
      assert is_binary(manifest.author)

      # Dependencies structure
      assert is_map(manifest.dependencies)
      assert Map.has_key?(manifest.dependencies, "raxol-core")

      # Capabilities list
      assert is_list(manifest.capabilities)
      assert Enum.all?(manifest.capabilities, &is_atom/1)

      # Trust level validation
      assert manifest.trust_level in [:trusted, :sandboxed, :untrusted]

      # Config schema validation
      assert is_map(manifest.config_schema)
    end

    test "version follows semantic versioning" do
      manifest = MyPlugin.manifest()
      version = manifest.version

      # Test semantic version format (major.minor.patch)
      assert Regex.match?(~r/^\d+\.\d+\.\d+(-[\w\d\.-]+)?$/, version)
    end

    test "capabilities are valid" do
      manifest = MyPlugin.manifest()

      valid_capabilities = [
        :ui_overlay, :keyboard_input, :command_execution,
        :file_system_access, :network_access, :status_line,
        :theme_provider, :file_watcher, :command_handler
      ]

      invalid_capabilities =
        manifest.capabilities
        |> Enum.reject(&(&1 in valid_capabilities))

      assert invalid_capabilities == [],
        "Invalid capabilities found: #{inspect(invalid_capabilities)}"
    end
  end

  describe "plugin lifecycle" do
    test "initializes with valid config" do
      config = %{
        enabled: true,
        debug: false,
        custom_setting: "value"
      }

      assert {:ok, state} = MyPlugin.init(config)

      # State structure validation
      assert state.config == config
      assert is_boolean(state.enabled)
    end

    test "handles enable/disable transitions" do
      config = %{enabled: true}
      {:ok, initial_state} = MyPlugin.init(config)

      # Test enable
      assert {:ok, enabled_state} = MyPlugin.enable(initial_state)
      assert enabled_state.enabled == true

      # Verify resources are initialized
      assert enabled_state.timers != []
      assert enabled_state.subscriptions != []

      # Test disable
      assert {:ok, disabled_state} = MyPlugin.disable(enabled_state)
      assert disabled_state.enabled == false

      # Verify resources are cleaned up
      assert disabled_state.timers == []
      assert disabled_state.subscriptions == []
    end

    test "terminates cleanly" do
      config = %{enabled: true}
      {:ok, state} = MyPlugin.init(config)
      {:ok, enabled_state} = MyPlugin.enable(state)

      # Should not raise errors
      assert :ok = MyPlugin.terminate(:normal, enabled_state)
    end

    test "handles error conditions during lifecycle" do
      # Test with invalid config
      invalid_config = %{required_field: nil}

      case MyPlugin.init(invalid_config) do
        {:ok, _state} ->
          # Plugin should handle invalid config gracefully
          :ok
        {:error, reason} ->
          # Error should be descriptive
          assert is_binary(reason) or is_atom(reason)
      end
    end
  end
end
```

### Command Handling Tests

```elixir
defmodule MyPluginCommandTest do
  use ExUnit.Case, async: true

  alias MyPlugin

  setup do
    config = %{enabled: true, debug: false}
    {:ok, initial_state} = MyPlugin.init(config)
    {:ok, state} = MyPlugin.enable(initial_state)

    on_exit(fn ->
      MyPlugin.terminate(:normal, state)
    end)

    {:ok, state: state}
  end

  describe "command declarations" do
    test "declares available commands" do
      commands = MyPlugin.get_commands()

      assert is_list(commands)

      # Validate command structure
      Enum.each(commands, fn {name, function, arity} ->
        assert is_atom(name)
        assert is_atom(function)
        assert is_integer(arity)
        assert arity >= 2  # Minimum: command, args, state

        # Verify function exists
        assert function_exported?(MyPlugin, function, arity)
      end)
    end

    test "command names are unique" do
      commands = MyPlugin.get_commands()
      command_names = Enum.map(commands, fn {name, _, _} -> name end)

      assert length(command_names) == length(Enum.uniq(command_names)),
        "Duplicate command names found"
    end
  end

  describe "command execution" do
    test "handles valid commands", %{state: state} do
      # Test each declared command
      commands = MyPlugin.get_commands()

      Enum.each(commands, fn {name, _, _} ->
        case MyPlugin.handle_command(name, [], state) do
          {:ok, new_state, result} ->
            # State should be valid after command
            assert is_map(new_state)
            # Result can be any term
            assert result != nil

          {:error, reason, error_state} ->
            # Error should be descriptive
            assert is_binary(reason) or is_atom(reason)
            # State should still be valid
            assert is_map(error_state)
        end
      end)
    end

    test "handles invalid commands", %{state: state} do
      invalid_commands = [:nonexistent, :invalid_cmd, :unknown]

      Enum.each(invalid_commands, fn cmd ->
        result = MyPlugin.handle_command(cmd, [], state)

        # Should return error for unknown commands
        assert match?({:error, _, _}, result)
      end)
    end

    test "handles command with arguments", %{state: state} do
      # Test commands that accept arguments
      test_cases = [
        {:search, ["query", "term"]},
        {:set_config, [%{setting: "value"}]},
        {:execute, ["action", %{param: 1}]}
      ]

      Enum.each(test_cases, fn {command, args} ->
        case MyPlugin.handle_command(command, args, state) do
          {:ok, _new_state, _result} ->
            :ok  # Command handled successfully

          {:error, _reason, _state} ->
            # Command might not be implemented - that's OK for testing
            :ok
        end
      end)
    end
  end

  describe "command state management" do
    test "commands preserve state integrity", %{state: initial_state} do
      # Execute a series of commands
      commands_sequence = [
        {:init_data, []},
        {:add_item, ["test_item"]},
        {:get_status, []},
        {:clear_data, []}
      ]

      final_state =
        Enum.reduce(commands_sequence, initial_state, fn {cmd, args}, state ->
          case MyPlugin.handle_command(cmd, args, state) do
            {:ok, new_state, _result} -> new_state
            {:error, _reason, error_state} -> error_state
          end
        end)

      # Final state should still be valid
      assert is_map(final_state)
      assert Map.has_key?(final_state, :config)
    end

    test "commands handle concurrent access", %{state: state} do
      # Simulate concurrent command execution
      tasks =
        1..10
        |> Enum.map(fn i ->
          Task.async(fn ->
            MyPlugin.handle_command(:get_status, [i], state)
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All commands should complete successfully
      Enum.each(results, fn result ->
        assert match?({:ok, _state, _result}, result) or
               match?({:error, _reason, _state}, result)
      end)
    end
  end
end
```

### Event Filtering Tests

```elixir
defmodule MyPluginEventTest do
  use ExUnit.Case, async: true

  alias MyPlugin

  setup do
    config = %{enabled: true}
    {:ok, state} = MyPlugin.init(config)
    {:ok, state: state}
  end

  describe "event filtering" do
    test "passes through unhandled events", %{state: state} do
      unhandled_events = [
        {:key_press, "a"},
        {:mouse_click, {10, 20}},
        {:terminal_resize, {80, 24}},
        {:custom_event, "data"}
      ]

      Enum.each(unhandled_events, fn event ->
        result = MyPlugin.filter_event(event, state)

        # Should pass through unchanged
        assert {:ok, ^event} = result
      end)
    end

    test "handles plugin-specific events", %{state: state} do
      # Test events your plugin specifically handles
      plugin_events = [
        {:key_press, "ctrl+p"},  # Command palette hotkey
        {:key_press, "escape"},  # Close UI
        {:file_change, "/path/to/file"}  # File watcher
      ]

      Enum.each(plugin_events, fn event ->
        result = MyPlugin.filter_event(event, state)

        case result do
          {:ok, modified_event} ->
            # Event was modified
            assert modified_event != event

          :halt ->
            # Event was consumed
            :ok

          {:error, reason} ->
            # Event caused error
            assert is_binary(reason)
        end
      end)
    end

    test "can halt event propagation", %{state: state} do
      # Events that should be consumed by the plugin
      halt_events = [
        {:key_press, "F12"},  # Plugin-specific hotkey
        {:plugin_internal_event, "data"}
      ]

      Enum.each(halt_events, fn event ->
        case MyPlugin.filter_event(event, state) do
          :halt ->
            # Event was properly consumed
            :ok

          {:ok, _modified_event} ->
            # Event was modified but not consumed - also valid
            :ok

          other ->
            flunk("Unexpected result for halt event: #{inspect(other)}")
        end
      end)
    end

    test "maintains state consistency during event filtering", %{state: state} do
      events = [
        {:key_press, "j"},
        {:key_press, "k"},
        {:key_press, "enter"},
        {:key_press, "escape"}
      ]

      # Process events sequentially
      final_state =
        Enum.reduce(events, state, fn event, current_state ->
          case MyPlugin.filter_event(event, current_state) do
            {:ok, _event} -> current_state  # State unchanged in basic filtering
            :halt -> current_state
            {:error, _reason} -> current_state
          end
        end)

      # State should remain consistent
      assert final_state == state
    end
  end

  describe "event performance" do
    test "event filtering is performant", %{state: state} do
      event = {:key_press, "a"}

      # Time event filtering
      {time_microseconds, _result} =
        :timer.tc(fn ->
          # Process many events
          Enum.each(1..1000, fn _ ->
            MyPlugin.filter_event(event, state)
          end)
        end)

      # Should complete in reasonable time (< 10ms for 1000 events)
      assert time_microseconds < 10_000,
        "Event filtering too slow: #{time_microseconds} microseconds"
    end

    test "handles high-frequency events", %{state: state} do
      high_freq_events = [
        {:mouse_move, {1, 1}},
        {:mouse_move, {2, 2}},
        {:mouse_move, {3, 3}},
        {:scroll, :up},
        {:scroll, :down}
      ]

      # Should handle rapid events without issues
      Enum.each(high_freq_events, fn event ->
        assert {:ok, _} = MyPlugin.filter_event(event, state)
      end)
    end
  end
end
```

## Integration Testing

### Plugin System Integration

```elixir
defmodule MyPluginIntegrationTest do
  use ExUnit.Case

  alias Raxol.Plugins.PluginSystemV2

  @moduletag :integration

  setup do
    # Start plugin system for testing
    {:ok, _pid} = PluginSystemV2.start_link(test_mode: true)

    on_exit(fn ->
      # Clean up any loaded plugins
      try do
        PluginSystemV2.stop()
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  describe "plugin loading" do
    test "plugin can be loaded into system" do
      plugin_manifest = MyPlugin.manifest()

      # Test plugin loading
      result = PluginSystemV2.load_plugin("my-plugin", %{
        manifest: plugin_manifest,
        module: MyPlugin
      })

      assert :ok = result

      # Verify plugin status
      {:ok, status} = PluginSystemV2.get_plugin_status("my-plugin")
      assert status.status in [:loaded, :running]
    end

    test "plugin dependencies are resolved" do
      # Test that dependencies are properly checked
      manifest = MyPlugin.manifest()

      case PluginSystemV2.resolve_dependencies(manifest) do
        {:ok, resolved} ->
          # Dependencies should include raxol-core
          assert "raxol-core" in Map.keys(resolved)

        {:error, conflicts} ->
          # If there are conflicts, they should be descriptive
          assert is_list(conflicts)
          Enum.each(conflicts, fn conflict ->
            assert is_map(conflict)
            assert Map.has_key?(conflict, :plugin)
            assert Map.has_key?(conflict, :requirement)
          end)
      end
    end

    test "plugin hot reload works" do
      # Load initial plugin
      assert :ok = PluginSystemV2.load_plugin("my-plugin")

      # Get initial state
      {:ok, initial_status} = PluginSystemV2.get_plugin_status("my-plugin")

      # Perform hot reload
      assert :ok = PluginSystemV2.hot_reload_plugin("my-plugin")

      # Verify plugin is still functional
      {:ok, reloaded_status} = PluginSystemV2.get_plugin_status("my-plugin")
      assert reloaded_status.status == :running

      # Version or timestamp should be updated
      assert reloaded_status.last_reload != initial_status.last_reload
    end
  end

  describe "command integration" do
    setup do
      # Load plugin for command tests
      PluginSystemV2.load_plugin("my-plugin")
      :ok
    end

    test "plugin commands are registered" do
      # Commands should be accessible through the system
      commands = MyPlugin.get_commands()

      Enum.each(commands, fn {name, _, _} ->
        # Command should be callable through system
        command_name = "my-plugin:#{name}"

        # This would depend on your command execution system
        case Raxol.Commands.execute(command_name) do
          {:ok, _result} -> :ok
          {:error, :not_found} -> flunk("Command not registered: #{command_name}")
          {:error, _other} -> :ok  # Command exists but may have failed
        end
      end)
    end
  end

  describe "performance monitoring" do
    setup do
      PluginSystemV2.load_plugin("my-plugin")
      :ok
    end

    test "plugin performance is monitored" do
      # Get performance metrics
      {:ok, status} = PluginSystemV2.get_plugin_status("my-plugin")

      # Should have performance metrics
      assert is_map(status.performance_metrics)

      expected_metrics = [
        :memory_usage_mb,
        :cpu_usage_percent,
        :event_processing_time_ms,
        :command_execution_count
      ]

      Enum.each(expected_metrics, fn metric ->
        assert Map.has_key?(status.performance_metrics, metric),
          "Missing performance metric: #{metric}"
      end)
    end

    test "plugin resource limits are enforced" do
      # This would test sandbox limits if applicable
      manifest = MyPlugin.manifest()

      if manifest.trust_level != :trusted do
        # Check that resource limits are enforced
        {:ok, status} = PluginSystemV2.get_plugin_status("my-plugin")

        # Memory usage should be reasonable
        memory_mb = status.performance_metrics.memory_usage_mb
        assert memory_mb < 100, "Plugin using too much memory: #{memory_mb}MB"

        # CPU usage should be reasonable
        cpu_percent = status.performance_metrics.cpu_usage_percent
        assert cpu_percent < 50, "Plugin using too much CPU: #{cpu_percent}%"
      end
    end
  end
end
```

### Terminal Integration Tests

```elixir
defmodule MyPluginTerminalTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @moduletag :terminal_integration

  describe "terminal interaction" do
    test "plugin responds to terminal events" do
      # This would require a test terminal emulator
      # For now, test the event handling directly

      config = %{enabled: true}
      {:ok, state} = MyPlugin.init(config)

      # Simulate terminal events
      terminal_events = [
        {:terminal_resize, {80, 24}},
        {:terminal_focus, true},
        {:terminal_focus, false}
      ]

      # Plugin should handle terminal events without crashing
      Enum.each(terminal_events, fn event ->
        case MyPlugin.filter_event(event, state) do
          {:ok, _modified_event} -> :ok
          :halt -> :ok
          {:error, reason} ->
            flunk("Plugin failed to handle terminal event #{inspect(event)}: #{reason}")
        end
      end)
    end

    test "plugin UI renders correctly" do
      # Test UI rendering if plugin has UI capabilities
      manifest = MyPlugin.manifest()

      if :ui_overlay in manifest.capabilities do
        config = %{enabled: true}
        {:ok, state} = MyPlugin.init(config)

        # Test rendering
        case MyPlugin.render_overlay(state, 80, 24) do
          {:ok, lines} ->
            # Should return list of rendered lines
            assert is_list(lines)
            assert length(lines) <= 24

            # Each line should be properly formatted
            Enum.each(lines, fn line ->
              assert is_map(line)
              assert Map.has_key?(line, :text)
              assert is_binary(line.text)
            end)

          {:error, reason} ->
            flunk("UI rendering failed: #{reason}")

          :not_implemented ->
            # Plugin doesn't implement UI rendering - OK
            :ok
        end
      end
    end
  end
end
```

## Test Utilities and Helpers

### Plugin Test Helper Module

```elixir
defmodule Raxol.PluginTestHelpers do
  @moduledoc """
  Helper functions for testing Raxol plugins.
  """

  def load_test_plugin(plugin_module, config \\ %{}) do
    {:ok, state} = plugin_module.init(config)
    {:ok, enabled_state} = plugin_module.enable(state)
    enabled_state
  end

  def unload_test_plugin(plugin_module, state) do
    {:ok, disabled_state} = plugin_module.disable(state)
    :ok = plugin_module.terminate(:normal, disabled_state)
  end

  def simulate_event(event, state, plugin_module) do
    case plugin_module.filter_event(event, state) do
      {:ok, _modified_event} -> state
      :halt -> state
      {:error, _reason} -> state
    end
  end

  def execute_command(command, args, state, plugin_module) do
    plugin_module.handle_command(command, args, state)
  end

  def assert_plugin_state(state, expected_status) do
    case expected_status do
      :running ->
        assert state.enabled == true
      :stopped ->
        assert state.enabled == false
      :initialized ->
        assert is_map(state)
        assert Map.has_key?(state, :config)
    end
  end

  def capture_plugin_output(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end

  def with_test_plugin(plugin_module, config \\ %{}, test_fun) do
    state = load_test_plugin(plugin_module, config)

    try do
      test_fun.(state)
    after
      unload_test_plugin(plugin_module, state)
    end
  end

  def assert_valid_manifest(manifest) do
    required_fields = [:name, :version, :description, :author]

    Enum.each(required_fields, fn field ->
      assert Map.has_key?(manifest, field),
        "Missing required field: #{field}"
      assert is_binary(Map.get(manifest, field)),
        "Field #{field} should be a string"
    end)

    # Validate optional fields
    if Map.has_key?(manifest, :capabilities) do
      assert is_list(manifest.capabilities)
      Enum.each(manifest.capabilities, fn cap ->
        assert is_atom(cap), "Capabilities should be atoms"
      end)
    end

    if Map.has_key?(manifest, :dependencies) do
      assert is_map(manifest.dependencies)
    end
  end
end
```

### Mock and Fixture Support

```elixir
defmodule Raxol.PluginTestMocks do
  @moduledoc """
  Mock implementations for testing plugins.
  """

  use Mox

  # Mock external dependencies
  defmock(MockHTTPoison, for: HTTPoisonBehaviour)
  defmock(MockFileSystem, for: FileSystemBehaviour)

  def mock_file_system do
    MockFileSystem
    |> expect(:ls, fn _path ->
      {:ok, ["file1.ex", "file2.ex", "dir1"]}
    end)
    |> expect(:stat, fn path ->
      {:ok, %{
        size: 1024,
        type: :regular,
        access: :read_write,
        atime: ~N[2025-09-26 12:00:00],
        mtime: ~N[2025-09-26 12:00:00],
        ctime: ~N[2025-09-26 12:00:00]
      }}
    end)
  end

  def mock_http_client do
    MockHTTPoison
    |> expect(:get, fn url ->
      case url do
        "http://api.example.com/data" ->
          {:ok, %{status_code: 200, body: "{\"data\": \"test\"}"}}
        _ ->
          {:ok, %{status_code: 404, body: "Not found"}}
      end
    end)
  end
end
```

### Property-Based Testing

```elixir
defmodule MyPluginPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias MyPlugin

  describe "property-based tests" do
    property "plugin handles arbitrary configuration" do
      check all config <- config_generator() do
        case MyPlugin.init(config) do
          {:ok, state} ->
            # Should always produce valid state
            assert is_map(state)
            assert Map.has_key?(state, :config)

          {:error, reason} ->
            # Error should be descriptive
            assert is_binary(reason) or is_atom(reason)
        end
      end
    end

    property "event filtering preserves event structure" do
      check all event <- event_generator() do
        config = %{enabled: true}
        {:ok, state} = MyPlugin.init(config)

        case MyPlugin.filter_event(event, state) do
          {:ok, filtered_event} ->
            # Filtered event should have similar structure
            assert is_tuple(filtered_event)

          :halt ->
            # Event was consumed - OK
            :ok

          {:error, _reason} ->
            # Error handling - OK
            :ok
        end
      end
    end

    property "commands with random args don't crash plugin" do
      check all {command, args} <- command_generator() do
        config = %{enabled: true}
        {:ok, state} = MyPlugin.init(config)

        # Should not raise exceptions
        case MyPlugin.handle_command(command, args, state) do
          {:ok, new_state, _result} ->
            assert is_map(new_state)

          {:error, _reason, error_state} ->
            assert is_map(error_state)
        end
      end
    end
  end

  # Generators
  defp config_generator do
    gen all enabled <- boolean(),
            debug <- boolean(),
            timeout <- integer(1..10000),
            name <- string(:ascii, min_length: 1, max_length: 50) do
      %{
        enabled: enabled,
        debug: debug,
        timeout: timeout,
        name: name
      }
    end
  end

  defp event_generator do
    one_of([
      {:key_press, string(:ascii, length: 1)},
      {:mouse_click, {integer(0..100), integer(0..50)}},
      {:terminal_resize, {integer(20..200), integer(10..100)}},
      {:file_change, string(:ascii, min_length: 1, max_length: 100)}
    ])
  end

  defp command_generator do
    gen all command <- atom(:alphanumeric),
            args <- list_of(term(), max_length: 5) do
      {command, args}
    end
  end
end
```

## Test Organization and Best Practices

### Test File Structure

```
test/
├── my_plugin_test.exs                 # Basic unit tests
├── my_plugin_command_test.exs         # Command handling tests
├── my_plugin_event_test.exs          # Event filtering tests
├── my_plugin_integration_test.exs     # Integration tests
├── my_plugin_property_test.exs        # Property-based tests
├── support/
│   ├── plugin_test_helpers.exs       # Test helpers
│   ├── mocks.exs                     # Mock definitions
│   └── fixtures/                     # Test fixtures
│       ├── sample_config.json
│       ├── test_data.txt
│       └── mock_responses/
└── performance/
    └── my_plugin_performance_test.exs # Performance tests
```

### Test Documentation

```elixir
defmodule MyPluginTest do
  @moduledoc """
  Comprehensive test suite for MyPlugin.

  This test suite covers:
  - Plugin lifecycle management
  - Command handling and validation
  - Event filtering and modification
  - Configuration validation
  - Error handling and recovery
  - Performance characteristics

  Test Categories:
  - Unit tests: Test individual functions and components
  - Integration tests: Test plugin interaction with Raxol system
  - Property tests: Test plugin behavior with random inputs
  - Performance tests: Verify performance requirements
  """

  use ExUnit.Case, async: true

  # Test setup and helpers...
end
```

### Continuous Integration

```yaml
# .github/workflows/plugin_tests.yml
name: Plugin Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.15'
        otp-version: '26'

    - name: Install dependencies
      run: mix deps.get

    - name: Run plugin tests
      run: |
        TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true mix test test/plugins/

    - name: Run integration tests
      run: |
        TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true mix test --only integration

    - name: Check test coverage
      run: mix test --cover
```

This comprehensive testing guide ensures that plugins are thoroughly tested at all levels, from individual functions to full system integration, providing confidence in plugin reliability and performance.