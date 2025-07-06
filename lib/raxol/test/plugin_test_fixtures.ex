defmodule Raxol.Test.PluginTestFixtures do
  @moduledoc """
  Test fixtures for plugin-related tests.

  Each plugin in this module is designed to be isolated and self-contained,
  with clear state management and error handling. Plugins are designed to be
  used in parallel test runs without interference.
  """

  defmodule TestPlugin do
    @moduledoc """
    Test plugin that implements the Plugin behaviour correctly
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "test_plugin",
         version: "1.0.0",
         description: "Test plugin for unit testing",
         enabled: true,
         config: opts,
         dependencies: [],
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: [{:test_cmd, :handle_test_cmd, 1}]

    def handle_test_cmd(_arg, _state) do
      # Update state with a timestamp to track when it was handled
      {:ok, %{handled: true, handled_at: System.monotonic_time()}, :test_ok}
    end

    # Renamed from metadata/0 to get_metadata/0
    def get_metadata do
      %{
        id: :test_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end

    # Alias for backward compatibility
    def metadata, do: get_metadata()

    # Added Behaviour Callbacks
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  @moduledoc """
  Broken plugin that fails to implement required functions
  """
  defmodule BrokenPlugin do
    @moduledoc """
    Broken plugin that fails to implement required functions
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "broken_plugin",
         version: "1.0.0",
         description: "Plugin that breaks during command execution",
         enabled: true,
         config: %{},
         dependencies: [],
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: [{:broken_cmd, :handle_broken_cmd, 1}]

    # Missing implementation of handle_broken_cmd/2

    # Renamed from metadata/0 to get_metadata/0
    def get_metadata do
      %{
        id: :broken_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end

    # Added Behaviour Callbacks
    # Or error for testing
    def handle_input(_input, state), do: {:ok, state}
    # Or error for testing
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  @moduledoc """
  Plugin with bad return values
  """
  defmodule BadReturnPlugin do
    @moduledoc """
    Plugin with bad return values
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      state_id = System.unique_integer([:positive])

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "bad_return_plugin",
         version: "1.0.0",
         description: "Plugin that returns invalid values",
         enabled: true,
         config: %{},
         dependencies: [],
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

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

    def handle_test_cmd(_arg, _state) do
      {:error, :bad_return}
    end

    # Renamed from metadata/0 to get_metadata/0
    def get_metadata do
      %{
        id: :bad_return_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end

    # Added Behaviour Callbacks
    # Already had handle_input/output
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  defmodule DependentPlugin do
    @moduledoc """
    Plugin with invalid dependencies
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      state_id = System.unique_integer([:positive])

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "dependent_plugin",
         version: "1.0.0",
         description: "Plugin that depends on TestPlugin",
         enabled: true,
         config: %{},
         dependencies: dependencies(),
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: []

    def id, do: :dependent_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"test_plugin", ">= 1.0.0"}]

    def get_metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end

    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  defmodule TimeoutPlugin do
    @moduledoc """
    Plugin that times out during initialization
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Simulate a timeout error immediately without actually timing out
      {:error, :timeout_simulated}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: []

    # Renamed from metadata/0 to get_metadata/0
    def get_metadata do
      %{
        id: :timeout_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end

    # Added Behaviour Callbacks
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  # Plugin that crashes during initialization
  defmodule CrashPlugin do
    @moduledoc """
    Plugin that crashes during initialization
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      state_id = System.unique_integer([:positive])

      raise "Plugin initialization failed: Intentional crash for testing error handling (State ID: #{state_id})"
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

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

    # Renamed from metadata/0 to get_metadata/0
    def get_metadata do
      %{
        id: :crash_plugin,
        version: "1.0.0",
        dependencies: []
      }
    end

    # Added Behaviour Callbacks
    # handle_input and handle_output are effectively implemented by handle_input_crash / handle_output_crash
    # for the specific commands. Adding general ones for completeness.
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(:trigger_input_crash, arg, state),
      do: handle_input_crash(arg, state)

    def handle_command(:trigger_output_crash, arg, state),
      do: handle_output_crash(arg, state)

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  defmodule InvalidMetadataPlugin do
    @moduledoc """
    Plugin that returns invalid metadata
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      state_id = System.unique_integer([:positive])

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "invalid_metadata_plugin",
         version: "1.0.0",
         description: "Plugin with invalid metadata for testing",
         enabled: true,
         config: %{},
         dependencies: [],
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

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

    def get_metadata do
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

    # Added Behaviour Callbacks
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  defmodule VersionMismatchPlugin do
    @moduledoc """
    Plugin with version mismatch dependency
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      {:ok,
       %{state_id: state_id, dependencies: dependencies(), module: __MODULE__}}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: []

    def id, do: :version_mismatch_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"test_plugin", ">= 2.0.0"}]

    def get_metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end

    # Added Behaviour Callbacks
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  defmodule CircularDependencyPlugin do
    @moduledoc """
    Plugin with circular dependency
    """
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts) do
      # Initialize with a unique state ID to track instances
      state_id = :rand.uniform(1_000_000)

      {:ok,
       %Raxol.Plugins.Plugin{
         name: "circular_dependency_plugin",
         version: "1.0.0",
         description: "Plugin with circular dependency for testing",
         enabled: true,
         config: %{},
         dependencies: dependencies(),
         api_version: "1.0.0",
         module: __MODULE__
       }}
    end

    def terminate(_reason, state) do
      # Clean up any resources if needed
      state
    end

    def cleanup(_config), do: :ok

    def get_commands, do: []

    def id, do: :circular_dependency_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{"circular_dependency_plugin", ">= 1.0.0"}]

    def get_metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end

    # Added Behaviour Callbacks
    def handle_input(_input, state), do: {:ok, state}
    def handle_output(_output, state), do: {:ok, state}
    def enable(state), do: {:ok, state}
    def disable(state), do: {:ok, state}
    def filter_event(_event, state), do: {:ok, state}

    def handle_command(_cmd, _args, state),
      do: {:error, :not_implemented, state}
  end

  @moduledoc """
  Helper function to create a unique plugin state
  """
  def create_unique_state do
    %{
      state_id: :rand.uniform(1_000_000),
      created_at: System.monotonic_time()
    }
  end
end
