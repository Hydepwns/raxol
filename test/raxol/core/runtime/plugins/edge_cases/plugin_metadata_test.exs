defmodule Raxol.Core.Runtime.Plugins.EdgeCases.PluginMetadataTest do
  use ExUnit.Case
  import Mox

  alias Raxol.Core.Runtime.Plugins.Loader
  alias Raxol.Test.PluginTestFixtures
  alias Raxol.Core.Runtime.Plugins.EdgeCases.Helper

  setup do
    Helper.setup_test()
  end

  describe "plugin metadata validation" do
    test "handles invalid plugin metadata", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Loader will return invalid metadata
        Mox.expect(Loader, :load_plugin_metadata, fn
          PluginTestFixtures.InvalidMetadataPlugin ->
            {:ok, %{
              id: nil,  # Invalid: missing required field
              version: "not_a_semver",  # Invalid: not a valid semver
              dependencies: [
                {:invalid_dependency, "invalid_version"},  # Invalid: wrong format
                {:missing_required_field, nil},  # Invalid: missing required field
                {:invalid_type, 123}  # Invalid: wrong type
              ],
              # Missing required fields
              name: nil,
              description: nil,
              author: nil
            }}
          # Default case
          _ -> {:ok, %{id: :test, version: "1.0.0", dependencies: []}}
        end)

        # Test loading with invalid metadata
        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.InvalidMetadataPlugin,
          %{},
          {:error, {:invalid_metadata, [
            :missing_required_field,
            :invalid_version_format,
            :invalid_dependency_format,
            :invalid_dependency_type
          ]}}
        )
      end)
    end

    test "handles missing plugin metadata", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Loader will fail to load metadata
        Mox.expect(Loader, :load_plugin_metadata, fn
          PluginTestFixtures.MissingMetadataPlugin -> {:error, :metadata_not_found}
          # Default case
          _ -> {:ok, %{id: :test, version: "1.0.0", dependencies: []}}
        end)

        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.MissingMetadataPlugin,
          %{},
          {:error, {:metadata_load_failed, :metadata_not_found}}
        )
      end)
    end

    test "handles malformed plugin metadata", %{command_registry_table: table} do
      Helper.with_running_manager([command_registry_table: table], fn manager_pid ->
        # Setup: Loader will return malformed metadata
        Mox.expect(Loader, :load_plugin_metadata, fn
          PluginTestFixtures.MalformedMetadataPlugin ->
            {:ok, "not_a_map"}  # Invalid: metadata should be a map
          # Default case
          _ -> {:ok, %{id: :test, version: "1.0.0", dependencies: []}}
        end)

        Helper.assert_plugin_load_fails(
          manager_pid,
          PluginTestFixtures.MalformedMetadataPlugin,
          %{},
          {:error, {:invalid_metadata_format, :not_a_map}}
        )
      end)
    end
  end
end
