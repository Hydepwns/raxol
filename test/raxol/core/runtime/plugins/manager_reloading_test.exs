defmodule Raxol.Core.Runtime.Plugins.ManagerReloadingTest do
  use ExUnit.Case, async: true
  # use Properties.Case # If needed for property tests
  # No Mox import needed if only using meck

  # --- Aliases & Meck Setup ---
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.{LifecycleHelper, Loader, CommandRegistry, PluginMetadataProvider}
  # Keep MockPluginBehaviour defined below as it IS a behaviour

  # Using meck for Loader and LifecycleHelper as they are not behaviours
  # defmock LifecycleHelperMock, for: Raxol.Core.Runtime.Plugins.LifecycleHelper <-- Removed

  # Keep Mox for behaviours we define in the test
  import Mox

  # --- Mocks & Mock Behaviours (if needed by reloading logic) ---

  # Mock Plugin Behaviours (copied from original test)
  defmodule MockPluginBehaviour do
    @callback id() :: atom
    @callback version() :: String.t()
    @callback init(Keyword.t()) :: {:ok, map} | {:error, any}
    @callback terminate(atom, map) :: any
    @callback get_commands() :: [{atom, function, non_neg_integer}]
  end
  defmock MockPluginBehaviour, for: MockPluginBehaviour

  defmodule MockPluginMetadataProvider do
    @callback metadata() :: map
  end
  defmock MockPluginMetadataProvider, for: MockPluginMetadataProvider

  # Alias the mock plugin behaviour
  alias Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
  alias Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider

  # --- Setup & Teardown ---
  # Common setup for reloading tests
  setup %{test: test_name} do
    # Mox.verify_on_exit!(self) # Only if Mox mocks used

    # Setup meck for Loader and LifecycleHelper
    :meck.new(Loader, [:passthrough])
    :meck.new(LifecycleHelper, [:passthrough])
    on_exit(fn -> :meck.unload([Loader, LifecycleHelper]) end)

    # Create a temporary directory for test plugins
    {:ok, tmp_dir} = Briefly.create(directory: true)
    on_exit(fn -> Briefly.remove!(tmp_dir) end)

    # Unique ETS table for command registry
    table_name = :"#{test_name}_ReloadingReg"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    on_exit(fn -> :ets.delete(table_name) end)

    # Base start options for reloading tests
    start_opts = [
      name: :"#{test_name}_PluginManagerReloading",
      plugin_dirs: [tmp_dir],
      loader_module: Loader, # Use mecked Loader
      lifecycle_helper_module: LifecycleHelper, # Use mecked LifecycleHelper
      command_registry_table: table_name
      # command_helper_module? Depends if reload triggers command logic
    ]

    {:ok, tmp_dir: tmp_dir, base_opts: start_opts, table: table_name}
  end

  # Helper to create/update plugin files
  # Version 1 Plugin
  defp create_plugin_v1(dir) do
    module_name = :MockPluginV1
    plugin_code = """
    defmodule #{module_name} do
      @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
      @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider

      def id, do: :mock_plugin
      def version, do: "1.0"
      def init(_opts), do: {:ok, %{version: 1, id: id()}}
      def terminate(_reason, _state), do: :ok
      def get_commands, do: [{:command_v1, &__MODULE__.handle_cmd/1, 1}]
      def handle_cmd(_args), do: :v1_handled
      def metadata, do: %{id: id(), version: version(), dependencies: []}
    end
    """
    file_path = Path.join(dir, "#{module_name}.exs")
    File.write!(file_path, plugin_code)
    {:ok, _module, _binary} = Code.compile_file(file_path) # Compile immediately
    {module_name, file_path}
  end

  # Version 2 Plugin (same module name, different code)
  defp create_plugin_v2(dir) do
    module_name = :MockPluginV1 # Same name as V1
    plugin_code = """
          defmodule #{module_name} do
            @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
            @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider

            def id, do: :mock_plugin # Keep the same ID
            def version, do: "2.0"
            def init(_opts), do: {:ok, %{version: 2, id: id()}}
            def terminate(_reason, _state), do: :ok
            def get_commands, do: [{:command_v2, &__MODULE__.handle_cmd/1, 1}]
            def handle_cmd(_args), do: :v2_handled
            def metadata, do: %{id: id(), version: version(), dependencies: []}
          end
          """
    file_path = Path.join(dir, "#{module_name}.exs") # Overwrite V1
    File.write!(file_path, plugin_code)
    # Compile the new version immediately
    {:ok, _module, _binary} = Code.compile_file(file_path)
    {module_name, file_path}
  end

  # --- Plugin Reloading Test Cases ---
  describe "Plugin Reloading" do
    test "reloads a modified plugin file", %{tmp_dir: dir, base_opts: opts, table: table} do
      # Arrange: Initial load with V1
      {module_name_v1, path_v1} = create_plugin_v1(dir)

      # Set expectations for initial load
      :meck.expect(Loader, :discover_plugins, fn [^dir] -> [%{module: module_name_v1, path: path_v1}] end)
      :meck.expect(Loader, :load_plugin_metadata, fn ^module_name_v1 -> {:ok, MockPluginV1} end)
      :meck.expect(Loader, :load_plugin_module, fn ^module_name_v1 -> {:ok, MockPluginV1} end)
      :meck.expect(LifecycleHelper, :init_plugin, fn MockPluginV1, _ -> {:ok, %{version: 1, id: :mock_plugin}} end)

      {:ok, pid} = Manager.start_link(opts)
      assert Manager.get_plugin_info(pid, :mock_plugin) != nil
      assert CommandRegistry.lookup(table, {:mock_plugin, :command_v1}) == {:ok, MockPluginV1}
      :meck.verify(Loader)
      :meck.verify(LifecycleHelper)
      :meck.reset(Loader) # Reset expectations for reload
      :meck.reset(LifecycleHelper)

      # Arrange: Modify the plugin file to V2
      {module_name_v2, path_v2} = create_plugin_v2(dir) # Overwrites and compiles V2
      assert module_name_v1 == module_name_v2 # Should be the same module name
      assert path_v1 == path_v2

      # Arrange: Set expectations for the reload process
      # 1. Terminate old plugin
      :meck.expect(LifecycleHelper, :terminate_plugin, fn :mock_plugin, MockPluginV1, %{version: 1, id: :mock_plugin} -> :ok end)
      # 2. Loader loads new metadata
      :meck.expect(Loader, :load_plugin_metadata, fn ^module_name_v2 -> {:ok, MockPluginV1} end) # Module name is still MockPluginV1
      # 3. Loader loads new module code
      :meck.expect(Loader, :load_plugin_module, fn ^module_name_v2 -> {:ok, MockPluginV1} end)
      # 4. LifecycleHelper inits new plugin version
      :meck.expect(LifecycleHelper, :init_plugin, fn MockPluginV1, _ -> {:ok, %{version: 2, id: :mock_plugin}} end)

      # Act: Trigger reload (assuming Manager has a :reload call or watches file changes)
      # If file watching is internal, just wait briefly and assert
      # If manual reload needed: GenServer.cast(pid, :reload_plugins)
      # For simplicity, let's assume a manual reload call
      :ok = GenServer.call(pid, :reload_plugins)

      # Assert: V1 command gone, V2 command present, state updated
      assert CommandRegistry.lookup(table, {:mock_plugin, :command_v1}) == :error
      assert CommandRegistry.lookup(table, {:mock_plugin, :command_v2}) == {:ok, MockPluginV1}

      plugin_states = GenServer.call(pid, :get_plugin_states)
      assert Map.get(plugin_states, :mock_plugin) == %{version: 2, id: :mock_plugin}

      # Assert: Mecks were called
      :meck.verify(Loader)
      :meck.verify(LifecycleHelper)

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
      :meck.unload([Loader, LifecycleHelper])
    end

    # Add more tests: removing plugin file, adding new file, reload failure etc.

  end # describe
end # module
