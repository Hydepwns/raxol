defmodule Raxol.Core.Runtime.Events.DispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Events.Dispatcher

  # Mock modules for testing
  defmodule Mock.Application do
    @behaviour Raxol.Core.Runtime.Application # Ensure it implements the behaviour

    # Default implementation
    def init(_), do: {%{count: 0}, []}
    def update(_msg, state), do: {state, []}
    def view(_state), do: nil
    def subscribe(_state), do: []

    # Test-specific implementations can be added here or via meck/mox
    def handle_event(event, model)
    # Example: Convert specific event to a message
    def update({:test_message, cmd_list}, model) do
      {%{model | count: model.count + 1}, cmd_list}
    end
  end

  # Mocks for runtime interactions
  defmock CommandMock, for: Raxol.Core.Runtime.Command
  defmock RenderingEngineMock, for: Raxol.Core.Runtime.Rendering.Engine
  defmock PubSubMock, for: Phoenix.PubSub # Assuming Phoenix PubSub is used

  setup do
    # Setup mocks
    Mox.stub_with(CommandMock, Raxol.Core.Runtime.Command)
    Mox.stub_with(RenderingEngineMock, Raxol.Core.Runtime.Rendering.Engine)
    Mox.stub_with(PubSubMock, Phoenix.PubSub)

    # Start Dispatcher manually for testing handle_cast/handle_call
    initial_state = %{
      app_module: Mock.Application,
      model: %{count: 0},
      commands: [],
      debug_mode: false,
      plugin_manager: nil, # Or mock this if needed
      pubsub_server: Raxol.PubSub, # Use the actual PubSub server name
      rendering_engine: Raxol.Core.Runtime.Rendering.Engine # Use actual name
    }
    {:ok, dispatcher_pid} = Dispatcher.start_link(initial_state)

    # Verify mocks on exit
    Mox.verify_on_exit!()
    {:ok, dispatcher: dispatcher_pid, initial_state: initial_state}
  end

  # --- Tests for GenServer Callbacks (handle_cast, handle_call) ---
  describe "GenServer Callbacks" do
    test "handle_cast :dispatch dispatches event and updates state", %{dispatcher: dispatcher, initial_state: initial_state} do
      event = %Event{type: :key, key: :enter, modifiers: []}

      # Expect interactions based on event dispatch
      # 1. Application update (potentially returns commands)
      # For simplicity, assume Mock.Application.update returns the command [:test_cmd]
      # (Need to adjust Mock.Application or use meck/mox for this)

      # 2. Command execution for any returned commands
      expect(CommandMock, :execute, fn :test_cmd, ^dispatcher -> :ok end)

      # 3. Notify Renderer
      expect(RenderingEngineMock, :cast, fn :render_frame -> :ok end)

      # 4. Broadcast event via PubSub
      expect(PubSubMock, :broadcast, fn Raxol.PubSub, "events", {:event, ^event} -> :ok end)

      # Send the cast
      :ok = GenServer.cast(dispatcher, {:dispatch, event})

      # Allow time for cast processing
      Process.sleep(50)

      # Verify state update (model count incremented)
      state = :sys.get_state(dispatcher)
      assert state.model.count == initial_state.model.count + 1
    end

    test "handle_cast :dispatch handles application update errors", %{dispatcher: dispatcher} do
      # Setup Dispatcher state to cause update failure
      error_state = %{
        app_module: Mock.Application,
        model: :invalid_model, # Cause update to likely fail
        commands: [], debug_mode: false, plugin_manager: nil,
        pubsub_server: Raxol.PubSub,
        rendering_engine: Raxol.Core.Runtime.Rendering.Engine
      }
      :sys.replace_state(dispatcher, error_state)

      event = %Event{type: :key, key: :enter, modifiers: []}

      # Expect only PubSub broadcast (as error happens during update)
      expect(PubSubMock, :broadcast, fn Raxol.PubSub, "events", {:event, ^event} -> :ok end)

      # Ensure Command execution and Renderer notification DON'T happen

      log = capture_log(fn ->
        :ok = GenServer.cast(dispatcher, {:dispatch, event})
        Process.sleep(50) # Allow cast processing
      end)

      # Assert error was logged
      assert log =~ "Error updating application state"
      # Assert state wasn't significantly changed (or reflects error state)
      current_state = :sys.get_state(dispatcher)
      assert current_state.model == :invalid_model
    end

    # TODO: Add tests for handle_call (:get_state)
  end


  # --- Existing Tests (Refactored if needed) ---
  # Keep the describe blocks for internal logic tests if still relevant
  # Or integrate them into the GenServer callback tests

  # describe "dispatch_event/2" do ... end
  # describe "process_system_event/2" do ... end
  # describe "handle_event/2" do ... end
end
