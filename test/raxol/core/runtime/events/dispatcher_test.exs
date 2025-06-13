defmodule Raxol.Core.Runtime.Events.DispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  # Use Mox instead
  import Mox
  # Added for stub logging
  require Raxol.Core.Runtime.Log

  # Mox mocks definition
  defmock(ApplicationMock, for: Raxol.Core.Runtime.Application)

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  # Add Alias for PubSub
  # Assuming this is the correct PubSub module
  alias Phoenix.PubSub
  # Needed for Mox types
  alias Raxol.Core.UserPreferences

  # Simple Mock GenServer for PluginManager
  defmodule Mock.PluginManager do
    use GenServer

    def start_link(_opts) do
      # Accept :runtime_pid for compatibility, ignore it
      GenServer.start_link(__MODULE__, nil)
    end

    def init(_), do: {:ok, nil}
    # Allow call for filter_event
    def handle_call({:filter_event, event}, _from, state),
      do: {:reply, {:ok, event}, state}

    # Default reply
    def handle_call(_msg, _from, state), do: {:reply, :ok, state}
  end

  describe "GenServer Callbacks" do
    # No context injected from setup
    test "handle_cast :dispatch dispatches event and updates state" do
      # Attempt to resize RenderingEngine buffer to minimize log output on failure
      # This is a temporary measure to help diagnose the actual test failure.
      # It assumes RenderingEngine is running and registered by this name.
      _ =
        GenServer.cast(
          Raxol.Core.Runtime.Rendering.Engine,
          {:update_size, %{width: 1, height: 1}}
        )

      # Start Mock Plugin Manager for this test
      {:ok, mock_pm_pid} = Mock.PluginManager.start_link([])

      # Define initial state for this test
      initial_state = %{
        # Use ApplicationMock
        app_module: ApplicationMock,
        # This model is expected to be initialized by ApplicationMock.init
        model: %{count: 0},
        runtime_pid: self(),
        width: 80,
        height: 24,
        focused: true,
        debug_mode: false,
        # Use per-test PID
        plugin_manager: mock_pm_pid,
        command_registry_table: :raxol_command_registry,
        # Use PubSubMock
        pubsub_server: PubSubMock,
        # Ensure RenderingEngine is included
        rendering_engine: Raxol.Core.Runtime.Rendering.Engine,
        # Add missing key
        initial_commands: []
      }

      # Mox expectations
      Mox.expect(ApplicationMock, :init, fn _opts -> {:ok, %{count: 0}} end)

      event = %Event{
        type: :key,
        data: %{key: :enter, state: :pressed, modifiers: []}
      }

      Mox.expect(ApplicationMock, :handle_event, fn ^event, model ->
        {:ok, model, [%Command{type: :system, data: {:event_handled, event}}]}
      end)

      # MODIFIED: Stub Raxol.Core.Runtime.Command.execute directly
      execute_stub_fun = fn
        # Match first expected call from handle_event result
        %Command{type: :system, data: {:event_handled, ^event}}, _context ->
          :ok

        # Match second expected call from update result
        %Command{type: :system, data: {:test_cmd, []}}, _context ->
          :ok

        # Default case (log unexpected calls)
        unexpected_cmd, _context ->
          Raxol.Core.Runtime.Log.warning(
            "Unexpected call to Command.execute stub in test '#{__ENV__.function}': #{inspect(unexpected_cmd)}"
          )

          :error
      end

      Mox.stub(Raxol.Core.Runtime.Command, :execute, execute_stub_fun)

      Mox.expect(ApplicationMock, :update, fn _msg, model ->
        {:ok, %{model | count: model.count + 1},
         [%Command{type: :system, data: {:test_cmd, []}}]}
      end)

      # MODIFIED: Stub Phoenix.PubSub.broadcast directly
      broadcast_stub_fun = fn
        _pubsub_server, "events", {:event, ^event} ->
          :ok

        server, topic, msg ->
          Raxol.Core.Runtime.Log.warning(
            "Unexpected call to PubSub.broadcast stub in test '#{__ENV__.function}': #{inspect({server, topic, msg})}"
          )

          :error
      end

      Mox.stub(Phoenix.PubSub, :broadcast, broadcast_stub_fun)

      # MODIFIED: Directly stub the real UserPreferences module
      Mox.stub(Raxol.Core.UserPreferences, :get, fn "theme.active_id" ->
        :default
      end)

      # Start Dispatcher for this test
      {:ok, dispatcher} = Dispatcher.start_link(self(), initial_state)

      :ok = GenServer.cast(dispatcher, {:dispatch, event})

      # Assertions (e.g., state change, messages sent)
      assert_receive {:render_needed, _}, 100
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 1

      # Test-specific teardown
      on_exit(fn ->
        # Verify all Mox expectations
        Mox.verify!()
        GenServer.stop(mock_pm_pid)
      end)
    end

    test "handle_cast :dispatch handles application update errors" do
      # Start Mock Plugin Manager for this test
      {:ok, mock_pm_pid} = Mock.PluginManager.start_link([])

      # Define initial state for this test
      initial_state = %{
        app_module: ApplicationMock,
        model: %{count: 0},
        runtime_pid: self(),
        width: 80,
        height: 24,
        focused: true,
        debug_mode: false,
        plugin_manager: mock_pm_pid,
        command_registry_table: :raxol_command_registry,
        pubsub_server: PubSubMock,
        rendering_engine: Raxol.Core.Runtime.Rendering.Engine,
        initial_commands: []
      }

      # Mox expectations
      Mox.expect(ApplicationMock, :init, fn _opts -> {:ok, %{count: 0}} end)

      event = %Event{
        type: :key,
        data: %{key: :enter, state: :pressed, modifiers: []}
      }

      # Expect handle_event to be called
      Mox.expect(ApplicationMock, :handle_event, fn ^event, model ->
        {:ok, model, []}
      end)

      # Stub Command.execute
      Mox.stub(Raxol.Core.Runtime.Command, :execute, fn _cmd, _context -> :ok end)

      # Expect update to fail
      Mox.expect(ApplicationMock, :update, fn _any_event_or_msg, _model ->
        {:error, :simulated_error}
      end)

      # Stub PubSub.broadcast
      Mox.stub(Phoenix.PubSub, :broadcast, fn _server, "events", {:event, ^event} -> :ok end)

      # Stub UserPreferences
      Mox.stub(Raxol.Core.UserPreferences, :get, fn "theme.active_id" -> :default end)

      # Start Dispatcher for this test
      {:ok, dispatcher} = Dispatcher.start_link(self(), initial_state)

      :ok = GenServer.cast(dispatcher, {:dispatch, event})

      # Assertions: No render needed, state unchanged
      refute_receive {:render_needed, _}, 100
      current_state_after_error = :sys.get_state(dispatcher)
      assert current_state_after_error.model.count == 0

      # Test-specific teardown
      on_exit(fn ->
        Mox.verify!()
        GenServer.stop(mock_pm_pid)
      end)
    end
  end
end
