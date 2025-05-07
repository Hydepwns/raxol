defmodule Raxol.Core.Runtime.Events.DispatcherTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  # REMOVE Mox import as it's no longer needed
  # import Mox
  # Use Mox instead
  import Mox

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  # Add Alias for PubSub
  alias Phoenix.PubSub # Assuming this is the correct PubSub module
  alias Raxol.Core.UserPreferences # Needed for meck
  alias Raxol.Core.Runtime.Events.DispatcherTest.Mock.Application, as: MockApp

  # Define Mox mock for UserPreferences
  # defmock(UserPreferencesMock, for: Raxol.Core.UserPreferences)

  # Simple Mock GenServer for PluginManager
  defmodule Mock.PluginManager do
    use GenServer
    def start_link(_opts), do: GenServer.start_link(__MODULE__, nil)
    def init(_), do: {:ok, nil}
    # Allow call for filter_event
    def handle_call({:filter_event, event}, _from, state), do: {:reply, {:ok, event}, state}
    def handle_call(_msg, _from, state), do: {:reply, :ok, state} # Default reply
  end

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
    :meck.new(UserPreferences, [:non_strict, :passthrough])
    :meck.expect(UserPreferences, :get, fn "theme.active_id" -> :default end)

    # Dispatcher and Mock PM started per-test

    on_exit(fn ->
      :meck.validate(UserPreferences)
      :meck.unload(UserPreferences)
    end)

    # No context returned from setup anymore
    :ok
  end

  describe "GenServer Callbacks" do
    # No context injected from setup
    test "handle_cast :dispatch dispatches event and updates state" do
      # Start Mock Plugin Manager for this test
      {:ok, mock_pm_pid} = Mock.PluginManager.start_link([])

      # Define initial state for this test
      initial_state = %{
        app_module: MockApp,
        model: %{count: 0},
        runtime_pid: self(),
        width: 80,
        height: 24,
        focused: true,
        debug_mode: false,
        plugin_manager: mock_pm_pid, # Use per-test PID
        command_registry_table: :raxol_command_registry,
        pubsub_server: Raxol.PubSub, # Ensure PubSub server is included
        rendering_engine: Raxol.Core.Runtime.Rendering.Engine, # Ensure RenderingEngine is included
        initial_commands: [] # Add missing key
      }

      # Start Dispatcher for this test
      {:ok, dispatcher} = Dispatcher.start_link(self(), initial_state)

      event = %Event{type: :key, data: %{key: :enter, state: :pressed, modifiers: []}}

      # Mocks setup for this test
      :meck.new(MockApp, [:non_strict])
      :meck.expect(MockApp, :update, 2, fn _msg, state -> {%{state | count: state.count + 1}, [%Command{type: :system, data: {:test_cmd, []}}]} end)
      :meck.new(Command, [:passthrough])
      :meck.expect(Command, :execute, fn %Command{type: :system, data: {:test_cmd, []}}, _context -> :ok end)
      :meck.new(PubSub, [:passthrough])
      :meck.expect(PubSub, :broadcast, fn Raxol.PubSub, "events", {:event, ^event} -> :ok end)
      # :meck.new(GenServer, [:passthrough]) # GenServer mock still commented out
      # :meck.expect(GenServer, :call, fn ^mock_pm_pid, {:filter_event, ^event}, 5000 -> {:ok, event} end)

      :ok = GenServer.cast(dispatcher, {:dispatch, event})

      Process.sleep(50) # Allow cast to process

      # Assertions (e.g., state change, messages sent)
      assert_receive {:render_needed, _}, 100
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 1

      # Test-specific teardown
      on_exit(fn ->
        :meck.validate(MockApp)
        :meck.validate(PubSub)
        # :meck.validate(GenServer)
        :meck.validate(Command)
        :meck.unload(MockApp)
        :meck.unload(PubSub)
        # :meck.unload(GenServer)
        :meck.unload(Command)
        GenServer.stop(mock_pm_pid)
      end)
    end

    test "handle_cast :dispatch handles application update errors" do
      # Start Mock Plugin Manager for this test
      {:ok, mock_pm_pid} = Mock.PluginManager.start_link([])

      # Define initial state for this test
      initial_state = %{
        app_module: MockApp,
        model: %{count: 0}, # Start with valid model
        runtime_pid: self(),
        width: 80,
        height: 24,
        focused: true,
        debug_mode: false,
        plugin_manager: mock_pm_pid, # Use per-test PID
        command_registry_table: :raxol_command_registry,
        pubsub_server: Raxol.PubSub,
        rendering_engine: Raxol.Core.Runtime.Rendering.Engine,
        initial_commands: [] # Add missing key
      }

      # Start Dispatcher for this test
      {:ok, dispatcher} = Dispatcher.start_link(self(), initial_state)

      event = %Event{type: :key, data: %{key: :enter, state: :pressed, modifiers: []}}

      # Mocks setup for this test
      :meck.new(MockApp, [:non_strict])
      :meck.expect(MockApp, :update, fn ^event, _model -> {:error, :simulated_error} end)
      :meck.new(Command, [:passthrough])
      :meck.new(PubSub, [:passthrough])
      # :meck.new(GenServer, [:passthrough])
      # :meck.expect(GenServer, :call, fn ^mock_pm_pid, {:filter_event, ^event}, 5000 -> {:ok, event} end)

      :ok = GenServer.cast(dispatcher, {:dispatch, event})
      Process.sleep(50) # Allow cast to process

      # Assertions: No render needed, state unchanged
      refute_receive {:render_needed, _}, 100
      current_state_after_error = :sys.get_state(dispatcher)
      assert current_state_after_error.model.count == 0

      # Test-specific teardown
      on_exit(fn ->
        :meck.validate(MockApp)
        :meck.validate(Command)
        # :meck.validate(GenServer)
        :meck.unload(Command)
        :meck.unload(PubSub)
        :meck.unload(MockApp)
        # :meck.unload(GenServer)
        GenServer.stop(mock_pm_pid)
      end)
    end
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
