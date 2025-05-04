defmodule Raxol.Core.Runtime.SupervisorTest do
  use ExUnit.Case, async: false

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
    def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    def init(_), do: {:ok, nil}
  end

  defmodule Mock.RenderLoop do
    use GenServer
    def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    def init(_), do: {:ok, nil}
  end

  defmodule Mock.Plugins.Manager do
    use GenServer
    def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    def init(_), do: {:ok, nil}
  end

  defmodule Mock.Plugins.Commands do
    use GenServer
    def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    def init(_), do: {:ok, nil}
  end

  # Helper function for setting up Meck mocks
  defp setup_meck(module) do
    :meck.new(module, [:passthrough])
    on_exit(fn -> :meck.unload(module) end)
  end

  setup do
    # Use Meck for modules that are not behaviours or where Mox causes issues
    setup_meck(Raxol.Core.Runtime.Events.Dispatcher)
    setup_meck(Raxol.Core.Runtime.Manager)
    setup_meck(Raxol.Core.Runtime.Plugins.Manager)
    setup_meck(Raxol.Core.Renderer.Manager)
    setup_meck(Raxol.Terminal.Driver)
    :ok
  end

  describe "supervisor structure" do
    test "starts all runtime child processes" do
      # Expectations for child processes using Meck
      :meck.expect(Raxol.Core.Runtime.Plugins.Manager, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)
      :meck.expect(Raxol.Core.Runtime.Events.Dispatcher, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)
      :meck.expect(Raxol.Core.Runtime.Manager, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)
      :meck.expect(Raxol.Core.Renderer.Manager, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)
      :meck.expect(Raxol.Terminal.Driver, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      {:ok, _pid} = Supervisor.start_link([], name: Raxol.Core.Runtime.Supervisor)

      # Verify Meck expectations
      :meck.validate(Raxol.Core.Runtime.Plugins.Manager)
      :meck.validate(Raxol.Core.Runtime.Events.Dispatcher)
      :meck.validate(Raxol.Core.Runtime.Manager)
      :meck.validate(Raxol.Core.Renderer.Manager)
      :meck.validate(Raxol.Terminal.Driver)
    end

    test "uses one_for_all strategy" do
      # Fetch the supervisor spec directly
      {:ok, {config, _}} = Supervisor.init([])
      # Check the strategy defined in the spec
      assert config[:strategy] == :one_for_all
    end
  end
end
