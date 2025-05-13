defmodule Raxol.Terminal.EmulatorPluginMetadataTest do
  use ExUnit.Case
  import Raxol.Test.EventAssertions

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Plugins.HyperlinkPlugin
  alias Raxol.Terminal.Emulator
  alias Raxol.Test.MockPlugins.MockEventConsumingPlugin

  setup context do
    reloading_enabled = Keyword.has_key?(context.tags, :enable_plugin_reloading)

    {:ok, _pid} =
      Manager.start_link(
        command_registry_table: :test_command_registry,
        plugin_config: %{},
        enable_plugin_reloading: reloading_enabled
      )

    :ok = Manager.initialize()
    emulator = Emulator.new(80, 24)
    on_exit(fn -> :ets.delete(:test_command_registry) end)
    {:ok, %{emulator: emulator}}
  end

  describe "plugin metadata" do
    # (describe block intentionally left empty for now)
  end
end
