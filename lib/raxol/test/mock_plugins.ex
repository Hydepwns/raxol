defmodule Raxol.Test.MockPlugins do
  @moduledoc """
  Mock plugins for testing plugin system functionality.

  Provides various mock plugin implementations for testing
  dependency handling, versioning, crashes, and lifecycle events.
  """
  # --- Mock Plugins for Testing Dependencies and Versions ---
  defmodule MockDependencyPlugin do
    @moduledoc "Mock plugin that provides dependencies for testing."
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      {:ok,
       %{
         name: "mock_dependency_plugin",
         version: "1.0.1",
         dependencies: [],
         raxol_compatibility: "~>1.0"
       }}
    end

    def terminate(_reason, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}
  end

  defmodule MockDependentPlugin do
    @moduledoc "Mock plugin with dependencies for testing dependency resolution."
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      {:ok,
       %{
         name: "mock_dependent_plugin",
         version: "1.0.1",
         dependencies: [
           %{"name" => "mock_dependency_plugin", "version" => ">=1.0.0"}
         ],
         raxol_compatibility: "~>1.0"
       }}
    end

    def terminate(_reason, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}
  end

  defmodule MockIncompatibleVersionPlugin do
    @moduledoc "Mock plugin with incompatible version for testing version conflicts."
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      {:ok,
       %{
         name: "mock_incompatible_plugin",
         version: "1.0.1",
         # Incompatible with Manager API version "1.0"
         raxol_compatibility: "~>2.0.0"
       }}
    end

    def terminate(_reason, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}
  end

  # --- End Mock Plugins ---

  # --- Mock Plugin for Event Testing ---
  defmodule MockEventConsumingPlugin do
    @moduledoc "Mock plugin for testing event consumption and handling."
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

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

      final_state =
        if Map.has_key?(config_or_state, :handled_events) do
          Map.merge(initial_plugin_state_map, config_or_state)
        else
          initial_plugin_state_map
        end

      {:ok, final_state}
    end

    def terminate(_reason, state), do: {:ok, state}

    def handle_input(input_data, state) do
      updated_events = [{:input, input_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    def handle_mouse_event(state, event_data) do
      updated_events = [{:mouse, event_data} | state.handled_events]
      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    def handle_terminal_event(state, event_type, event_data) do
      updated_events = [
        {:terminal, event_type, event_data} | state.handled_events
      ]

      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    def handle_custom_event(state, event_type, event_data) do
      updated_events = [
        {:custom, event_type, event_data} | state.handled_events
      ]

      new_plugin_state_map = %{state | handled_events: updated_events}
      {:ok, new_plugin_state_map}
    end

    def handle_output(_output, state), do: {:ok, state}
    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}
  end

  # --- End Mock Plugin for Event Testing ---

  # --- Mock Plugin for Command Testing ---
  defmodule MockCommandPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      initial_state = %{
        name: "mock_command_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: []
      }

      {:ok, initial_state}
    end

    def terminate(_reason, state), do: {:ok, state}
    def get_commands, do: []
    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def handle_mouse_event(state, _event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}
  end

  # --- End Mock Plugin for Command Testing ---

  # --- Mock Plugin for Crash Testing ---
  defmodule MockCrashyPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      initial_state = %{
        name: "mock_crashy_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: [],
        crash_on_command: true
      }

      {:ok, initial_state}
    end

    def terminate(_reason, state), do: {:ok, state}

    def get_commands do
      [
        %{
          name: :induce_crash,
          description: "Raises an error to simulate a plugin crash."
        },
        %{
          name: :toggle_crash_on_command,
          description: "Toggles whether induce_crash actually crashes."
        }
      ]
    end

    def handle_command(command_name, _params, state) do
      case command_name do
        :induce_crash ->
          if state.crash_on_command do
            raise "Simulated plugin crash!"
          else
            {:ok, state, %{status: "crash averted"}}
          end

        :toggle_crash_on_command ->
          new_crash_setting = !state.crash_on_command
          new_state = %{state | crash_on_command: new_crash_setting}
          {:ok, new_state, %{crash_on_command: new_crash_setting}}

        _ ->
          {:error, :unknown_command, state}
      end
    end

    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_mouse_event(state, _event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end

  # --- End Mock Plugin for Crash Testing ---

  # --- Mock Plugin for Init Crash Testing ---
  defmodule MockOnInitCrashPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      raise "Simulated plugin crash during init!"
    end

    def terminate(_reason, state), do: {:ok, state}
    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_mouse_event(state, _event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end

  # --- End Mock Plugin for Init Crash Testing ---

  # --- Mock Plugin for Terminate Crash Testing ---
  defmodule MockOnTerminateCrashPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_config) do
      initial_state = %{
        name: "mock_on_terminate_crash_plugin",
        version: "1.0.0",
        raxol_compatibility: "~>1.0",
        dependencies: []
      }

      {:ok, initial_state}
    end

    def terminate(_reason, _state) do
      raise "Simulated plugin crash during terminate!"
    end

    def get_commands, do: []

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}

    def handle_output(_output, state), do: {:ok, state}
    def handle_input(_input, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_mouse_event(state, _event_data), do: {:ok, state}
    def handle_terminal_event(state, _et, _ed), do: {:ok, state}
    def handle_custom_event(state, _et, _ed), do: {:ok, state}
  end

  # --- End Mock Plugin for Terminate Crash Testing ---
end
