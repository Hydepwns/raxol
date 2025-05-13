defmodule Raxol.Core.Runtime.Plugins.EdgeCases.Helper do
  use ExUnit.Case
  require Logger
  import Mox

  alias Raxol.Core.Events.Event

  alias Raxol.Core.Runtime.Plugins.{
    Manager,
    Loader,
    LifecycleHelper,
    CommandRegistry
  }

  alias Raxol.Test.PluginTestFixtures

  # Define Mox mock for LifecycleHelper
  Mox.defmock(EdgeCasesLifecycleHelperMock,
    for: Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  )

  def setup_test do
    # Reset Mox for each test
    Mox.stub_with(EdgeCasesLifecycleHelperMock, LifecycleHelper)
    Mox.verify_on_exit!()

    # Create a unique ETS table name for each test
    table_name = :"command_registry_#{:rand.uniform(1_000_000)}"
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

    # Store the table name in the test context
    {:ok, %{command_registry_table: table_name}}
  end

  def with_running_manager(opts \\ [], fun) do
    {:ok, pid} = Manager.start_link(opts)

    try do
      fun.(pid)
    after
      Manager.stop(pid)
    end
  end

  def setup_plugin(manager_pid, module, plugin_id, opts) do
    Manager.load_plugin(manager_pid, module, plugin_id, opts)
  end

  def assert_plugin_load_fails(manager_pid, module, opts, expected_error) do
    assert {:error, error} = Manager.load_plugin(manager_pid, module, opts)
    assert error == expected_error
  end

  def execute_command_and_verify(
        manager_pid,
        plugin_id,
        command,
        args,
        expected_errors,
        command_registry_table
      ) do
    assert {:error, error} =
             Raxol.Core.Runtime.Plugins.CommandRegistry.execute_command(
               command,
               args,
               command_registry_table
             )

    assert error in expected_errors
  end
end
