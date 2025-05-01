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

  describe "supervisor structure" do
    test "starts all runtime child processes" do
      # Restart the supervisor with mocked modules
      # REMOVED: Meck setup for StateManager
      # :meck.new(Raxol.Core.Runtime.StateManager, [:passthrough])
      # :meck.expect(Raxol.Core.Runtime.StateManager, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      :meck.new(Raxol.Core.Runtime.EventLoop, [:passthrough])
      :meck.expect(Raxol.Core.Runtime.EventLoop, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      :meck.new(Raxol.Core.Runtime.RenderLoop, [:passthrough])
      :meck.expect(Raxol.Core.Runtime.RenderLoop, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      :meck.new(Raxol.Core.Runtime.Plugins.Manager, [:passthrough])
      :meck.expect(Raxol.Core.Runtime.Plugins.Manager, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      :meck.new(Raxol.Core.Runtime.Plugins.Commands, [:passthrough])
      :meck.expect(Raxol.Core.Runtime.Plugins.Commands, :start_link, fn _ -> {:ok, spawn(fn -> :ok end)} end)

      # Start the supervisor
      pid = start_supervised!(Supervisor)

      # Verify it's a supervisor
      info = Process.info(pid, :dictionary)
      dictionary = Keyword.get(info, :dictionary, [])
      initial_call = Keyword.get(dictionary, :"$initial_call")
      assert initial_call == {Supervisor, :init, 1}

      # Get child specs to verify structure
      children = Supervisor.which_children(pid)

      # Check correct number of children (Now 5)
      assert length(children) == 5

      # Verify expected child processes exist
      child_ids = Enum.map(children, fn {id, _, _, _} -> id end)
      assert Task.Supervisor in child_ids
      # REMOVED: assert Raxol.Core.Runtime.StateManager in child_ids
      assert Raxol.Core.Runtime.EventLoop in child_ids
      assert Raxol.Core.Runtime.RenderLoop in child_ids
      assert Raxol.Core.Runtime.Plugins.Manager in child_ids
      assert Raxol.Core.Runtime.Plugins.Commands in child_ids

      # Clean up
      # REMOVED: Meck unload for StateManager
      # :meck.unload(Raxol.Core.Runtime.StateManager)
      :meck.unload(Raxol.Core.Runtime.EventLoop)
      :meck.unload(Raxol.Core.Runtime.RenderLoop)
      :meck.unload(Raxol.Core.Runtime.Plugins.Manager)
      :meck.unload(Raxol.Core.Runtime.Plugins.Commands)
    end

    test "uses one_for_all strategy" do
      # Extract supervisor configuration without starting it
      {:ok, {config, _}} = Supervisor.init([])

      # Verify supervision strategy
      assert config[:strategy] == :one_for_all
    end
  end
end
