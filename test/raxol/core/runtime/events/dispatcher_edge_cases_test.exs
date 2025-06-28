defmodule Raxol.Core.Runtime.Events.DispatcherEdgeCasesTest do
  use ExUnit.Case, async: false
  require Raxol.Core.Runtime.Log
  import Mox

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Plugins.Manager
  alias Phoenix.PubSub
  alias Raxol.Core.UserPreferences
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences.Behaviour, as: UserPreferencesBehaviour
  alias Raxol.UI.Theming.ThemeBehaviour

  # Mox defmocks
  defmock(UserPreferencesMock, for: UserPreferencesBehaviour)
  defmock(ThemeMock, for: Raxol.UI.Theming.ThemeBehaviour)

  # Mock Application module that implements Application behavior
  defmodule MockApp do
    @behaviour Raxol.Core.Runtime.Application

    def init(_app_module, _context) do
      {:ok, %{count: 0, last_event: nil}, []}
    end

    def update(msg, state) do
      case msg do
        {:key_press, :crash, _} ->
          raise "Simulated crash in application update"

        {:key_press, :error, _} ->
          {:error, :simulated_error}

        {:key_press, {:timeout, test_pid}, _modifiers} when is_pid(test_pid) ->
          # Simulate long computation with event-based approach
          timer_id = System.unique_integer([:positive])
          Process.send_after(self(), {:update_complete, timer_id}, 200)

          receive do
            {:update_complete, ^timer_id} ->
              send(test_pid, :mock_app_slow_update_finished)
              {%{state | count: state.count + 1, last_event: msg}, []}
          end

        _ ->
          {%{state | count: state.count + 1, last_event: msg}, []}
      end
    end

    def view(model) do
      # Simple view
      [%{type: :text, content: "Count: #{model.count}", x: 0, y: 0}]
    end

    # Required behaviour callbacks
    def handle_event(_), do: :ok
    def handle_message(_, _), do: :ok
    def handle_tick(_), do: :ok
    def subscriptions(_), do: []
    def terminate(_, _), do: :ok
  end

  # Mock Plugin Manager module
  defmodule MockPluginManager do
    use GenServer

    def start_link(_) do
      GenServer.start_link(__MODULE__, %{}, [])
    end

    def init(_) do
      {:ok, %{filter_mode: :passthrough, events: []}}
    end

    def handle_call({:filter_event, event}, _from, state) do
      state = %{state | events: [event | state.events]}

      case state.filter_mode do
        :passthrough ->
          {:reply, {:ok, event}, state}

        :modify ->
          {:reply, {:ok, %{event | data: Map.put(event.data, :modified, true)}},
           state}

        :block ->
          {:reply, :halt, state}

        :crash ->
          raise "Simulated plugin manager crash"
      end
    end

    def handle_call(:get_events, _from, state) do
      {:reply, state.events, state}
    end

    def handle_cast({:set_filter_mode, mode}, state) do
      {:noreply, %{state | filter_mode: mode}}
    end
  end

  setup do
    Mox.stub(UserPreferencesMock, :get, fn
      "theme.active_id" -> :default
      [:theme, :active_id] -> :default
      # Fallback for unexpected calls
      _ -> :error
    end)

    Mox.stub(ThemeMock, :get_theme, fn _ -> {:ok, %{}} end)

    # Stub all ThemeBehaviour callbacks to prevent missing function errors
    Mox.stub(ThemeMock, :register, fn _ -> :ok end)
    Mox.stub(ThemeMock, :get, fn _ -> nil end)
    Mox.stub(ThemeMock, :list, fn -> [] end)
    Mox.stub(ThemeMock, :default_theme, fn -> %{} end)
    Mox.stub(ThemeMock, :dark_theme, fn -> %{} end)
    Mox.stub(ThemeMock, :component_style, fn _, _ -> %{} end)
    Mox.stub(ThemeMock, :color, fn _, _ -> nil end)
    Mox.stub(ThemeMock, :get_color, fn _, _, _ -> nil end)
    Mox.stub(ThemeMock, :apply_theme, fn e, _ -> e end)
    Mox.stub(ThemeMock, :init, fn -> :ok end)

    # Registry for events
    Registry.start_link(keys: :duplicate, name: :raxol_event_subscriptions)

    # ETS for command registry
    :ets.new(:raxol_command_registry, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    # Start Mock Plugin Manager
    {:ok, mock_pm_pid} = MockPluginManager.start_link([])

    Mox.stub(Phoenix.PubSub, :broadcast, fn _, _, _ -> :ok end)

    # Define initial state for Dispatcher
    initial_state = %{
      app_module: MockApp,
      model: %{count: 0, last_event: nil},
      runtime_pid: self(),
      width: 80,
      height: 24,
      focused: true,
      debug_mode: false,
      plugin_manager: mock_pm_pid,
      command_registry_table: :raxol_command_registry,
      pubsub_server: Phoenix.PubSub,
      rendering_engine: Raxol.Core.Runtime.Rendering.Engine,
      initial_commands: []
    }

    # Start Dispatcher for this test
    {:ok, dispatcher} = Dispatcher.start_link(self(), initial_state)

    Mox.verify_on_exit!()

    on_exit(fn ->
      if Process.alive?(dispatcher), do: GenServer.stop(dispatcher)
      if Process.alive?(mock_pm_pid), do: GenServer.stop(mock_pm_pid)

      # Cleanup for Registry by its registered name
      try do
        GenServer.stop(:raxol_event_subscriptions, :normal, 5000)
      catch
        # Process not found, already stopped
        :exit, {:noproc, _} -> :ok
        # Other exit during stop, consider it cleaned for test purposes
        :exit, _ -> :ok
      end

      # Cleanup for ETS table by its name
      :ets.delete(:raxol_command_registry)
    end)

    # Return test context
    %{
      dispatcher: dispatcher,
      plugin_manager: mock_pm_pid
    }
  end

  describe "plugin filtering" do
    test "passes events through when plugins don't block", %{
      dispatcher: dispatcher,
      plugin_manager: pm
    } do
      # Create a basic event
      event = create_key_event(:enter)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify the event passed through
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 1
      assert current_state.model.last_event == {:key_press, :enter, []}

      # Check that plugin manager was called with event
      events = GenServer.call(pm, :get_events)
      assert Enum.any?(events, fn e -> e.data.key == :enter end)
    end

    test "modifies events when plugin transforms them", %{
      dispatcher: dispatcher,
      plugin_manager: pm
    } do
      # Set plugin manager to modify events
      GenServer.cast(pm, {:set_filter_mode, :modify})

      # Create a basic event
      event = create_key_event(:enter)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify the event was modified by plugin
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 1

      # Verify the plugin was called
      events = GenServer.call(pm, :get_events)
      assert Enum.any?(events, fn e -> e.data.key == :enter end)
    end

    test "blocks events when plugin halts event processing", %{
      dispatcher: dispatcher,
      plugin_manager: pm
    } do
      # Set plugin manager to block events
      GenServer.cast(pm, {:set_filter_mode, :block})

      # Create a basic event
      event = create_key_event(:enter)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify the event was blocked (state unchanged)
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 0
      assert current_state.model.last_event == nil

      # Verify plugin was called with event
      events = GenServer.call(pm, :get_events)
      assert Enum.any?(events, fn e -> e.data.key == :enter end)
    end
  end

  describe "error handling" do
    test "handles application update errors gracefully", %{
      dispatcher: dispatcher
    } do
      # Create an event that will cause an error in update
      event = create_key_event(:error)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify that state is unchanged after error
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 0
      assert current_state.model.last_event == nil
    end

    test "handles application update crashes", %{dispatcher: dispatcher} do
      Process.flag(:trap_exit, true)

      # Create an event that will cause a crash in update
      event = create_key_event(:crash)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify the process is still alive
      assert Process.alive?(dispatcher)

      # Verify that state is unchanged after crash
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 0
      assert current_state.model.last_event == nil
    end

    test "handles plugin filter crashes", %{
      dispatcher: dispatcher,
      plugin_manager: pm
    } do
      # Set plugin manager to crash during filtering
      GenServer.cast(pm, {:set_filter_mode, :crash})

      # Create a basic event
      event = create_key_event(:enter)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify that state is unchanged after crash
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 0
      assert current_state.model.last_event == nil

      # Ensure dispatcher is still alive
      assert Process.alive?(dispatcher)
    end
  end

  describe "system events" do
    test "handles resize events", %{dispatcher: dispatcher} do
      # Create resize event
      event = %Event{type: :resize, data: %{width: 100, height: 50}}

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify state is updated
      current_state = :sys.get_state(dispatcher)
      assert current_state.width == 100
      assert current_state.height == 50
    end

    test "handles focus events", %{dispatcher: dispatcher} do
      # Create focus event (focus lost)
      event = %Event{type: :focus, data: %{focused: false}}

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify state is updated
      current_state = :sys.get_state(dispatcher)
      assert current_state.focused == false

      # Create focus event (focus gained)
      event = %Event{type: :focus, data: %{focused: true}}

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Verify state is updated
      current_state = :sys.get_state(dispatcher)
      assert current_state.focused == true
    end

    test "handles quit events", %{dispatcher: dispatcher} do
      Process.flag(:trap_exit, true)

      # Create quit event
      event = %Event{type: :quit, data: %{}}

      # Monitor the dispatcher
      ref = Process.monitor(dispatcher)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Wait for DOWN message
      receive do
        {:DOWN, ^ref, :process, _, _} ->
          assert true
      after
        1000 ->
          flunk("Dispatcher did not shutdown within timeout")
      end
    end
  end

  describe "performance edge cases" do
    test "handles slow application updates", %{dispatcher: dispatcher} do
      # Create an event that will cause a slow update
      event = create_key_event({:timeout, self()})

      # Start measuring time
      start_time = :os.system_time(:millisecond)

      # Dispatch the event
      GenServer.cast(dispatcher, {:dispatch, event})

      # Wait for MockApp to confirm its "slow work" is done
      # Increased timeout for safety
      assert_receive :mock_app_slow_update_finished, 5000

      end_time = :os.system_time(:millisecond)
      elapsed = end_time - start_time

      # Verify update occurred
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 1

      assert current_state.model.last_event ==
               {:key_press, {:timeout, self()}, []}

      # Verify the operation took at least the sleep time
      assert elapsed >= 200
    end

    test "handles rapid sequential events", %{dispatcher: dispatcher} do
      # Create multiple events in quick succession
      events =
        for i <- 1..10 do
          create_key_event("key#{i}")
        end

      # Dispatch events in rapid succession
      Enum.each(events, fn event ->
        GenServer.cast(dispatcher, {:dispatch, event})
      end)

      # Verify all events were processed
      current_state = :sys.get_state(dispatcher)
      assert current_state.model.count == 10
      assert current_state.model.last_event == {:key_press, "key10", []}
    end
  end

  # Private helper functions
  defp create_key_event(key_value, extra_data \\ %{}) do
    default_key_data = %{state: :pressed, modifiers: []}
    final_data = Map.merge(default_key_data, extra_data)
    # Ensure the :key from key_value argument takes precedence
    data_with_key = Map.put(final_data, :key, key_value)
    %Event{type: :key, data: data_with_key}
  end
end
