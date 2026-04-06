defmodule Mix.Tasks.Raxol.Gen.Plugin do
  @shortdoc "Generates a skeleton Raxol plugin module and test"

  @moduledoc """
  Generates a skeleton Raxol plugin.

      $ mix raxol.gen.plugin MyPlugin
      $ mix raxol.gen.plugin MyApp.Plugins.Logger

  Creates:

    * `lib/<path>.ex` - Plugin module with `use Raxol.Plugin` and `init/1`
    * `test/<path>_test.exs` - ExUnit test with lifecycle smoke test
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      [module_name | _] ->
        generate(module_name)

      [] ->
        Mix.shell().error("Usage: mix raxol.gen.plugin ModuleName")
    end
  end

  defp generate(module_name) do
    module_parts = String.split(module_name, ".")
    file_path = module_parts |> Enum.map(&Macro.underscore/1) |> Path.join()

    lib_path = Path.join("lib", "#{file_path}.ex")
    test_path = Path.join("test", "#{file_path}_test.exs")

    create_file(lib_path, plugin_template(module_name))
    create_file(test_path, test_template(module_name))

    Mix.shell().info("""

    Plugin generated. Next steps:

      1. Implement init/1 in #{lib_path}
      2. Override callbacks as needed (filter_event/2, handle_command/3, etc.)
      3. Run tests: mix test #{test_path}
    """)
  end

  defp create_file(path, content) do
    dir = Path.dirname(path)

    unless File.dir?(dir) do
      File.mkdir_p!(dir)
    end

    if File.exists?(path) do
      Mix.shell().error("* skipping #{path} (already exists)")
    else
      File.write!(path, content)
      Mix.shell().info("* creating #{path}")
    end
  end

  defp plugin_template(module_name) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      TODO: Describe what this plugin does.
      \"\"\"

      use Raxol.Plugin

      @impl true
      def init(config) do
        {:ok, %{config: config}}
      end

      # Override callbacks as needed:
      #
      # @impl true
      # def filter_event(event, state) do
      #   {:ok, event}
      # end
      #
      # @impl true
      # def handle_command(command, args, state) do
      #   {:ok, state, :ok}
      # end
      #
      # @impl true
      # def get_commands do
      #   [{:my_command, :handle_my_command, 1}]
      # end
      #
      # @impl true
      # def terminate(reason, state) do
      #   :ok
      # end
    end
    """
  end

  defp test_template(module_name) do
    """
    defmodule #{module_name}Test do
      use ExUnit.Case, async: true

      import Raxol.Plugin.Testing

      describe "lifecycle" do
        test "init/1 returns ok" do
          {:ok, state} = setup_plugin(#{module_name}, %{})
          assert is_map(state)
        end

        test "full lifecycle" do
          steps = simulate_lifecycle(#{module_name}, %{})
          assert length(steps) == 4
        end
      end

      describe "events" do
        test "passes events through by default" do
          {:ok, state} = setup_plugin(#{module_name}, %{})
          event = assert_handles_event(#{module_name}, :test_event, state)
          assert event == :test_event
        end
      end
    end
    """
  end
end
