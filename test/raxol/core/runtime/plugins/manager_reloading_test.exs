# Define mock behaviours outside the test module
defmodule Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour do
  @callback id() :: atom
  @callback version() :: String.t()
  @callback init(Keyword.t()) :: {:ok, map} | {:error, any}
  @callback terminate(atom, map) :: any
  @callback get_commands() :: [{atom, function, non_neg_integer}]
end

defmodule Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider do
  @callback metadata() :: map
end

# Now define the test module
defmodule Raxol.Core.Runtime.Plugins.ManagerReloadingTest do
  use ExUnit.Case, async: true
  require Mox
  # use Mox # COMMENTED OUT
  # Instead of 'use Mox', we will use fully qualified names like Mox.defmock, Mox.stub, etc.

  # MOVED behaviour definitions inside the test module
  defmodule MockPluginBehaviour do
    @moduledoc """
    A mock behaviour for testing plugin interactions.
    """
    @callback init(map()) :: {:ok, map()} | {:error, any()}
    @callback handle_output(String.t(), map()) :: String.t() | {:error, any()}
    @callback terminate(any(), map()) :: :ok
    # Add other callbacks as needed by the tests
  end

  defmodule MockPluginMetadataProvider do
    @moduledoc """
    A mock behaviour for providing plugin metadata.
    """
    @callback get_metadata(String.t()) :: {:ok, map()} | {:error, :not_found}
    # Add other callbacks as needed
  end

  # Defmocks for behaviours (now including those defined inside this module)
  # UNCOMMENTED
  Mox.defmock(MockPluginBehaviour,
    for: Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
  )

  # UNCOMMENTED
  Mox.defmock(MockPluginMetadataProvider,
    for:
      Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider
  )

  # Mox mock for LoaderBehaviour
  # UNCOMMENTED
  Mox.defmock(LoaderMock, for: Raxol.Core.Runtime.Plugins.LoaderBehaviour)

  # --- Aliases & Meck Setup ---
  alias Raxol.Core.Runtime.Plugins.Manager

  alias Raxol.Core.Runtime.Plugins.ManagerReloadingTest.{
    MockPluginBehaviour,
    MockPluginMetadataProvider
  }

  # We are not using meck in this test, relying purely on Mox for the reloaded module.

  # --- Setup & Teardown ---
  # Common setup for reloading tests
  setup %{test: test_name} do
    # Mox.verify_on_exit!(self) # Handled by `use Mox`

    # Start with a clean slate, create temp dir
    {:ok, tmp_dir} = Briefly.create(type: :directory)

    on_exit(fn ->
      Briefly.cleanup()
    end)

    # Unique ETS table for command registry
    table_name = :"#{test_name}_ReloadingReg"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    on_exit(fn ->
      if :ets.whereis(table_name) != :undefined, do: :ets.delete(table_name)
    end)

    # Base start options for reloading tests
    start_opts = [
      name: :"#{test_name}_PluginManagerReloading",
      plugin_dirs: [tmp_dir],
      # Use Mox mock for Loader
      loader_module: LoaderMock,
      command_registry_table: table_name,
      runtime_pid: self()
    ]

    # Stub Loader globally for this test process
    # Mox.stub_with(LoaderMock, Raxol.Core.Runtime.Plugins.Loader) # Stub with the real Loader

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
    # Correctly handle the return value of Code.compile_file
    case Code.compile_file(file_path) do
      [{^module_name, _binary}] -> {module_name, file_path}
      other -> raise "Failed to compile plugin V1: #{inspect(other)}"
    end
  end

  # Version 2 Plugin (same module name, different code)
  defp create_plugin_v2(dir) do
    # Keep same module name for reloading
    module_name = :MockPluginV1

    plugin_code = """
    defmodule #{module_name} do
      @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
      @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider

      def id, do: :mock_plugin
      def version, do: "2.0"
      def init(_opts), do: {:ok, %{version: 2, id: id()}}
      def terminate(_reason, _state), do: :ok
      def get_commands, do: [{:command_v2, &__MODULE__.handle_cmd/1, 1}]
      def handle_cmd(_args), do: :v2_handled
      def metadata, do: %{id: id(), version: version(), dependencies: []}
    end
    """

    file_path = Path.join(dir, "#{module_name}.exs")
    File.write!(file_path, plugin_code)
    # Correctly handle the return value of Code.compile_file
    case Code.compile_file(file_path) do
      [{^module_name, _binary}] -> {module_name, file_path}
      other -> raise "Failed to compile plugin V2: #{inspect(other)}"
    end
  end

  # --- Test Cases ---
  describe "Plugin Reloading" do
    @tag :reloading
    test "Plugin Reloading reloads a modified plugin file", %{test: test_name} do
      # Allow direct mocking of the concrete LifecycleHelper for this test
      # Mox.allow(Raxol.Core.Runtime.Plugins.LifecycleHelper, self()) # OLD
      # Mox.allow(Raxol.Core.Runtime.Plugins.LifecycleHelper, self(), nil) # OLD 2
      # NEW: Use allow/3 with function
      Mox.allow(Raxol.Core.Runtime.Plugins.LifecycleHelper, self(), fn ->
        raise "Unexpected call"
      end)

      # Setup temporary directory for plugin files
      tmp_dir =
        Path.join([System.tmp_dir!(), "plugin_reloading_test_#{test_name}"])

      File.mkdir_p!(tmp_dir)
      plugin_base_name = "TestPluginV1"
      plugin_file_name = "#{plugin_base_name}.ex"
      plugin_path = Path.join(tmp_dir, plugin_file_name)

      # Initial plugin code (V1)
      plugin_v1_content = """
      defmodule #{plugin_base_name} do
        @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour

        def init(opts), do: {:ok, Map.put(opts, :version, 1)}
        def handle_output(output, state), do: "V1: \#{output} - \#{inspect(state)}"
        def terminate(_reason, _state), do: :ok
      end
      """

      File.write!(plugin_path, plugin_v1_content)
      assert [{module_atom, _binary}] = Code.compile_file(plugin_path)
      assert Atom.to_string(module_atom) == "Elixir.#{plugin_base_name}"

      # Configure initial mocks for LoaderBehaviour
      # These are global/shared mocks, their expectations are set once.
      initial_plugin_spec = %{
        id: "test_plugin",
        module: MockPluginBehaviour,
        path: plugin_path,
        config: %{some_setting: "initial"}
      }

      # Expectations for initial load
      Mox.expect(LoaderMock, :discover_plugins, fn _plugin_dirs ->
        {:ok, [initial_plugin_spec]}
      end)

      # --- Expectations for CONCRETE LifecycleHelper ---
      # Expect initial load via LifecycleHelper
      # Note: Arity is 8 (module, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config)
      # We need to return the expected state map structure after loading.
      Mox.expect(
        Raxol.Core.Runtime.Plugins.LifecycleHelper,
        :load_plugin_by_module,
        fn
          MockPluginBehaviour,
          _config,
          _plugins,
          _metadata,
          _plugin_states,
          _load_order,
          _cmd_table,
          _plugin_config ->
            # Simulate successful load, returning the structure Manager expects
            {:ok,
             %{
               plugins: %{"test_plugin" => MockPluginBehaviour},
               # Example metadata
               metadata: %{
                 "test_plugin" => %{id: "test_plugin", version: "1.0"}
               },
               # Corresponds to :init expectation
               plugin_states: %{"test_plugin" => %{mock_state: :v1}},
               load_order: ["test_plugin"],
               plugin_config: %{"test_plugin" => %{some_setting: "initial"}}
             }}
        end
      )

      # Start options for the Manager, using the mocks
      start_opts = [
        name: ManagerReloadingTest.PluginManager,
        plugin_dirs: [tmp_dir],
        # Use Mox mock for Loader
        loader_module: LoaderMock,
        command_registry_table: :raxol_command_registry,
        runtime_pid: self()
      ]

      # Start the Plugin Manager
      {:ok, manager_pid} = Manager.start_link(start_opts)
      # ADDED: Allow manager to initialize before proceeding
      Process.sleep(100)

      # Allow mocks for the dynamically loaded plugin (V1)
      # Since it's dynamically compiled, we stub_with its actual module name after compilation
      # Mox.stub_with(String.to_atom(plugin_base_name), MockPluginBehaviour)

      # Set expectations for the MockPluginBehaviour (Init is called by LifecycleHelper)
      Mox.expect(MockPluginBehaviour, :init, fn _config ->
        {:ok, %{mock_state: :v1}}
      end)

      # Verify initial plugin version (V1)
      # Example: Send an event or command that uses the plugin and check output
      # This part depends on how plugins are invoked; for simplicity, let's assume direct call or a test helper
      # For this test, let's assume Manager has a way to directly invoke a plugin's method for test purposes
      # Or, more realistically, an event would trigger plugin interaction.
      # For now, we are just checking if it loads.

      # Modify the plugin file (V2)
      plugin_v2_content = """
      defmodule #{plugin_base_name} do
        @behaviour Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour

        def init(opts), do: {:ok, Map.put(opts, :version, 2)} # Version updated
        def handle_output(output, state), do: "V2: \#{output} - \#{inspect(state)}" # Output changed, ESCAPED
        def terminate(_reason, _state), do: :ok
      end
      """

      File.write!(plugin_path, plugin_v2_content)

      # Trigger reload (e.g., via a GenServer call to the Manager)
      # The exact mechanism depends on Manager's API; using a placeholder
      # This might involve :sys.suspend, Code.compile_file, :sys.resume, plugin re-init, etc.
      # NEW: Use GenServer.cast
      GenServer.cast(manager_pid, {:reload_plugin_by_id, "test_plugin"})

      # Expectations for reload: LifecycleHelper might be involved again if plugins are re-initialized
      # Now expect reload_plugin_from_disk/8 on the CONCRETE mock
      # Args: plugin_id, plugins, metadata, plugin_states, load_order, command_table, plugin_config, plugin_paths
      Mox.expect(
        Raxol.Core.Runtime.Plugins.LifecycleHelper,
        :reload_plugin_from_disk,
        fn
          "test_plugin",
          _plugins,
          _metadata,
          _plugin_states,
          _load_order,
          _cmd_table,
          _plugin_config,
          _plugin_paths ->
            # Simulate successful reload, returning updated state maps
            {:ok,
             %{
               # Still the same mock module
               plugins: %{"test_plugin" => MockPluginBehaviour},
               # Example updated metadata
               metadata: %{
                 "test_plugin" => %{id: "test_plugin", version: "2.0"}
               },
               # Corresponds to :init V2 expectation
               plugin_states: %{"test_plugin" => %{mock_state: :v2}},
               # Assuming order doesn't change
               load_order: ["test_plugin"],
               # Assuming config doesn't change
               plugin_config: %{"test_plugin" => %{some_setting: "initial"}}
             }}
        end
      )

      # Allow mocks for the reloaded plugin (V2) - important to re-stub after reload
      # Mox.stub_with(String.to_atom(plugin_base_name), MockPluginBehaviour)

      # Set expectations for the MockPluginBehaviour after reload (Terminate then Init)
      Mox.expect(MockPluginBehaviour, :terminate, fn :reload, _state -> :ok end)

      Mox.expect(MockPluginBehaviour, :init, fn _config ->
        {:ok, %{mock_state: :v2}}
      end)

      # Verify reloaded plugin version (V2)
      # Again, this depends on how to interact with the plugin.
      # We'd expect handle_output to now return "V2: ..."

      # Cleanup: stop manager, remove temp directory
      Process.exit(manager_pid, :shutdown)
      File.rm_rf!(tmp_dir)
      # Verify all expectations
      Mox.verify_on_exit!()
    end
  end
end
