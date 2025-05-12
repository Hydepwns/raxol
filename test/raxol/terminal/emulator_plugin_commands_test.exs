defmodule Raxol.Terminal.EmulatorPluginCommandsTest do
  use ExUnit.Case
  import Raxol.Test.EventAssertions

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Terminal.Emulator
  alias Raxol.Test.MockPlugins.MockCommandPlugin

  setup context do
    reloading_enabled = Keyword.has_key?(context.tags, :enable_plugin_reloading)
    {:ok, _pid} = Manager.start_link(
      command_registry_table: :test_command_registry,
      plugin_config: %{},
      enable_plugin_reloading: reloading_enabled
    )
    :ok = Manager.initialize()
    emulator = Emulator.new(80, 24)
    on_exit(fn -> :ets.delete(:test_command_registry) end)
    {:ok, %{emulator: emulator}}
  end

  describe "plugin commands" do
    # ... existing code ...
  end

  # Helper function for command handler test
  defp test_command_handler(_plugin_id, _command, _params) do
    {:ok, %{result: "success"}}
  end

  # Helper for command validation test
  defp validating_command_handler(_plugin_id, _command, %{valid: true} = params) do
    {:ok, %{status: "valid params", received: params}}
  end
  defp validating_command_handler(_plugin_id, _command, _invalid_params) do
    {:error, :invalid_parameters}
  end
end
