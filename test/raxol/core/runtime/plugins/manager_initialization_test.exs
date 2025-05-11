# Now define the test module
defmodule Raxol.Core.Runtime.Plugins.ManagerInitializationTest do
  use ExUnit.Case
  # Ensure Mox macros are available
  require Mox
  # Explicitly import defmock
  import Mox
  import Raxol.TestHelpers

  # --- Aliases & Mox Setup ---
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.{LifecycleHelper, Loader}

  # Mocks defined inside the test module, using behaviours from support file
  # Updated namespace
  defmock(MockPluginBehaviourMock, for: Raxol.TestSupport.MockPluginBehaviour)
  # Updated namespace
  defmock(MockPluginMetadataProviderMock,
    for: Raxol.TestSupport.MockPluginMetadataProvider
  )

  # --- Setup & Teardown ---
  # Common setup for initialization tests
  setup %{test: test_name} do
    # Added for Mox verification
    Mox.verify_on_exit!()

    # Create a temporary directory for test plugins
    {:ok, tmp_dir} = Briefly.create(type: :directory)

    on_exit(fn ->
      # Use the documented cleanup function
      Briefly.cleanup()
    end)

    # Setup mocks (expectations will be set in individual tests)
    # Mox.stub_with(LifecycleHelperMock, Raxol.Core.Runtime.Plugins.LifecycleHelper) <-- Removed

    # Base start options, individual tests can override
    start_opts = [
      name: :"#{test_name}_PluginManagerInit",
      # Use the temporary directory
      plugin_dirs: [tmp_dir],
      # Use the real (mecked) Loader
      loader_module: Loader,
      # Use the real (mecked) LifecycleHelper
      lifecycle_helper_module: LifecycleHelper
      # command_registry_table, command_helper_module not needed for pure init tests
    ]

    {:ok, tmp_dir: tmp_dir, base_opts: start_opts}
  end

  # Helper to create a simple plugin file
  defp create_plugin_file(
         dir,
         module_name,
         version \\ "1.0",
         dependencies \\ []
       ) do
    plugin_code = """
    defmodule #{module_name} do
      # Use behaviours from support file
      @behaviour Raxol.TestSupport.MockPluginBehaviour # Updated namespace
      @behaviour Raxol.TestSupport.MockPluginMetadataProvider # Updated namespace

      def id, do: :"#{Atom.to_string(module_name)}"
      def version, do: \"#{version}\"
      def init(_opts), do: {:ok, %{started: true, id: :"#{Atom.to_string(module_name)}\"}}
      def terminate(_reason, _state), do: :ok
      def get_commands, do: []

      def metadata, do: %{id: :"#{Atom.to_string(module_name)}\", version: \"#{version}\", dependencies: #{inspect(dependencies)}}
    end
    """

    file_path = Path.join(dir, "#{module_name}.exs")
    File.write!(file_path, plugin_code)
    # Compile the file immediately so meck can find the module
    {:ok, _module, _binary} = Code.compile_file(file_path)
    file_path
  end

  # --- Initialization Test Cases ---
  describe "Plugin Initialization and Dependencies" do
    # Test case copied from original manager_test.exs
    test "start_link initializes Manager state and discovers plugins", %{
      tmp_dir: dir,
      base_opts: opts
    } do
      # Arrange: Create a dummy plugin file
      plugin_module = :MyTestPlugin1
      plugin_path = create_plugin_file(dir, plugin_module)

      # Arrange: Expect Loader to discover the plugin using Mox
      Mox.expect(Loader, :discover_plugins, fn [^dir] ->
        [%{module: plugin_module, path: plugin_path}]
      end)

      # Arrange: Expect Loader to load the plugin module metadata using Mox
      Mox.expect(Loader, :load_plugin_metadata, fn ^plugin_module ->
        {:ok, MyTestPlugin1}
      end)

      # Arrange: Expect Loader to compile and load the actual plugin module using Mox
      Mox.expect(Loader, :load_plugin_module, fn ^plugin_module ->
        {:ok, MyTestPlugin1}
      end)

      # Arrange: Expect LifecycleHelper to initialize the plugin using Mox
      Mox.expect(LifecycleHelper, :init_plugin, fn MyTestPlugin1, _opts ->
        {:ok, %{started: true, id: :my_test_plugin1}}
      end)

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)
      on_exit(fn -> cleanup_process(pid) end)

      # Assert: Check internal state (assuming API exists or using :sys.get_state)
      # Assuming this API exists
      plugins = GenServer.call(pid, :get_plugins)
      assert Map.has_key?(plugins, :my_test_plugin1)

      # Assuming this API exists
      plugin_states = GenServer.call(pid, :get_plugin_states)

      assert Map.get(plugin_states, :my_test_plugin1) == %{
               started: true,
               id: :my_test_plugin1
             }

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
    end

    test "start_link handles plugins with unmet dependencies", %{
      tmp_dir: dir,
      base_opts: opts
    } do
      # Arrange: Create two plugins, one depending on the other (which is missing)
      plugin_a = :PluginA
      plugin_b = :PluginB

      path_a =
        create_plugin_file(dir, plugin_a, "1.0", [{:missing_dep, ">= 1.0"}])

      path_b = create_plugin_file(dir, plugin_b)

      # Arrange: Expect Loader to discover both using Mox
      Mox.expect(Loader, :discover_plugins, fn [^dir] ->
        [
          %{module: plugin_a, path: path_a},
          %{module: plugin_b, path: path_b}
        ]
      end)

      # Arrange: Expect Loader to load metadata for both using Mox
      Mox.expect(Loader, :load_plugin_metadata, fn
        :PluginA -> {:ok, PluginA}
        :PluginB -> {:ok, PluginB}
      end)

      # Arrange: Expect Loader to load PluginB module only (as PluginA has unmet dep) using Mox
      Mox.expect(Loader, :load_plugin_module, fn :PluginB -> {:ok, PluginB} end)
      # No expectation for PluginA to be loaded by load_plugin_module

      # Arrange: Expect LifecycleHelper to init PluginB only using Mox
      Mox.expect(LifecycleHelper, :init_plugin, fn PluginB, _opts ->
        {:ok, %{started: true, id: :plugin_b}}
      end)

      # No expectation for PluginA to be initialized

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)
      on_exit(fn -> cleanup_process(pid) end)

      # Assert: Check that only PluginB is loaded and initialized
      plugins = GenServer.call(pid, :get_plugins)
      assert Map.has_key?(plugins, :plugin_b)
      refute Map.has_key?(plugins, :plugin_a)

      plugin_states = GenServer.call(pid, :get_plugin_states)

      assert Map.get(plugin_states, :plugin_b) == %{
               started: true,
               id: :plugin_b
             }

      refute Map.has_key?(plugin_states, :plugin_a)

      # LifecycleHelper is mocked with Mox via LifecycleHelperMock, no meck validation needed

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
    end

    test "start_link handles plugins with circular dependencies", %{
      tmp_dir: dir,
      base_opts: opts
    } do
      # Arrange: Create two plugins that depend on each other
      plugin_c = :PluginC
      plugin_d = :PluginD
      path_c = create_plugin_file(dir, plugin_c, "1.0", [{:plugin_d, ">= 1.0"}])
      path_d = create_plugin_file(dir, plugin_d, "1.0", [{:plugin_c, ">= 1.0"}])

      # Arrange: Expect Loader to discover both using Mox
      Mox.expect(Loader, :discover_plugins, fn [^dir] ->
        [
          %{module: plugin_c, path: path_c},
          %{module: plugin_d, path: path_d}
        ]
      end)

      # Arrange: Expect Loader to load metadata for both using Mox
      Mox.expect(Loader, :load_plugin_metadata, fn
        :PluginC -> {:ok, PluginC}
        :PluginD -> {:ok, PluginD}
      end)

      # Arrange: Expect Loader to load both modules using Mox
      Mox.expect(Loader, :load_plugin_module, fn
        :PluginC -> {:ok, PluginC}
        :PluginD -> {:ok, PluginD}
      end)

      # Arrange: Expect LifecycleHelper to init both using Mox
      Mox.expect(LifecycleHelper, :init_plugin, fn
        PluginC, _opts -> {:ok, %{started: true, id: :plugin_c}}
        PluginD, _opts -> {:ok, %{started: true, id: :plugin_d}}
      end)

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)
      on_exit(fn -> cleanup_process(pid) end)

      # Assert: Check that both plugins are loaded and initialized
      plugins = GenServer.call(pid, :get_plugins)
      assert Map.has_key?(plugins, :plugin_c)
      assert Map.has_key?(plugins, :plugin_d)

      plugin_states = GenServer.call(pid, :get_plugin_states)
      assert Map.get(plugin_states, :plugin_c) == %{
               started: true,
               id: :plugin_c
             }
      assert Map.get(plugin_states, :plugin_d) == %{
               started: true,
               id: :plugin_d
             }
    end
  end

  # describe
end

# module
