defmodule Raxol.Test.MockPlugins do
  # --- Mock Plugins for Testing Dependencies and Versions ---
  defmodule MockDependencyPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config), do: {:ok, %{name: "mock_dependency_plugin", version: "1.0.0", dependencies: [], raxol_compatibility: "~>1.0"}}
    def terminate(_reason, _state), do: :ok
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input), do: {:ok, state, input}
  end

  defmodule MockDependentPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      {:ok, %{
        name: "mock_dependent_plugin",
        version: "1.0.0",
        dependencies: [%{"name" => "mock_dependency_plugin", "version" => ">=1.0.0"}],
        raxol_compatibility: "~>1.0"
      }}
    end
    def terminate(_reason, _state), do: :ok
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input), do: {:ok, state, input}
  end

  defmodule MockIncompatibleVersionPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      {:ok, %{
        name: "mock_incompatible_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>2.0.0" # Incompatible with Manager API version "1.0"
      }}
    end
    def terminate(_reason, _state), do: :ok
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input), do: {:ok, state, input}
  end
  # --- End Mock Plugins ---

  # --- Mock Plugin for Event Testing ---
  defmodule MockEventConsumingPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(config_or_state) do
      initial_plugin_state_map = %{
        # Standard metadata
        name: "mock_event_consumer",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: [],
        # Plugin internal state for tracking events
        handled_events: []
      }

      # If config_or_state contains :handled_events, assume it's an existing state.
      # Otherwise, it's a new initialization, and we use the default initial_plugin_state_map.
      # This allows the plugin to restore state if it's passed during a reload.
      final_state =
        if Map.has_key?(config_or_state, :handled_events) do
          # It's an existing state, merge it with defaults to ensure all keys are present,
          # but prioritize the existing state's values.
          Map.merge(initial_plugin_state_map, config_or_state)
        else
          # It's a config for a new plugin, or an empty map.
          # We might want to merge config if it contained other relevant init options,
          # but for this mock, we'll just use the default state.
          # If config_or_state is a map and not empty, one might log a warning
          # if it's expected to be used but isn't.
          initial_plugin_state_map
        end

      {:ok, final_state}
    end

    def terminate(_reason, state), do: {:ok, state}

    # Assuming Manager calls specific handlers like handle_input/2
    # The actual state passed here by Manager would be the map from init/1
    def handle_input(state, input_data) do
      updated_events = [{:input, input_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      # Plugins that process input might return the (possibly modified) input_data
      {:ok, new_plugin_state_map, input_data}
    end

    def handle_mouse_event(state, event_data) do
      updated_events = [{:mouse, event_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      # Mouse events might not modify the event data itself, just react
      {:ok, new_plugin_state_map}
    end

    def handle_terminal_event(state, event_type, event_data) do
      updated_events = [{:terminal, event_type, event_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    def handle_custom_event(state, event_type, event_data) do
      updated_events = [{:custom, event_type, event_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    # Other required callbacks for Raxol.Plugins.Behaviour
    def handle_output(state, output), do: {:ok, state, output} # Pass through output
    def get_commands(_state), do: [] # No commands
    def handle_command(state, _command_name, _params), do: {:error, :not_implemented, state}
  end
  # --- End Mock Plugin for Event Testing ---

  # --- Mock Plugin for Command Testing ---
  defmodule MockCommandPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      initial_state = %{
        name: "mock_command_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: []
        # No specific state needed for these tests if handlers are external
      }
      {:ok, initial_state}
    end

    def terminate(_reason, state), do: {:ok, state}
    def get_commands(_state), do: [] # Commands registered dynamically in tests
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input_data), do: {:ok, state, input_data}
    def handle_mouse_event(state, event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
    # No handle_command needed if all commands use externally provided handlers
  end
  # --- End Mock Plugin for Command Testing ---

  # --- Mock Plugin for Crash Testing ---
  defmodule MockCrashyPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      initial_state = %{
        name: "mock_crashy_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: [],
        crash_on_command: true # Default to crashing
      }
      {:ok, initial_state}
    end

    def terminate(_reason, state), do: {:ok, state}

    def get_commands(_state) do
      [
        %{name: :induce_crash, description: "Raises an error to simulate a plugin crash."},
        %{name: :toggle_crash_on_command, description: "Toggles whether induce_crash actually crashes."}
      ]
    end

    def handle_command(state, :induce_crash, _params) do
      if state.crash_on_command do
        raise "Simulated plugin crash!"
      else
        {:ok, state, %{status: "crash averted"}}
      end
    end

    def handle_command(state, :toggle_crash_on_command, _params) do
      new_crash_setting = !state.crash_on_command
      new_state = %{state | crash_on_command: new_crash_setting}
      {:ok, new_state, %{crash_on_command: new_crash_setting}}
    end

    def handle_command(state, _command_name, _params) do
      {:error, :unknown_command, state}
    end

    # Other required callbacks
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input_data), do: {:ok, state, input_data}
    def handle_mouse_event(state, event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end
  # --- End Mock Plugin for Crash Testing ---

  # --- Mock Plugin for Init Crash Testing ---
  defmodule MockOnInitCrashPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      raise "Simulated plugin crash during init!"
    end

    # Minimal implementations for other callbacks
    def terminate(_reason, state), do: {:ok, state}
    def get_commands(_state), do: []
    def handle_command(state, _command_name, _params), do: {:error, :not_implemented, state}
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input_data), do: {:ok, state, input_data}
    def handle_mouse_event(state, event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end
  # --- End Mock Plugin for Init Crash Testing ---

  # --- Mock Plugin for Terminate Crash Testing ---
  defmodule MockOnTerminateCrashPlugin do
    @behaviour Raxol.Plugins.Behaviour

    def init(_config) do
      # Basic init, should succeed
      {:ok, %{name: "mock_on_terminate_crash_plugin", version: "1.0.0"}}
    end

    def terminate(_reason, _state) do
      raise "Simulated plugin crash during terminate!"
    end

    # Minimal implementations for other callbacks
    def get_commands(_state), do: []
    def handle_command(state, _command_name, _params), do: {:error, :not_implemented, state}
    def handle_output(state, output), do: {:ok, state, output}
    def handle_input(state, input_data), do: {:ok, state, input_data}
    def handle_mouse_event(state, event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end
  # --- End Mock Plugin for Terminate Crash Testing ---
end
