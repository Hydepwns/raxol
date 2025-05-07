defmodule Raxol.Core.Runtime.Plugins.ManagerInitializationTest do
  use ExUnit.Case, async: true
  # use Properties.Case # If needed
  # No Mox import needed if only using meck

  # --- Aliases & Meck Setup ---
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Core.Runtime.Plugins.{LifecycleHelper, Loader}

  # Using meck for Loader and LifecycleHelper as they are not behaviours
  # defmock LifecycleHelperMock, for: Raxol.Core.Runtime.Plugins.LifecycleHelper <-- Removed

  # Mock Plugin Behaviours (copied from original test)
  # These CAN use Mox as we define the behaviours here
  import Mox
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
  alias Raxol.Core.Runtime.Plugins.ManagerInitializationTest.MockPluginBehaviour
  alias Raxol.Core.Runtime.Plugins.ManagerInitializationTest.MockPluginMetadataProvider

  # --- Setup & Teardown ---
  # Common setup for initialization tests
  setup %{test: test_name} do
    # Mox.verify_on_exit!(self) # Only needed if Mox mocks are used in tests

    # Setup meck for Loader and LifecycleHelper
    :meck.new(Loader, [:passthrough])
    :meck.new(LifecycleHelper, [:passthrough])
    # Ensure mecks are unloaded on exit
    on_exit(fn -> :meck.unload([Loader, LifecycleHelper]) end)

    # Create a temporary directory for test plugins
    {:ok, tmp_dir} = Briefly.create(directory: true)
    # Clean up the temporary directory on exit
    on_exit(fn -> Briefly.remove!(tmp_dir) end)

    # Setup mocks (expectations will be set in individual tests)
    # Mox.stub_with(LifecycleHelperMock, Raxol.Core.Runtime.Plugins.LifecycleHelper) <-- Removed

    # Base start options, individual tests can override
    start_opts = [
      name: :"#{test_name}_PluginManagerInit",
      plugin_dirs: [tmp_dir], # Use the temporary directory
      loader_module: Loader, # Use the real (mecked) Loader
      lifecycle_helper_module: LifecycleHelper # Use the real (mecked) LifecycleHelper
      # command_registry_table, command_helper_module not needed for pure init tests
    ]

    {:ok, tmp_dir: tmp_dir, base_opts: start_opts}
  end

  # Helper to create a simple plugin file
  defp create_plugin_file(dir, module_name, version \\ "1.0", dependencies \\ []) do
    plugin_code = """
    defmodule #{module_name} do
      # Note: These behaviours are defined within this test module
      @behaviour Raxol.Core.Runtime.Plugins.ManagerInitializationTest.MockPluginBehaviour
      @behaviour Raxol.Core.Runtime.Plugins.ManagerInitializationTest.MockPluginMetadataProvider

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
    test "start_link initializes Manager state and discovers plugins", %{tmp_dir: dir, base_opts: opts} do
      # Arrange: Create a dummy plugin file
      plugin_module = :MyTestPlugin1
      plugin_path = create_plugin_file(dir, plugin_module)

      # Arrange: Expect Loader (mecked) to discover the plugin
      :meck.expect(Loader, :discover_plugins, fn [^dir] ->
        [%{module: plugin_module, path: plugin_path}]
      end)

      # Arrange: Expect Loader (mecked) to load the plugin module metadata
      :meck.expect(Loader, :load_plugin_metadata, fn ^plugin_module ->
         {:ok, MyTestPlugin1}
      end)

      # Arrange: Expect Loader (mecked) to compile and load the actual plugin module
      :meck.expect(Loader, :load_plugin_module, fn ^plugin_module ->
         {:ok, MyTestPlugin1}
      end)

      # Arrange: Expect LifecycleHelper (mecked) to initialize the plugin
      :meck.expect(LifecycleHelper, :init_plugin, fn MyTestPlugin1, _opts ->
        {:ok, %{started: true, id: :my_test_plugin1}}
      end)

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)

      # Assert: Check internal state (assuming API exists or using :sys.get_state)
      plugins = GenServer.call(pid, :get_plugins) # Assuming this API exists
      assert Map.has_key?(plugins, :my_test_plugin1)

      plugin_states = GenServer.call(pid, :get_plugin_states) # Assuming this API exists
      assert Map.get(plugin_states, :my_test_plugin1) == %{started: true, id: :my_test_plugin1}

      # Assert: Ensure mecks were called
      :meck.verify(Loader)
      :meck.verify(LifecycleHelper)
      # Mox.verify!(LifecycleHelperMock) <-- Removed

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
      :meck.unload([Loader, LifecycleHelper])
    end

    test "start_link handles plugins with unmet dependencies", %{tmp_dir: dir, base_opts: opts} do
      # Arrange: Create two plugins, one depending on the other (which is missing)
      plugin_a = :PluginA
      plugin_b = :PluginB
      path_a = create_plugin_file(dir, plugin_a, "1.0", [{:missing_dep, ">= 1.0"}])
      path_b = create_plugin_file(dir, plugin_b)

      # Arrange: Expect Loader to discover both
      :meck.expect(Loader, :discover_plugins, fn [^dir] ->
        [
          %{module: plugin_a, path: path_a},
          %{module: plugin_b, path: path_b}
        ]
      end)

      # Arrange: Expect Loader to load metadata for both
      :meck.expect(Loader, :load_plugin_metadata, fn :PluginA -> {:ok, PluginA} end)
      :meck.expect(Loader, :load_plugin_metadata, fn :PluginB -> {:ok, PluginB} end)

      # Arrange: Expect Loader to load PluginB module only (as PluginA has unmet dep)
      :meck.expect(Loader, :load_plugin_module, fn :PluginB -> {:ok, PluginB} end)

      # Arrange: Expect LifecycleHelper to init PluginB only
      :meck.expect(LifecycleHelper, :init_plugin, fn PluginB, _opts ->
        {:ok, %{started: true, id: :plugin_b}}
      end)

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)

      # Assert: Check that only PluginB is loaded and initialized
      plugins = GenServer.call(pid, :get_plugins)
      assert Map.has_key?(plugins, :plugin_b)
      refute Map.has_key?(plugins, :plugin_a)

      plugin_states = GenServer.call(pid, :get_plugin_states)
      assert Map.get(plugin_states, :plugin_b) == %{started: true, id: :plugin_b}
      refute Map.has_key?(plugin_states, :plugin_a)

      # Assert: Verify mocks
      :meck.verify(Loader)
      :meck.verify(LifecycleHelper)
      # Mox.verify!(LifecycleHelperMock) <-- Removed

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
      :meck.unload([Loader, LifecycleHelper])
    end

    test "start_link handles plugins with circular dependencies", %{tmp_dir: dir, base_opts: opts} do
      # Arrange: Create two plugins that depend on each other
      plugin_c = :PluginC
      plugin_d = :PluginD
      path_c = create_plugin_file(dir, plugin_c, "1.0", [{:plugin_d, ">= 1.0"}])
      path_d = create_plugin_file(dir, plugin_d, "1.0", [{:plugin_c, ">= 1.0"}])

      # Arrange: Expect Loader to discover both
      :meck.expect(Loader, :discover_plugins, fn [^dir] ->
        [
          %{module: plugin_c, path: path_c},
          %{module: plugin_d, path: path_d}
        ]
      end)

      # Arrange: Expect Loader to load metadata for both
      :meck.expect(Loader, :load_plugin_metadata, fn :PluginC -> {:ok, PluginC} end)
      :meck.expect(Loader, :load_plugin_metadata, fn :PluginD -> {:ok, PluginD} end)

      # Arrange: Neither plugin should be loaded or initialized due to circular dep
      # No more calls expected to Loader.load_plugin_module or LifecycleHelper.init_plugin

      # Act: Start the Manager
      {:ok, pid} = Manager.start_link(opts)

      # Assert: Check that neither plugin is loaded
      plugins = GenServer.call(pid, :get_plugins)
      assert plugins == %{}

      plugin_states = GenServer.call(pid, :get_plugin_states)
      assert plugin_states == %{}

      # Assert: Verify mocks (ensure only discovery and metadata were called)
      :meck.verify(Loader)
      :meck.verify(LifecycleHelper)
      # Mox.verify!(LifecycleHelperMock) <-- Removed

      # Cleanup
      if Process.alive?(pid), do: Supervisor.stop(pid, :shutdown, :infinity)
      :meck.unload([Loader, LifecycleHelper])
    end

    # Add more tests for different dependency scenarios, versions, errors during init etc.

  end # describe
end # module
