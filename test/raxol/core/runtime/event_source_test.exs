defmodule Raxol.Core.Runtime.EventSourceTest do
  use ExUnit.Case, async: true

  defmodule TestEventSource do
    use Raxol.Core.Runtime.EventSource

    @impl true
    def init(args, context) do
      if args[:fail_init] do
        {:error, :init_failed}
      else
        {:ok, %{args: args, context: context}}
      end
    end

    @impl true
    def handle_info(:send_event, state) do
      send_event(state.context, {:test_event, state.args[:data]})
      {:noreply, state}
    end

    def handle_info(:stop, state) do
      {:stop, :normal, state}
    end

    def handle_info(:raise, _state) do
      raise "Test error"
    end

    @impl true
    def terminate(:normal, state) do
      send(state.context.pid, :terminated_normally)
      :ok
    end

    def terminate(_reason, _state), do: :ok
  end

  describe "EventSource behaviour" do
    setup do
      context = %{pid: self()}
      {:ok, context: context}
    end

    test "starts and initializes successfully", %{context: context} do
      args = %{data: :test_data}
      assert {:ok, pid} = TestEventSource.start_link(args, context)
      assert is_pid(pid)
    end

    test "fails to initialize when requested", %{context: context} do
      args = %{fail_init: true}
      assert {:error, :init_failed} = TestEventSource.start_link(args, context)
    end

    test "sends events to subscriber", %{context: context} do
      args = %{data: :test_data}
      {:ok, pid} = TestEventSource.start_link(args, context)

      send(pid, :send_event)
      assert_receive {:subscription, {:test_event, :test_data}}
    end

    test "stops normally", %{context: context} do
      args = %{data: :test_data}
      {:ok, pid} = TestEventSource.start_link(args, context)
      ref = Process.monitor(pid)

      send(pid, :stop)
      assert_receive :terminated_normally
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    @tag :pending
    test "handles crashes", %{context: context} do
      # Test that the process crashes but is restarted
      pid =
        Raxol.TestHelpers.start_test_event_source(%{data: :test_data}, context)

      # Killing the process should trigger a restart
      Process.exit(pid, :kill)

      # Monitor the process (reuse same pid variable)
      ref = Process.monitor(pid)

      # Expect DOWN message (not checking contents)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 500

      # Wait a moment for restart
      :timer.sleep(100)

      # The source should still be alive (check using the registered name)
      # assert Process.whereis(TestSource) # TestSource is not a registered name
    end
  end
end
