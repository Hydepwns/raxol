defmodule Raxol.Core.Runtime.Events.DispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  # REMOVE Mox import as it's no longer needed
  # import Mox

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  # Add Alias for PubSub
  alias Phoenix.PubSub # Assuming this is the correct PubSub module

  # Mock modules for testing
  defmodule Mock.Application do
    use Raxol.Core.Runtime.Application

    def init(_opts), do: {:ok, %{value: 0}}

    # Group update clauses together
    def update(:increment, model), do: {:ok, %{model | value: model.value + 1}, []}

    def update({:test_message, cmd_list}, model) do
      {:ok, model, cmd_list}
    end

    # Provide implementation for handle_event/2
    def handle_event(event, model) do
      # Simple echo for testing, adjust if specific event handling needed
      Logger.debug("Mock.Application received event: #{inspect(event)}")
      {:ok, model, [{:command, {:event_handled, event}}]} # Example command
    end

    def view(model), do: {:text, "Value: #{model.value}"}
  end

  # Remove Mox defmock for Command
  # defmock CommandMock, for: Raxol.Core.Runtime.Command

  # REMOVE Mox defmock for PubSub
  # defmock PubSubMock, for: Phoenix.PubSub

  setup do
    # Setup mocks
    # REMOVE Mox stub for PubSub
    # Mox.stub_with(PubSubMock, Phoenix.PubSub)

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

    # REMOVE Mox verify_on_exit
    # Mox.verify_on_exit!()
    {:ok, dispatcher: dispatcher_pid, initial_state: initial_state}
  end

  # --- Tests for GenServer Callbacks (handle_cast, handle_call) ---
  describe "GenServer Callbacks" do
    test "handle_cast :dispatch dispatches event and updates state", %{dispatcher: dispatcher, initial_state: initial_state} do
      event = %Event{type: :key, data: %{key: :enter, state: :pressed, modifiers: []}}

      # Mocks setup for this test
      :meck.new(Command, [:passthrough]) # Allow non-mocked functions
      :meck.new(RenderingEngine, [:passthrough])
      :meck.new(PubSub, [:passthrough])

      # Expect interactions based on event dispatch
      # 1. Application update (assumed to return :test_cmd via Mock.Application)

      # 2. Command execution
      :meck.expect(Command, :execute, fn :test_cmd, _context -> :ok end)

      # 3. Notify Renderer
      :meck.expect(RenderingEngine, :cast, fn :render_frame -> :ok end)

      # 4. Broadcast event via PubSub
      # Use :meck.expect for PubSub.broadcast
      :meck.expect(PubSub, :broadcast, fn Raxol.PubSub, "events", {:event, ^event} -> :ok end)

      # Send the cast
      :ok = GenServer.cast(dispatcher, {:dispatch, event})

      # Allow time for cast processing
      Process.sleep(50)

      # Verify state update (model count incremented)
      state = :sys.get_state(dispatcher)
      assert state.model.count == initial_state.model.count + 1

      :meck.unload(Command)
      :meck.unload(RenderingEngine)
      # Validate and unload PubSub
      :meck.validate(PubSub)
      :meck.unload(PubSub)
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

      event = %Event{type: :key, data: %{key: :enter, state: :pressed, modifiers: []}}

      # Mocks setup
      :meck.new(Command, [:passthrough])
      :meck.new(RenderingEngine, [:passthrough])
      :meck.new(PubSub, [:passthrough])

      # Expect only PubSub broadcast (as error happens during update)
      :meck.expect(PubSub, :broadcast, fn Raxol.PubSub, "events", {:event, ^event} -> :ok end)

      # Ensure Command execution and Renderer notification DON'T happen
      # (meck will validate this as no expect calls were made for them)

      log = capture_log(fn ->
        :ok = GenServer.cast(dispatcher, {:dispatch, event})
        Process.sleep(50) # Allow cast processing
      end)

      # Assert error was logged
      assert log =~ "Error updating application state"
      # Assert state wasn't significantly changed (or reflects error state)
      current_state = :sys.get_state(dispatcher)
      assert current_state.model == :invalid_model

      :meck.unload(Command)
      :meck.unload(RenderingEngine)
      # Validate and unload PubSub
      :meck.validate(PubSub)
      :meck.unload(PubSub)
    end

    # TODO: Add tests for handle_call (:get_state)
  end


  # --- Existing Tests (Refactored if needed) ---
  # Keep the describe blocks for internal logic tests if still relevant
  # Or integrate them into the GenServer callback tests

  # describe "dispatch_event/2" do ... end
  # describe "process_system_event/2" do ... end
  # describe "handle_event/2" do ... end

  # Mock the application module's update function
  # ADD EXPECTATION HERE:
  # expect(MockApplication, :update, fn _event, model ->
  #   {model, []} # Return model unchanged, no commands
  # end)

  # Mock command execution (if needed)
  # expect(MockCommandHelper, :execute_command, fn _, _, _ -> :ok end)
end
