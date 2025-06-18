if Mix.env() == :test do
  defmodule Raxol.Test.FileWatcherTestHelper do
    @moduledoc '''
    Helper functions for testing file watcher functionality.
    '''

    import Raxol.Test.Support.TestHelper

    @doc '''
    Creates a valid file stat for testing.
    '''
    def valid_file_stat do
      {:ok,
       %File.Stat{
         size: 0,
         type: :regular,
         access: :read,
         atime: {{2024, 1, 1}, {0, 0, 0}},
         mtime: {{2024, 1, 1}, {0, 0, 0}},
         ctime: {{2024, 1, 1}, {0, 0, 0}},
         mode: 0o644,
         links: 1,
         major_device: 0,
         minor_device: 0,
         inode: 0,
         uid: 0,
         gid: 0
       }}
    end

    @doc '''
    Creates a directory stat for testing.
    '''
    def directory_stat do
      {:ok,
       %File.Stat{
         size: 0,
         type: :directory,
         access: :read,
         atime: {{2024, 1, 1}, {0, 0, 0}},
         mtime: {{2024, 1, 1}, {0, 0, 0}},
         ctime: {{2024, 1, 1}, {0, 0, 0}},
         mode: 0o755,
         links: 1,
         major_device: 0,
         minor_device: 0,
         inode: 0,
         uid: 0,
         gid: 0
       }}
    end

    @doc '''
    Creates a test state with default values.
    '''
    def create_test_state(opts \\ %{}) do
      base = %{
        plugin_dirs: ["test/plugins"],
        plugins_dir: "priv/plugins",
        initialized: false,
        command_registry_table: nil,
        loader_module:
          opts[:loader_module] || Raxol.Core.Runtime.Plugins.Loader,
        lifecycle_helper_module:
          opts[:lifecycle_helper_module] ||
            Raxol.Core.Runtime.Plugins.FileWatcher,
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        plugin_paths: %{},
        reverse_plugin_paths: %{},
        load_order: [],
        file_watching_enabled?: false,
        file_watcher_pid: nil,
        file_event_timer: nil
      }

      base
      |> Map.put_new(:style, %{})
      |> Map.put_new(:disabled, false)
      |> Map.put_new(:focused, false)
    end

    @doc '''
    Starts the Manager process for testing.
    '''
    def start_manager do
      {:ok, pid} =
        Raxol.Core.Runtime.Plugins.Manager.start_link(runtime_pid: self())

      pid
    end

    @doc '''
    Stops the Manager process.
    '''
    def stop_manager(pid) do
      Process.exit(pid, :normal)
    end

    @doc '''
    Sets up common mocks and processes for file watcher tests.
    '''
    def setup_mocks do
      # Set up test environment and mocks
      {:ok, _} = setup_test_env()
      setup_common_mocks()

      # Start Manager process
      pid = start_manager()
      pid
    end

    @doc '''
    Creates a test plugin file in the test plugins directory.
    '''
    def create_test_plugin(name, content \\ nil) do
      plugin_dir = "test/plugins"
      File.mkdir_p!(plugin_dir)
      plugin_path = Path.join(plugin_dir, "#{name}.ex")
      content = content || default_plugin_content(name)
      File.write!(plugin_path, content)
      plugin_path
    end

    @doc '''
    Cleans up test plugin files.
    '''
    def cleanup_test_plugins do
      plugin_dir = "test/plugins"

      if File.exists?(plugin_dir) do
        File.rm_rf!(plugin_dir)
      end
    end

    @doc '''
    Provides default plugin content for testing.
    '''
    def default_plugin_content(name) do
      '''
      defmodule Raxol.Test.Plugins.#{name} do
        @behaviour Raxol.Core.Runtime.Plugins.Plugin.Behaviour

        def init(config) do
          {:ok, Map.put(config, :initialized, true)}
        end

        def handle_event(_event, state) do
          {:ok, state}
        end

        def handle_command(_command, _args, state) do
          {:ok, state}
        end

        def get_commands do
          []
        end

        def get_metadata do
          %{
            name: "#{name}",
            version: "1.0.0",
            description: "Test plugin #{name}",
            author: "Test Author",
            dependencies: []
          }
        end
      end
      '''
    end
  end
end
