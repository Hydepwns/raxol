# Define mock behaviours outside the test module
defmodule Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour do
  @callback id() :: String.t()
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
  use ExUnit.Case
  require Mox
  # Import Mox functions like expect, stub, verify_on_exit!, set_mox_global
  import Mox
  # use Mox # COMMENTED OUT AGAIN - Causes Mox.__using__/1 undefined
  # Instead of 'use Mox', we will use fully qualified names like Mox.defmock, Mox.stub, etc. if not importing

  # Defmocks for behaviours (now using the outer definitions)
  Mox.defmock(MockPluginBehaviourMock,
    for: Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginBehaviour
  )

  Mox.defmock(MockPluginMetadataProviderMock,
    for:
      Raxol.Core.Runtime.Plugins.ManagerReloadingTest.MockPluginMetadataProvider
  )

  # Mox mock for LoaderBehaviour
  Mox.defmock(LoaderMock, for: Raxol.Core.Runtime.Plugins.Loader.Behaviour)

  Mox.defmock(ReloadingLifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  # --- Aliases & Meck Setup ---
  alias Raxol.Core.Runtime.Plugins.Manager

  # Aliases should now correctly point to the outer (and only) definitions
  alias Raxol.Core.Runtime.Plugins.ManagerReloadingTest.{
    MockPluginBehaviour,
    MockPluginMetadataProvider
  }

  # Ensure core plugins are compiled when this test module is compiled
  Code.ensure_compiled!(Raxol.Core.Plugins.Core.ClipboardPlugin)
  Code.ensure_compiled!(Raxol.Core.Plugins.Core.NotificationPlugin)
  # Ensure clipboard impl is also compiled
  Code.ensure_compiled!(Raxol.System.Clipboard)

  # We are not using meck in this test, relying purely on Mox for the reloaded module.

  # --- Helper functions to generate plugin code ---
  defp generate_plugin_code(module_name_atom, version) do
    plugin_id_string =
      module_name_atom
      |> Atom.to_string()
      # Ensure clean name
      |> String.replace_prefix("Elixir.", "")
      |> String.replace_suffix("V#{version}", "")
      |> String.downcase()

    """
    defmodule #{Atom.to_string(module_name_atom)} do
      @behaviour Raxol.Core.Runtime.Plugins.Plugin

      def id, do: "#{plugin_id_string}" # e.g., "test_plugin"
      def version, do: "#{version}.0.0"
      def get_commands, do: []
      def init(_opts), do: {:ok, %{init_version: #{version}, id: :"#{plugin_id_string}" }}
      def terminate(_reason, state), do: {:ok, state}
      def enable(state), do: {:ok, state}
      def disable(state), do: {:ok, state}
      # Optional callbacks not implemented for this test plugin:
      # def filter_event(event, state), do: {:ok, event, state}
      # def handle_command(command, args, state), do: {:ok, :ack, state}
    end
    """
  end

  defp create_plugin_files(tmp_dir, module_atom, version) do
    plugin_content = generate_plugin_code(module_atom, version)
    # Use the plain module atom for the file name, e.g., TestPluginV1.ex
    file_name = "#{Atom.to_string(module_atom)}.ex"
    plugin_path = Path.join(tmp_dir, file_name)
    File.write!(plugin_path, plugin_content)
    # Compile and get the actual module atom (e.g., Elixir.TestPluginV1)
    # The test will refer to the plugin by its simple name, e.g. TestPluginV1, but compilation yields Elixir.TestPluginV1
    case Code.compile_file(plugin_path) do
      [{compiled_module_atom, _binary}] -> {plugin_path, compiled_module_atom}
      other -> raise "Failed to compile #{plugin_path}: #{inspect(other)}"
    end
  end

  # --- Setup & Teardown ---
  # Ensure mocks are globally visible for this non-async test case
  setup :set_mox_global

  # setup :verify_on_exit! # REMOVING THIS to see if it resolves the final shutdown error

  # Common setup for reloading tests
  # This setup block should be minimal, focused on what's truly common if multiple tests existed.
  # For a single test, most of this can be in the test block itself.
  setup %{test: test_name} do
    # Create a unique table name for each test to avoid ETS conflicts
    table_name = String.to_atom("#{test_name}_ReloadingReg")
    :ets.new(table_name, [:set, :protected, :named_table])

    {:ok, tmp_dir_path} = Briefly.create(directory: true)
    # Briefly.create(directory: true) already creates the directory.
    # File.mkdir_p!(tmp_dir_path)

    # Base options for starting the manager
    base_opts = [
      plugin_dirs: [tmp_dir_path],
      loader_module: LoaderMock,
      lifecycle_helper_module: ReloadingLifecycleHelperMock,
      command_registry_table: table_name,
      runtime_pid: self(),
      plugin_config: %{
        Raxol.Core.Plugins.Core.ClipboardPlugin => %{
          clipboard_impl: Raxol.System.Clipboard
        }
      }
    ]

    # Return tmp_dir_path as tmp_dir for the test context
    {:ok,
     tmp_dir: tmp_dir_path,
     base_opts: base_opts,
     test_name: test_name,
     table: table_name}
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
    test "Plugin Reloading reloads a modified plugin file", %{
      tmp_dir: tmp_dir,
      base_opts: original_start_opts,
      test: test_name,
      table: table_name
    } do
      IO.inspect(tmp_dir, label: "Test tmp_dir")

      # Modify start_opts for this test: ensure LoaderMock and ReloadingLifecycleHelperMock are used
      start_opts = original_start_opts
      # |> Keyword.delete(:loader_module) # Ensure this is NOT deleted
      IO.inspect(start_opts, label: "Test start_opts (modified)")

      # Compile the V1 plugin code and get its path and module atom
      {plugin_v1_path, module_atom} =
        create_plugin_files(tmp_dir, TestPluginV1, 1)

      # Define the spec that LoaderMock will return for V1
      initial_plugin_spec = %{
        # Use atom ID consistent with expectations
        id: :test_plugin_v1,
        module: module_atom,
        # Config specific to this discovered plugin
        config: %{some_setting: "initial"},
        path: plugin_v1_path
      }

      # Expectations for initial load (LoaderMock)
      Mox.expect(LoaderMock, :discover_plugins, fn [^tmp_dir] ->
        {:ok, [initial_plugin_spec]}
      end)

      # --- Expectations for ReloadingLifecycleHelperMock ---
      # Expectation for load_plugin_by_module
      Mox.expect(
        ReloadingLifecycleHelperMock,
        :load_plugin_by_module,
        3,
        fn module_atom_arg,
           config_arg,
           plugins_acc,
           meta_acc,
           states_acc,
           order_acc,
           _cmd_reg,
           _global_config ->
          plugin_id_atom =
            case module_atom_arg do
              # Match the compiled module name
              ^module_atom -> :test_plugin_v1
              _ -> raise "Unexpected module: #{inspect(module_atom_arg)}"
            end

          # Return updated accumulators
          {
            :ok,
            [plugin_id_atom | plugins_acc],
            [%{id: plugin_id_atom, module: module_atom_arg} | meta_acc],
            [%{id: plugin_id_atom, state: %{version: 1}} | states_acc],
            [plugin_id_atom | order_acc]
          }
        end
      )

      # Start the manager with the mocked loader
      {:ok, manager_pid} = Manager.start_link(start_opts)

      # Wait for the manager to be ready
      assert_receive {:manager_ready, ^manager_pid}, 5000

      # Verify initial state
      assert Manager.get_plugin_state(:test_plugin_v1).version == 1

      # Create V2 plugin
      {_plugin_v2_path, _module_atom} = create_plugin_v2(tmp_dir)

      # Expect the reload
      Mox.expect(
        ReloadingLifecycleHelperMock,
        :load_plugin_by_module,
        3,
        fn module_atom_arg,
           config_arg,
           plugins_acc,
           meta_acc,
           states_acc,
           order_acc,
           _cmd_reg,
           _global_config ->
          plugin_id_atom =
            case module_atom_arg do
              ^module_atom -> :test_plugin_v1
              _ -> raise "Unexpected module: #{inspect(module_atom_arg)}"
            end

          # Return updated accumulators
          {
            :ok,
            [plugin_id_atom | plugins_acc],
            [%{id: plugin_id_atom, module: module_atom_arg} | meta_acc],
            [%{id: plugin_id_atom, state: %{version: 2}} | states_acc],
            [plugin_id_atom | order_acc]
          }
        end
      )

      # Trigger reload
      assert :ok == Manager.reload_plugin(:test_plugin_v1)

      # Wait for reload to complete
      assert_receive {:plugin_reloaded, :test_plugin_v1}, 5000

      # Verify new state
      assert Manager.get_plugin_state(:test_plugin_v1).version == 2

      # Cleanup
      GenServer.stop(manager_pid)
    end
  end
end
