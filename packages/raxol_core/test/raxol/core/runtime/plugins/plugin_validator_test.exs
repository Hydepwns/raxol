defmodule Raxol.Core.Runtime.Plugins.PluginValidatorTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.PluginValidator

  # Fixture modules

  defmodule ValidPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    # Required by PluginValidator's @required_callbacks [:init, :handle_event, :cleanup]
    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "valid_plugin",
        version: "1.0.0",
        author: "tester",
        description: "A valid plugin",
        api_version: "1.0"
      }
    end

    def dependencies, do: []

    def plugin_info do
      %{name: __MODULE__, version: "1.0.0"}
    end
  end

  defmodule MinimalPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def metadata do
      %{
        name: "minimal_plugin",
        version: "2.0",
        author: "tester",
        api_version: "2.0"
      }
    end

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def plugin_info do
      %{name: __MODULE__, version: "2.0"}
    end
  end

  defmodule NoDepsPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "no_deps_plugin",
        version: "1.0",
        author: "tester",
        api_version: "1.0"
      }
    end

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end

    # No dependencies/0 function
  end

  defmodule WithDepsPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "with_deps_plugin",
        version: "1.0",
        author: "tester",
        api_version: "1.0"
      }
    end

    def dependencies, do: ["dep_a", "dep_b"]

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end
  end

  defmodule NoMetadataPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end

    # No metadata/0 function
  end

  defmodule BadVersionPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "bad_version_plugin",
        version: "abc",
        author: "tester",
        api_version: "1.0"
      }
    end

    def plugin_info do
      %{name: __MODULE__, version: "abc"}
    end
  end

  defmodule BadApiVersionPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "bad_api_plugin",
        version: "1.0",
        author: "tester",
        api_version: "99.0"
      }
    end

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end
  end

  defmodule BadNamePlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{
        name: "123bad name",
        version: "1.0",
        author: "tester",
        api_version: "1.0"
      }
    end

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end
  end

  defmodule MissingFieldsPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    @impl true
    def init(_config), do: {:ok, %{}}
    @impl true
    def terminate(_reason, _state), do: :ok
    @impl true
    def enable(state), do: {:ok, state}
    @impl true
    def disable(state), do: {:ok, state}
    @impl true
    def filter_event(event, _state), do: {:ok, event}
    @impl true
    def handle_command(_cmd, _args, state), do: {:ok, state, nil}
    @impl true
    def get_commands, do: []

    def handle_event(event, state), do: {:ok, event, state}
    def cleanup(_state), do: :ok

    def metadata do
      %{name: "missing_fields"}
    end

    def plugin_info do
      %{name: __MODULE__, version: "1.0"}
    end
  end

  describe "validate_not_loaded/2" do
    test "returns :ok when plugin not in map" do
      assert :ok = PluginValidator.validate_not_loaded("my_plugin", %{})
    end

    test "returns error when plugin already in map" do
      plugins = %{"my_plugin" => SomeModule}

      assert {:error, :already_loaded} =
               PluginValidator.validate_not_loaded("my_plugin", plugins)
    end
  end

  describe "validate_behaviour/1" do
    test "returns :ok for valid plugin module" do
      assert :ok = PluginValidator.validate_behaviour(ValidPlugin)
    end

    test "returns error for non-existent module" do
      assert {:error, :module_not_found} =
               PluginValidator.validate_behaviour(NonExistentModule12345)
    end

    test "returns error for module without plugin behaviour" do
      # Enum exists but doesn't implement Plugin behaviour
      result = PluginValidator.validate_behaviour(Enum)
      assert {:error, _} = result
    end
  end

  describe "validate_metadata/1" do
    test "returns :ok for valid metadata" do
      assert :ok = PluginValidator.validate_metadata(ValidPlugin)
    end

    test "returns :ok for minimal valid metadata" do
      assert :ok = PluginValidator.validate_metadata(MinimalPlugin)
    end

    test "returns error when metadata/0 not exported" do
      assert {:error, :missing_metadata} =
               PluginValidator.validate_metadata(NoMetadataPlugin)
    end

    test "returns error for missing required fields" do
      assert {:error, {:missing_metadata_fields, missing}} =
               PluginValidator.validate_metadata(MissingFieldsPlugin)

      assert :version in missing
      assert :author in missing
      assert :api_version in missing
    end

    test "returns error for invalid version format" do
      assert {:error, :invalid_version_format} =
               PluginValidator.validate_metadata(BadVersionPlugin)
    end

    test "returns error for unsupported api version" do
      assert {:error, {:unsupported_api_version, "99.0"}} =
               PluginValidator.validate_metadata(BadApiVersionPlugin)
    end

    test "returns error for invalid plugin name" do
      assert {:error, :invalid_plugin_name} =
               PluginValidator.validate_metadata(BadNamePlugin)
    end
  end

  describe "validate_compatibility/1" do
    test "passes for current system" do
      assert :ok = PluginValidator.validate_compatibility(ValidPlugin)
    end
  end

  describe "validate_performance/1" do
    test "returns initialization_failed for modules without init/1" do
      Process.flag(:trap_exit, true)

      result =
        PluginValidator.validate_performance(Raxol.Core.Runtime.Plugins.PluginRegistry)

      assert {:error, {:initialization_failed, _}} = result
    end

    test "returns size_check_failed for in-memory modules" do
      Process.flag(:trap_exit, true)
      result = PluginValidator.validate_performance(ValidPlugin)
      assert {:error, {:size_check_failed, _}} = result
    end
  end

  describe "validate_dependencies/2" do
    test "returns :ok when no dependencies/0 function" do
      assert :ok = PluginValidator.validate_dependencies(NoDepsPlugin, %{})
    end

    test "returns :ok when all dependencies are loaded" do
      loaded = %{"dep_a" => SomeModA, "dep_b" => SomeModB}
      assert :ok = PluginValidator.validate_dependencies(WithDepsPlugin, loaded)
    end

    test "returns :ok when dependencies list is empty" do
      assert :ok = PluginValidator.validate_dependencies(ValidPlugin, %{})
    end

    test "returns error for missing dependencies" do
      loaded = %{"dep_a" => SomeModA}

      assert {:error, {:missing_dependencies, ["dep_b"]}} =
               PluginValidator.validate_dependencies(WithDepsPlugin, loaded)
    end

    test "returns error when all dependencies missing" do
      assert {:error, {:missing_dependencies, missing}} =
               PluginValidator.validate_dependencies(WithDepsPlugin, %{})

      assert "dep_a" in missing
      assert "dep_b" in missing
    end
  end

  describe "resolve_plugin_identity/1" do
    test "resolves atom module to id and module" do
      assert {:ok, {id, ValidPlugin}} =
               PluginValidator.resolve_plugin_identity(ValidPlugin)

      assert is_binary(id)
      assert String.contains?(id, "ValidPlugin")
    end

    test "returns error for non-existent atom module" do
      assert {:error, :module_not_found} =
               PluginValidator.resolve_plugin_identity(FakeModule12345)
    end
  end

  describe "version format validation" do
    test "accepts major.minor format" do
      assert :ok = PluginValidator.validate_metadata(MinimalPlugin)
    end

    test "accepts major.minor.patch format" do
      assert :ok = PluginValidator.validate_metadata(ValidPlugin)
    end

    test "rejects alphabetic version" do
      assert {:error, :invalid_version_format} =
               PluginValidator.validate_metadata(BadVersionPlugin)
    end
  end

  describe "name format validation" do
    test "accepts valid names with underscores" do
      # ValidPlugin has name "valid_plugin"
      assert :ok = PluginValidator.validate_metadata(ValidPlugin)
    end

    test "rejects names starting with numbers" do
      # BadNamePlugin has name "123bad name"
      assert {:error, :invalid_plugin_name} =
               PluginValidator.validate_metadata(BadNamePlugin)
    end
  end

  describe "validate_security/2" do
    test "passes for module with beam file and no risky operations" do
      # PluginRegistry has a .beam file and doesn't do file/network/code_injection
      assert :ok =
               PluginValidator.validate_security(Raxol.Core.Runtime.Plugins.PluginRegistry)
    end

    test "passes with all restrictions disabled" do
      # Even for modules without .beam files, disabling restrictions skips
      # file and network checks. code_injection/resource_limits still run
      # but BeamAnalyzer returns false when it can't find abstract code.
      result =
        PluginValidator.validate_security(
          Raxol.Core.Runtime.Plugins.PluginRegistry,
          %{restrict_file_access: false, restrict_network_access: false}
        )

      assert :ok = result
    end
  end
end
