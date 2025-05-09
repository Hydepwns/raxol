defmodule Raxol.Test.PluginTestFixtures do
  @moduledoc """
  Container for common plugin modules used in testing the PluginManager and related systems.
  """

  # Test plugin module that implements the required behaviours
  defmodule TestPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(opts) do
      {:ok,
       %{
         name: "test_plugin",
         enabled: true,
         version: "1.0.0",
         options: opts,
         event_count: 0,
         crash_on: nil
       }}
    end

    def terminate(_reason, state) do
      # Return state to verify it was called with the correct state
      state
    end

    def get_commands do
      [
        {:test_cmd, :handle_test_cmd, 1},
        {:crash_cmd, :handle_crash_cmd, 0}
      ]
    end

    def handle_test_cmd(arg, state) do
      new_state = Map.put(state, :last_arg, arg)
      {:ok, new_state, {:result, arg}}
    end

    def handle_crash_cmd(_state) do
      raise "Intentional crash in TestPlugin.handle_crash_cmd"
    end

    def handle_input(input, state) do
      if state.crash_on == :input do
        raise "Intentional crash in handle_input"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_input: input
        }

        {:ok, new_state}
      end
    end

    def handle_output(output, state) do
      if state.crash_on == :output do
        raise "Intentional crash in handle_output"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_output: output
        }

        {:ok, new_state, "Modified: #{output}"}
      end
    end

    def handle_mouse(event, state) do
      if state.crash_on == :mouse do
        raise "Intentional crash in handle_mouse"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_mouse: event
        }

        {:ok, new_state}
      end
    end

    def handle_placeholder(tag, content, options, state) do
      if state.crash_on == :placeholder do
        raise "Intentional crash in handle_placeholder"
      else
        new_state = %{
          state
          | event_count: state.event_count + 1,
            last_placeholder: {tag, content, options}
        }

        {:ok, new_state, "Rendered: #{tag} - #{content}"}
      end
    end
  end

  # Broken plugin that fails to implement required functions
  defmodule BrokenPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: [{:broken_cmd, :handle_broken_cmd, 1}]

    # Missing implementation of handle_broken_cmd/2
  end

  # Plugin with bad return values
  defmodule BadReturnPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: [{:bad_return_cmd, :handle_bad_return_cmd, 1}]

    def handle_bad_return_cmd(_arg, _state) do
      # Return wrong format
      :unexpected_return
    end

    def handle_input(_input, _state) do
      # Wrong return format
      :not_ok
    end

    def handle_output(_output, _state) do
      # Wrong return format
      [:not, :a, :tuple]
    end
  end

  # Plugin with invalid dependencies
  defmodule DependentPlugin do
    @behaviour Raxol.Core.Runtime.Plugins.Plugin
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    def init(_opts), do: {:ok, %{}}
    def terminate(_reason, state), do: state
    def get_commands, do: []

    def id, do: :dependent_plugin
    def version, do: "1.0.0"
    def dependencies, do: [{:missing_plugin, ">= 1.0.0"}]

    # The PluginMetadataProvider behaviour recommends a `metadata/0` function
    # that returns a map.
    def metadata do
      %{
        id: id(),
        version: version(),
        dependencies: dependencies()
      }
    end
  end
end
