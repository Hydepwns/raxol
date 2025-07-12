defmodule Raxol.EmulatorPluginTestHelper do
  @moduledoc """
  Shared test helper for emulator plugin tests.
  Provides common setup functionality used across multiple plugin test modules.
  """

  alias Raxol.Core.Runtime.Plugins.Manager
  alias Raxol.Terminal.Emulator

  @doc """
  Common setup function for emulator plugin tests.
  Returns the setup data with emulator and cleanup function.
  """
  def setup_emulator_plugin_test(context) do
    reloading_enabled = Keyword.has_key?(context.tags, :enable_plugin_reloading)

    {:ok, _pid} =
      Manager.start_link(
        command_registry_table: :test_command_registry,
        plugin_config: %{},
        enable_plugin_reloading: reloading_enabled,
        runtime_pid: self()
      )

    :ok = Manager.initialize()
    emulator = Emulator.new(80, 24)
    on_exit(fn -> :ets.delete(:test_command_registry) end)
    {:ok, %{emulator: emulator}}
  end
end
