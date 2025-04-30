defmodule Raxol.Core.Runtime.Plugins.ManagerTest do
  use ExUnit.Case, async: true
  # Import Mox for mocking
  import Mox

  # Define mocks for dependencies
  # Using a mock module for Code since Code is not a behavior
  defmodule CodeBehavior do
    @callback compile_file(String.t(), Keyword.t()) :: atom | no_return
    @callback purge(atom) :: boolean
    @callback ensure_loaded(atom) :: {:module, atom} | {:error, atom}
  end
  defmock CodeMock, for: CodeBehavior
  defmock LoaderMock, for: Raxol.Core.Runtime.Plugins.Loader
  defmock MockPluginBehaviour, for: Raxol.Core.Runtime.Plugins.Plugin # Define a behaviour plugins implement
  # Add metadata provider behaviour
  defmock MockPluginMetadataProvider, for: Raxol.Core.Runtime.Plugins.PluginMetadataProvider

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  # --- Mock Plugin Definitions ---
  # Define a mock behaviour that our test plugins will implement
  # This allows us to set expectations on init/terminate using Mox
  defmodule MockPluginBehaviour do
    @callback id() :: atom
    @callback version() :: String.t()
    @callback init(Keyword.t()) :: {:ok, map} | {:error, any}
    @callback terminate(atom, map) :: any
    @callback get_commands() :: [{atom, String.t()}]
    # Add other callbacks if Manager interacts with them directly
  end

  # Behaviour for metadata
  defmodule Raxol.Core.Runtime.Plugins.PluginMetadataProvider do
    @callback metadata() :: %{
      id: atom,
      version: String.t(),
      dependencies: [{atom, String.t()}]
    }
  end

  defmodule MockPluginV1 do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :mock_plugin
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{version: 1, id: :mock_plugin}}
    def terminate(_reason, _state), do: :ok
    def get_commands, do: [{:command_v1, "Desc V1"}]
    def metadata, do: %{id: id(), version: version(), dependencies: []}
  end

  defmodule MockPluginV2 do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :mock_plugin # Same ID
    def version, do: "2.0"
    def init(_opts), do: {:ok, %{version: 2, id: :mock_plugin}}
    def terminate(_reason, _state), do: :ok
    def get_commands, do: [{:command_v2, "Desc V2"}]
    def metadata, do: %{id: id(), version: version(), dependencies: []}
  end

  # Plugins for Dependency Tests
  defmodule MockPluginA do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :plugin_a
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_a, "A"}]
    def metadata, do: %{id: id(), version: version(), dependencies: []}
  end

  defmodule MockPluginB do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :plugin_b
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_b, "B"}]
    def metadata, do: %{id: id(), version: version(), dependencies: [{:plugin_a, "~> 1.0"}]}
  end

  defmodule MockPluginC do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :plugin_c
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_c, "C"}]
    def metadata, do: %{id: id(), version: version(), dependencies: [{:plugin_b, "~> 1.0"}]}
  end

  defmodule MockPluginD do # Depends on non-existent E
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :plugin_d
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_d, "D"}]
    def metadata, do: %{id: id(), version: version(), dependencies: [{:plugin_e, "~> 1.0"}]}
  end

  defmodule MockPluginCircularA do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :circular_a
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_circ_a, "CircA"}]
    def metadata, do: %{id: id(), version: version(), dependencies: [{:circular_b, "~> 1.0"}]}
  end

  defmodule MockPluginCircularB do
    @behaviour MockPluginBehaviour
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    def id, do: :circular_b
    def version, do: "1.0"
    def init(_opts), do: {:ok, %{id: id()}}
    def terminate(_, _), do: :ok
    def get_commands, do: [{:cmd_circ_b, "CircB"}]
    def metadata, do: %{id: id(), version: version(), dependencies: [{:circular_a, "~> 1.0"}]}
  end


  # --- Setup & Teardown ---

  setup do
    # Verify mocks in testing
    Mox.verify_on_exit!()
    # Can't stub_with a behavior, so just set up expectations as needed

    Mox.stub_with(LoaderMock, Raxol.Core.Runtime.Plugins.Loader)

    # Start the CommandRegistry ETS table
    {:ok, table} = CommandRegistry.start_link()
    # Start the PluginManager
    # Ensure PluginManager uses the LoaderMock and potentially CodeMock
    # This might require passing mocks or using Application env config in Manager
    # For now, assume Manager calls LoaderMock and CodeMock directly via Module.function()
    {:ok, manager_pid} = Manager.start_link(command_registry_table: table)
    %{manager: manager_pid, table: table}
  end

  # --- Test Cases ---

  test "initializes correctly", %{manager: _manager} do
    # Basic check to ensure the process starts
    assert Process.alive?(Process.whereis(Manager))
  end

  test "initialize loads plugins (placeholder)", %{manager: manager} do
    # This test assumes a default plugin directory and potentially mock plugins
    # TODO: Enhance with actual mock plugins and directory structure
    assert {:ok, _status} = GenServer.call(manager, :initialize)
    # Basic assertion: check if initialization state changes
    # assert Manager.is_initialized?() # Needs an API function
  end

  test "list_plugins returns empty list initially", %{manager: manager} do
    assert GenServer.call(manager, :list_plugins) == []
  end

  describe "Plugin Initialization" do
    test "initialization skips plugins with unmet dependencies", %{manager: manager, table: table} do
      plugin_a_path = "/fake/path/mock_plugin_a.ex"
      plugin_b_path = "/fake/path/mock_plugin_b.ex"
      plugin_d_path = "/fake/path/mock_plugin_d.ex" # Depends on non-existent E

      # Expect discovery to find A, B, and D
      expect(LoaderMock, :discover_plugins, fn _dir ->
        [
          {MockPluginA, plugin_a_path},
          {MockPluginB, plugin_b_path},
          {MockPluginD, plugin_d_path}
        ]
      end)

      # Expect metadata extraction for all three
      expect(LoaderMock, :extract_metadata, fn
        MockPluginA -> MockPluginA.metadata()
        MockPluginB -> MockPluginB.metadata()
        MockPluginD -> MockPluginD.metadata()
      end)

      # Expect init to be called ONLY for A and B (correct load order)
      expect(MockPluginBehaviour, :init, fn
        # Capture the calls to ensure only A and B are initialized
        opts when opts == %{} -> {:ok, %{}}
      end |> times(2)) # Expect init for A and B

      # Trigger initialization
      assert {:ok, _} = GenServer.call(manager, :initialize)

      # Verify A and B are loaded, D is not
      assert Manager.get_plugin_info(manager, MockPluginA.id()) != nil
      assert CommandRegistry.lookup(table, {MockPluginA.id(), :cmd_a}) == {:ok, MockPluginA}

      assert Manager.get_plugin_info(manager, MockPluginB.id()) != nil
      assert CommandRegistry.lookup(table, {MockPluginB.id(), :cmd_b}) == {:ok, MockPluginB}

      # Plugin D should not be loaded due to missing dependency E
      assert Manager.get_plugin_info(manager, MockPluginD.id()) == nil
      assert CommandRegistry.lookup(table, {MockPluginD.id(), :cmd_d}) == :error
    end

    test "initialization fails with circular dependency", %{manager: manager, table: table} do
      circ_a_path = "/fake/path/mock_plugin_circular_a.ex"
      circ_b_path = "/fake/path/mock_plugin_circular_b.ex"

      # Expect discovery to find Circular A and B
      expect(LoaderMock, :discover_plugins, fn _dir ->
        [
          {MockPluginCircularA, circ_a_path},
          {MockPluginCircularB, circ_b_path}
        ]
      end)

      # Expect metadata extraction for both
      expect(LoaderMock, :extract_metadata, fn
        MockPluginCircularA -> MockPluginCircularA.metadata()
        MockPluginCircularB -> MockPluginCircularB.metadata()
      end)

      # Expect init NOT to be called for either due to circular dependency
      # Mox will verify no calls to init are made because we don't expect() them.

      # Trigger initialization - Expect specific error
      # LifecycleHelper.initialize_plugins returns the error, Manager should propagate it.
      assert {:error, :circular_dependency} = GenServer.call(manager, :initialize)

      # Verify neither plugin is loaded
      assert Manager.get_plugin_info(manager, MockPluginCircularA.id()) == nil
      assert CommandRegistry.lookup(table, {MockPluginCircularA.id(), :cmd_circ_a}) == :error

      assert Manager.get_plugin_info(manager, MockPluginCircularB.id()) == nil
      assert CommandRegistry.lookup(table, {MockPluginCircularB.id(), :cmd_circ_b}) == :error
    end
  end

  describe "Plugin Reloading" do
    test "successfully reloads a changed plugin", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # 1. Expect discovery to find V1 initially
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      # Expect V1 init to be called via LifecycleHelper (invoked by Manager)
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 1}} end)

      # Initialize the manager, which should load V1
      assert {:ok, _} = GenServer.call(manager, :initialize)

      # Verify V1 is loaded by checking registered commands
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}
      assert Manager.get_plugin_info(manager, plugin_id) != nil # Check plugin is tracked

      # 2. Setup expectations for reload triggered via Manager -> LifecycleHelper
      # Expect terminate on V1
      expect(MockPluginBehaviour, :terminate, 1, fn :reload, %{version: 1} -> :ok end)
      # Expect purge for V1 module
      expect(CodeMock, :purge, 1, fn MockPluginV1 -> :ok end)
      # Expect compile_file for the fake path, simulate it "compiling" V2
      expect(CodeMock, :compile_file, 1, fn ^fake_plugin_path -> {:ok, MockPluginV2} end) # Return V2 module
      # Expect ensure_loaded for V2
      expect(CodeMock, :ensure_loaded, 1, fn MockPluginV2 -> {:module, MockPluginV2} end)
      # Expect init on V2
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 2}} end)

      # 3. Trigger the reload via the manager
      assert :ok = GenServer.call(manager, {:reload_plugin, plugin_id})

      # 4. Verify V2 is now loaded and V1 is gone
      # V1 command should be gone from registry
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == :error
      # V2 command should be present in registry
      assert CommandRegistry.lookup(table, {plugin_id, :command_v2}) == {:ok, MockPluginV2}
      # Check manager tracks the new module
      plugin_info = Manager.get_plugin_info(manager, plugin_id)
      assert plugin_info.module == MockPluginV2

      # Mox.verify_on_exit! handles verification
    end

    test "fails reload if init fails", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # 1. Load V1 successfully first
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 1}} end)
      assert {:ok, _} = GenServer.call(manager, :initialize)
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}

      # 2. Setup expectations for reload where V2 init fails
      expect(MockPluginBehaviour, :terminate, 1, fn :reload, %{version: 1} -> :ok end)
      expect(CodeMock, :purge, 1, fn MockPluginV1 -> :ok end)
      expect(CodeMock, :compile_file, 1, fn ^fake_plugin_path -> {:ok, MockPluginV2} end)
      expect(CodeMock, :ensure_loaded, 1, fn MockPluginV2 -> {:module, MockPluginV2} end)
      # Expect init on V2 to FAIL
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:error, :init_failed} end)

      # 3. Trigger the reload
      # Assert the specific error tuple returned by the reload process
      # This assumes LifecycleHelper/Manager propagates the init error
      assert {:error, {:init_failed, MockPluginV2}} = GenServer.call(manager, {:reload_plugin, plugin_id})

      # 4. Verify plugin V1 and V2 are inactive
      # V1 command should be gone (unregistered during unload)
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == :error
      # V2 command should NOT be registered due to init failure
      assert CommandRegistry.lookup(table, {plugin_id, :command_v2}) == :error
      # Manager should not track the plugin after failed reload (or track as failed)
      # Assuming it removes it if reload fails completely
      assert Manager.get_plugin_info(manager, plugin_id) == nil
    end

    test "fails reload if compilation fails", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # 1. Load V1 successfully first
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 1}} end)
      assert {:ok, _} = GenServer.call(manager, :initialize)
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}
      assert Manager.get_plugin_info(manager, plugin_id).module == MockPluginV1

      # 2. Setup expectations for reload where compilation fails
      # Note: Depending on implementation, terminate/purge might happen *before*
      # or *after* compilation attempt. Assuming *before* here.
      expect(MockPluginBehaviour, :terminate, 1, fn :reload, %{version: 1} -> :ok end)
      expect(CodeMock, :purge, 1, fn MockPluginV1 -> :ok end)
      # Expect compile_file to FAIL
      expect(CodeMock, :compile_file, 1, fn ^fake_plugin_path -> {:error, {:compile_error, "Syntax error"}} end)

      # 3. Trigger the reload
      # Assert the specific error tuple returned by the reload process
      # This assumes the manager/helper propagates the compile error
      assert {:error, {:compile_error, MockPluginV1, "Syntax error"}} = GenServer.call(manager, {:reload_plugin, plugin_id})

      # 4. Verify original plugin V1 REMAINS active
      # The reload failed, so the original plugin should ideally be restored or left untouched.
      # This depends heavily on the LifecycleHelper's error handling strategy.
      # Assuming the manager restores V1's state or never fully removed it.
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}
      # V2 command should definitely NOT be registered
      assert CommandRegistry.lookup(table, {plugin_id, :command_v2}) == :error
      # Manager should still track V1
      assert Manager.get_plugin_info(manager, plugin_id).module == MockPluginV1
    end

    test "returns error when reloading non-existent plugin", %{manager: manager, table: _table} do
      non_existent_plugin_id = :unknown_plugin

      # Attempt to reload a plugin that was never loaded
      assert {:error, :not_found} = GenServer.call(manager, {:reload_plugin, non_existent_plugin_id})
      # Or assert {:error, {:not_found, ^non_existent_plugin_id}} = ... depending on Manager's return value

      # Verify manager state is unchanged for this ID
      assert Manager.get_plugin_info(manager, non_existent_plugin_id) == nil
      # Mox will verify no unexpected lifecycle/code functions were called
    end

    test "plugin remains unloaded if code purge fails during reload", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # 1. Load V1 successfully first
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 1}} end)
      assert {:ok, _} = GenServer.call(manager, :initialize)
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}

      # 2. Setup expectations for reload where code purge fails
      expect(MockPluginBehaviour, :terminate, 1, fn :reload, %{version: 1} -> :ok end) # Unload succeeds
      # Expect purge for V1 module to FAIL
      # Need to raise or return error? :code.purge returns boolean or raises?
      # Let's assume it raises an error based on docs/common patterns for failed native calls
      expect(CodeMock, :purge, 1, fn MockPluginV1 -> raise "Purge failed!" end)

      # Compilation, loading, V2 init should NOT be called

      # 3. Trigger the reload
      # Assert the specific error tuple - assuming :reload_exception is used
      assert {:error, {:reload_exception, %RuntimeError{message: "Purge failed!"}}} = GenServer.call(manager, {:reload_plugin, plugin_id})

      # 4. Verify plugin V1 is still unloaded and V2 was never loaded
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == :error
      assert CommandRegistry.lookup(table, {plugin_id, :command_v2}) == :error
      assert Manager.get_plugin_info(manager, plugin_id) == nil
    end
  end

  # --- Test Cases for Loading/Unloading ---

  describe "Plugin Loading and Unloading" do
    test "successfully loads a plugin during initialization", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # Expect discovery to find V1
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      # Expect V1 init to be called and succeed
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:ok, %{version: 1, id: plugin_id}} end)

      # Initialize the manager
      assert {:ok, _} = GenServer.call(manager, :initialize)

      # Verify V1 is loaded
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == {:ok, MockPluginV1}
      plugin_info = Manager.get_plugin_info(manager, plugin_id)
      assert plugin_info != nil
      assert plugin_info.module == MockPluginV1
      assert plugin_info.path == fake_plugin_path
      # Assuming Manager stores the state returned by init under an :state key
      # assert plugin_info.state == %{version: 1, id: plugin_id}
      # Check the full list
      assert GenServer.call(manager, :list_plugins) == [plugin_id]
    end

    test "handles plugin init failure during initialization", %{manager: manager, table: table} do
      fake_plugin_path = "/fake/path/mock_plugin_v1.ex"
      plugin_id = MockPluginV1.id()

      # Expect discovery to find V1
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginV1, fake_plugin_path}] end)
      # Expect V1 init to be called and FAIL
      expect(MockPluginBehaviour, :init, 1, fn _ -> {:error, :init_failed_reason} end)

      # Initialize the manager
      # Initialization should still succeed overall, but log the plugin error
      # Or return {:ok, %{failed: [...]}} - Assuming it logs and continues for now.
      assert {:ok, %{loaded: [], failed: [{MockPluginV1, :init_failed_reason}]}} = GenServer.call(manager, :initialize)

      # Verify V1 is NOT loaded
      assert CommandRegistry.lookup(table, {plugin_id, :command_v1}) == :error
      assert Manager.get_plugin_info(manager, plugin_id) == nil
      assert GenServer.call(manager, :list_plugins) == []
    end

    # TODO: Add tests for dependency resolution (success, missing, circular)
    # TODO: Add tests for unloading a specific plugin (if applicable API exists)
  end

  describe "Plugin Dependency Handling" do
    test "loads plugins in correct dependency order", %{manager: manager, table: table} do
      path_a = "/fake/a.ex"
      path_b = "/fake/b.ex"
      path_c = "/fake/c.ex"

      # Discover plugins out of order
      expect(LoaderMock, :discover_plugins, fn _opts ->
        [
          {MockPluginC, path_c},
          {MockPluginA, path_a},
          {MockPluginB, path_b}
        ]
      end)

      # Expect init calls in the correct order (A -> B -> C)
      expect(MockPluginBehaviour, :init, 3, fn _opts ->
        # We can't easily assert order directly here with simple Mox expectations,
        # but the successful assertion of loaded plugins implies correct ordering.
        # A more complex setup could involve passing state or usingmeck.
        {:ok, %{id: :unknown}} # Generic ok response for all
      end)

      # Initialize the manager
      assert {:ok, %{loaded: loaded_ids, failed: []}} = GenServer.call(manager, :initialize)
      # Assert the *reported* loaded order matches dependency order
      assert loaded_ids == [:plugin_a, :plugin_b, :plugin_c]

      # Verify all plugins are loaded and registered
      assert CommandRegistry.lookup(table, {:plugin_a, :cmd_a}) == {:ok, MockPluginA}
      assert Manager.get_plugin_info(manager, :plugin_a).path == path_a

      assert CommandRegistry.lookup(table, {:plugin_b, :cmd_b}) == {:ok, MockPluginB}
      assert Manager.get_plugin_info(manager, :plugin_b).path == path_b

      assert CommandRegistry.lookup(table, {:plugin_c, :cmd_c}) == {:ok, MockPluginC}
      assert Manager.get_plugin_info(manager, :plugin_c).path == path_c

      assert GenServer.call(manager, :list_plugins) == [:plugin_a, :plugin_b, :plugin_c]
    end

    test "fails to load plugin with missing dependency", %{manager: manager, table: table} do
      path_d = "/fake/d.ex"

      # Discover plugin D which depends on non-existent E
      expect(LoaderMock, :discover_plugins, fn _opts -> [{MockPluginD, path_d}] end)
      # Expect init NOT to be called for D
      expect(MockPluginBehaviour, :init, 0, fn _ -> {:ok, %{}} end)

      # Initialize the manager
      # Expect failure reported for D
      assert {:ok, %{loaded: [], failed: [{MockPluginD, {:missing_dependency, :plugin_e}}]}} = GenServer.call(manager, :initialize)

      # Verify D is not loaded
      assert CommandRegistry.lookup(table, {:plugin_d, :cmd_d}) == :error
      assert Manager.get_plugin_info(manager, :plugin_d) == nil
      assert GenServer.call(manager, :list_plugins) == []
    end

    test "fails to load plugins with circular dependency", %{manager: manager, table: table} do
      path_ca = "/fake/circ_a.ex"
      path_cb = "/fake/circ_b.ex"

      # Discover circular plugins
      expect(LoaderMock, :discover_plugins, fn _opts ->
        [{MockPluginCircularA, path_ca}, {MockPluginCircularB, path_cb}]
      end)
      # Expect init NOT to be called for either
      expect(MockPluginBehaviour, :init, 0, fn _ -> {:ok, %{}} end)

      # Initialize the manager
      # Expect failure reported for both due to circular dependency
      # The exact error format might depend on the sorting implementation
      assert {:ok, %{loaded: [], failed: failed_plugins}} = GenServer.call(manager, :initialize)
      # Check both plugins are in the failed list with a circular dependency reason
      assert Enum.sort(failed_plugins) == Enum.sort([
        {MockPluginCircularA, {:circular_dependency, [:circular_a, :circular_b]}},
        {MockPluginCircularB, {:circular_dependency, [:circular_a, :circular_b]}}
        # Or similar structure indicating the cycle
      ])

      # Verify neither is loaded
      assert CommandRegistry.lookup(table, {:circular_a, :cmd_circ_a}) == :error
      assert Manager.get_plugin_info(manager, :circular_a) == nil
      assert CommandRegistry.lookup(table, {:circular_b, :cmd_circ_b}) == :error
      assert Manager.get_plugin_info(manager, :circular_b) == nil
      assert GenServer.call(manager, :list_plugins) == []
    end
  end

  # TODO: Add tests for:
  # - Loading a plugin with dependencies
  # - Handling missing dependencies

end
