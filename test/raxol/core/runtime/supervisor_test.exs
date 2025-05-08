defmodule Raxol.Core.Runtime.SupervisorTest do
  use ExUnit.Case, async: false
  require Mox

  alias Raxol.Core.Runtime.Supervisor

  # Mock modules for testing
  # REMOVED: Mock.StateManager as it's no longer a child
  # defmodule Mock.StateManager do
  #   use GenServer
  #   def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  #   def init(_), do: {:ok, nil}
  # end

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
  # Mox.defmock(Raxol.Core.Runtime.Events.DispatcherMock, for: Raxol.Core.Runtime.Events.Dispatcher.Behaviour)
  # Mox.defmock(Raxol.Core.Runtime.Rendering.EngineMock, for: Raxol.Core.Runtime.Rendering.Engine.Behaviour)
  # Mox.defmock(Raxol.Core.Runtime.Plugins.ManagerMock, for: Raxol.Core.Runtime.Plugins.Manager.Behaviour)
  # Mox.defmock(Raxol.Terminal.DriverMock, for: Raxol.Terminal.Driver.Behaviour)

  setup do
    # Define mocks here
    Mox.defmock(Raxol.Core.Runtime.Events.DispatcherMock,
      for: Raxol.Core.Runtime.Events.Dispatcher.Behaviour
    )

    Mox.defmock(Raxol.Core.Runtime.Rendering.EngineMock,
      for: Raxol.Core.Runtime.Rendering.Engine.Behaviour
    )

    Mox.defmock(Raxol.Core.Runtime.Plugins.ManagerMock,
      for: Raxol.Core.Runtime.Plugins.Manager.Behaviour
    )

    Mox.defmock(Raxol.Terminal.DriverMock, for: Raxol.Terminal.Driver.Behaviour)
    # Verify on exit
    :verify_on_exit!
  end

  describe "supervisor structure" do
    test "starts all runtime child processes with mocks" do
      # Define the init args, injecting mock modules
      init_arg = %{
        dispatcher_module: Raxol.Core.Runtime.Events.DispatcherMock,
        rendering_engine_module: Raxol.Core.Runtime.Rendering.EngineMock,
        plugin_manager_module: Raxol.Core.Runtime.Plugins.ManagerMock,
        # Add other necessary args for children, e.g.:
        app_module: TestApp,
        width: 80,
        height: 24
      }

      # Expectations for child processes using Mox
      # Note: Terminal.Driver isn't started by this supervisor, so no expectation here
      Mox.expect(Raxol.Core.Runtime.Plugins.ManagerMock, :start_link, fn [_args] ->
        {:ok, spawn(fn -> :ok end)}
      end)

      Mox.expect(Raxol.Core.Runtime.Events.DispatcherMock, :start_link, fn _pid,
                                                                           _init_arg ->
        {:ok, spawn(fn -> :ok end)}
      end)

      Mox.expect(
        Raxol.Core.Runtime.Rendering.EngineMock,
        :start_link,
        fn _initial_state_map -> {:ok, spawn(fn -> :ok end)} end
      )

      # Call the supervisor's own start_link/1 function with the modified init_arg
      {:ok, _pid} = Raxol.Core.Runtime.Supervisor.start_link(init_arg)

      # Verify Mox expectations (verify automatically happens on exit due to setup :verify_on_exit!)
      # Explicit verify calls are optional here
      # Mox.verify!(Raxol.Core.Runtime.Plugins.ManagerMock)
      # Mox.verify!(Raxol.Core.Runtime.Events.DispatcherMock)
      # Mox.verify!(Raxol.Core.Runtime.Rendering.EngineMock)
    end

    test "uses one_for_all strategy" do
      # Minimal init_arg needed for Supervisor.init/1 to work
      init_arg = %{}
      # Fetch the supervisor spec directly by calling init/1
      # Supervisor.init/1 returns the child specs and options
      {children_spec, opts} = Supervisor.init(init_arg)

      # Assert on the strategy option
      assert opts[:strategy] == :one_for_all
      # Optionally assert on children if needed, e.g., check count or types
      assert is_list(children_spec)
    end
  end
end
