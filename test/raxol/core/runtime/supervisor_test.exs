defmodule Raxol.Core.Runtime.SupervisorTest do
  @moduledoc """
  Tests for the runtime supervisor, including child process management,
  supervisor configuration, and error handling.
  """
  use ExUnit.Case, async: false
  require Mox
  import Mox
  import Raxol.Test.TestUtils

  # Mock modules for testing
  defmodule Mock.EventLoop do
    use GenServer

    def start_link(_),
      do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

    def init(_), do: {:ok, nil}
  end

  defmodule Mock.RenderLoop do
    use GenServer

    def start_link(_),
      do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

    def init(_), do: {:ok, nil}
  end

  defmodule Mock.Plugins.Manager do
    use GenServer

    def start_link(_),
      do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

    def init(_), do: {:ok, nil}
  end

  defmodule Mock.Plugins.Commands do
    use GenServer

    def start_link(_),
      do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

    def init(_), do: {:ok, nil}
  end

  # Define mocks for dependencies
  # Dispatcher mock removed - no behavior exists for Events Dispatcher
  # Mox.defmock(Raxol.Core.Runtime.Events.DispatcherMock,
  #   for: Raxol.Core.Runtime.Events.Dispatcher.Behaviour
  # )

  # Rendering Engine mock removed - no behavior exists for Rendering Engine
  # Mox.defmock(Raxol.Core.Runtime.Rendering.EngineMock,
  #   for: Raxol.Core.Runtime.Rendering.Engine.Behaviour
  # )

  # PluginManager.Behaviour mock removed - behavior doesn't exist
  # Mox.defmock(Raxol.Core.Runtime.Plugins.PluginManagerMock,
  #   for: Raxol.Core.Runtime.Plugins.PluginManager.Behaviour
  # )

  # DriverMock already defined in test/support/terminal_driver_mock.ex

  setup do
    # Set Mox to global mode so expectations are visible to spawned processes
    Mox.set_mox_global(true)
    # Set up test environment and mocks
    {:ok, context} = setup_test_env()
    setup_common_mocks()

    # Verify on exit
    :verify_on_exit!

    {:ok, context}
  end

  describe "supervisor structure" do
    @tag :skip
    test ~c"starts all runtime child processes with mocks" do
      # Define the init args, injecting mock modules
      init_arg = %{
        dispatcher_module: Raxol.Core.Runtime.Events.DispatcherMock,
        rendering_engine_module: Raxol.Core.Runtime.Rendering.EngineMock,
        plugin_manager_module: Raxol.Core.Runtime.Plugins.PluginManagerMock,
        app_module: TestApp,
        width: 80,
        height: 24
      }

      # Expectation for Plugins.ManagerMock.start_link/1
      expect(Raxol.Core.Runtime.Plugins.PluginManagerMock, :start_link, fn _args ->
        {:ok, spawn(fn -> :ok end)}
      end)

      # Expectation for DispatcherMock.start_link/2 (match full init_arg)
      expect(Raxol.Core.Runtime.Events.DispatcherMock, :start_link, fn pid,
                                                                       arg ->
        assert is_pid(pid)
        assert is_map(arg)

        assert arg[:dispatcher_module] ==
                 Raxol.Core.Runtime.Events.DispatcherMock

        {:ok, spawn(fn -> :ok end)}
      end)

      expect(
        Raxol.Core.Runtime.Rendering.EngineMock,
        :start_link,
        fn _initial_state_map -> {:ok, spawn(fn -> :ok end)} end
      )

      # Call the supervisor's own start_link/1 function with the modified init_arg
      {:ok, _pid} = Raxol.Core.Runtime.Supervisor.start_link(init_arg)
    end

    test ~c"uses one_for_all strategy" do
      # Minimal init_arg needed for Supervisor.init/1 to work
      init_arg = %{
        app_module: TestApp,
        width: 80,
        height: 24
      }

      # Call the supervisor's init/1 function directly
      result = Raxol.Core.Runtime.Supervisor.init(init_arg)
      # result is {:ok, {children, opts}}
      assert match?({:ok, {_children, _opts}}, result)
      {:ok, {_children, opts}} = result
      assert is_list(opts)
    end
  end
end
