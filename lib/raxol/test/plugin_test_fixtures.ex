defmodule Raxol.Test.PluginTestFixtures do
  @moduledoc """
  Test fixtures for plugin-related tests.

  Each plugin in this module is designed to be isolated and self-contained,
  with clear state management and error handling. Plugins are designed to be
  used in parallel test runs without interference.
  """

  # Test plugin that implements the Plugin behaviour correctly
  defmodule TestPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, handled: false}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: [{:test_cmd, :handle_test_cmd, 1}]

    def handle_test_cmd(_arg, state) do
      # Update state with a timestamp to track when it was handled
      {:ok, %{state | handled: true, handled_at: System.monotonic_time()},
       :test_ok}
    end

    # Add metadata/0 function
    def metadata do
      %{
        id: :test_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  # Broken plugin that fails to implement required functions
  defmodule BrokenPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, error_type: :missing_implementation}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: [{:broken_cmd, :handle_broken_cmd, 1}]

    # Missing implementation of handle_broken_cmd/2

    def disable(state), do: {:ok, state}

    # Add metadata/0 function
    def metadata do
      %{
        id: :broken_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  # Plugin with bad return values
  defmodule BadReturnPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, error_type: :bad_return}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: [{:bad_return_cmd, :handle_bad_return_cmd, 1}]

    def handle_bad_return_cmd(_arg, _state) do
      # Return wrong format
      :unexpected_return
    end

    def handle_input(_input, _state) do
      # Wrong return format
      :not_ok
    end

    def handle_output(_output, _state) do
      # Wrong return format
      [:not, :a, :tuple]
    end

    def handle_test_cmd(_arg, state) do
      # Return wrong format
      :unexpected_return
    end

    def disable(state), do: {:ok, state}

    # Add metadata/0 function
    def metadata do
      %{
        id: :bad_return_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  # Plugin with invalid dependencies
  defmodule DependentPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, dependencies: dependencies()}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: []

    def id, do: :dependent_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"test_plugin", ">= 1.0.0"}]

    def metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end

    def disable(state), do: {:ok, state}
  end

  # Plugin that times out during initialization
  defmodule TimeoutPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      # Use a timer to simulate a timeout instead of sleeping forever
      Process.send_after(self(), :timeout_simulated, 100)

      receive do
        :timeout_simulated -> {:error, :timeout_simulated}
      end
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: []

    # Add metadata/0 function
    def metadata do
      %{
        id: :timeout_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  # Plugin that crashes during initialization
  defmodule CrashPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      # Raise a more descriptive error with the state ID for better debugging
      raise "Plugin initialization failed: Intentional crash for testing error handling (State ID: #{state_id})"
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands,
      do: [
        {:trigger_input_crash, :handle_input_crash, 1},
        {:trigger_output_crash, :handle_output_crash, 1}
      ]

    def handle_input_crash(_arg, _state) do
      raise "Intentional crash in input handler"
    end

    def handle_output_crash(_arg, _state) do
      raise "Intentional crash in output handler"
    end

    # Add metadata/0 function
    def metadata do
      %{
        id: :crash_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end
  end

  # Plugin that returns invalid metadata
  defmodule InvalidMetadataPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, metadata_errors: metadata_errors()}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: []

    def id, do: :invalid_metadata_plugin
    def version, do: "1.0.0"

    def dependencies,
      do: [
        {"invalid_dependency", "invalid_version"},
        {"missing_required_field", "invalid_version"},
        {"invalid_type", "invalid_version"}
      ]

    defp metadata_errors do
      [
        :invalid_id,
        :invalid_version,
        :invalid_dependencies
      ]
    end

    def metadata do
      # Return invalid metadata structure to test error handling
      %{
        # Invalid ID
        id: nil,
        # Invalid version format
        version: "not_a_semver",
        dependencies: [
          # Invalid: wrong format
          {"invalid_dependency", "invalid_version"},
          # Invalid: missing required field (now with version)
          {"missing_required_field", "invalid_version"},
          # Invalid: wrong type (now with version)
          {"invalid_type", "invalid_version"}
        ],
        # Missing required fields
        name: nil,
        description: nil,
        author: nil
      }
    end
  end

  # Plugin with version mismatch dependency
  defmodule VersionMismatchPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, dependencies: dependencies()}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: []

    def id, do: :version_mismatch_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"test_plugin", ">= 1.0.0"}]

    def metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end
  end

  # Plugin with circular dependency
  defmodule CircularDependencyPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)
      {:ok, %{state_id: state_id, dependencies: dependencies()}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def get_commands, do: []

    def id, do: :circular_dependency_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"circular_dependency", ">= 1.0.0"}]

    def metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end
  end

  # Helper function to create a unique plugin state
  def create_unique_state do
    %{
      state_id: :rand.uniform(1_000_000),
      created_at: System.monotonic_time()
    }
  end
end
