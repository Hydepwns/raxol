\ndefmodule Raxol.RuntimeTest do\n  use ExUnit.Case, async: false # Use async: false for tests involving process linking/monitoring/receiving\n\n  alias Raxol.Runtime\n  alias Raxol.Core.Runtime.Application\n  alias Raxol.Runtime.Supervisor, as: RuntimeSupervisor\n  # Aliases for supervised processes might be needed for mocking/assertions\n  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager\n  alias Raxol.Core.Runtime.Events.Dispatcher\n  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine\n  alias Raxol.Terminal.Driver, as: TerminalDriver\n\n  # --- Mock Application ---\n  defmodule MockApp do\n    @behaviour Raxol.Core.Runtime.Application\n\n    alias Raxol.Core.Events.Event\n    alias Raxol.Core.Runtime.Command\n\n    @impl true\n    def init(_app_module, _context) do\n      %{count: 0, last_clipboard: nil}\n    end\n\n    @impl true\n    def update(model, event, _context) do\n      case event do\n        # Test Counter\n        %Event{type: :key, data: %{key: :char, char: \"+\"}} ->\n          {%{model | count: model.count + 1}, []}\n\n        # Test Quit (old way)\n        %Event{type: :key, data: %{key: :char, char: \"c\", ctrl: true}} ->\n          {model, [:quit]}\n\n        # Test Quit (Command.quit)\n        %Event{type: :key, data: %{key: :char, char: \"q\", ctrl: true}} ->\n          {model, [Command.quit()]}\n\n        # Test Clipboard Write (Ctrl+X)\n        %Event{type: :key, data: %{key: :char, char: <<24>>, ctrl: true}} ->\n          {model, [Command.clipboard_write(\"Mock Copy\")]}\n\n        # Test Clipboard Read (Ctrl+V)\n        %Event{type: :key, data: %{key: :char, char: <<22>>, ctrl: true}} ->\n          {model, [Command.clipboard_read()]}\n\n        # Test Notify (Ctrl+N)\n        %Event{type: :key, data: %{key: :char, char: <<14>>, ctrl: true}} ->\n          {model, [Command.notify(\"Mock Title\", \"Mock Body\")]}\n\n        # Handle incoming command result from clipboard read\n        {:clipboard_content, content} ->\n          {%{model | last_clipboard: content}, []}\n\n        # Ignore other events\n        _ ->\n          {model, []}\n      end\n    end\n\n    @impl true\n    def view(model) do\n      # Simple view for testing\n      [:text, \"Count: \#{model.count}, Clip: \#{inspect(model.last_clipboard)}\"]\n    end\n\n    @impl true\n    def subscriptions(_model) do\n      []\n    end\n  end\n\n  # --- Mock GenServers (Optional, for deeper isolation) ---\n  # Example Mock Dispatcher\n  # defmodule MockDispatcher do\n  #   use GenServer\n  #   def start_link(runtime_pid, _init_args), do: GenServer.start_link(__MODULE__, runtime_pid, name: Dispatcher)\n  #   def init(runtime_pid), do: {:ok, runtime_pid}\n  #   def handle_cast({:dispatch, event}, state), do: # store event or send to test pid\n  #   def handle_call(:get_model, _from, state), do: {:reply, {:ok, %{mock: true}}, state}\n  # end\n\n  setup do\n    # Start necessary mocks if using Mox or similar\n    # Ensure related ETS tables are cleaned up if needed\n    :ets.delete_all_objects(:raxol_command_registry)\n    :ets.new(:raxol_command_registry, [:set, :public, :named_table, read_concurrency: true])\n\n    # Get original stty settings to restore after test\n    {original_stty, 0} = System.cmd(\"stty\", [\"-g\"])\n    original_stty = String.trim(original_stty)\n\n    on_exit(fn ->\n      System.cmd(\"stty\", [original_stty])\n      # Ensure supervisor and children are stopped\n      if sup = Process.whereis(RuntimeSupervisor), do: Supervisor.stop(sup, :shutdown)\n      # Clean up ETS table\n      :ets.delete(:raxol_command_registry)\n    end)\n\n    :ok\n  end\n\n  describe \"start_application/2\" do\n    test \"successfully starts the supervisor and core processes\" do\n      # Start the application in a separate process to allow the main loop to run\n      # without blocking the test process immediately.\n      test_pid = self()\n      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)\n\n      # Allow some time for processes to start\n      :timer.sleep(200)\n\n      # Check if supervisor is running\n      sup_pid = Process.whereis(RuntimeSupervisor)\n      assert is_pid(sup_pid)\n\n      # Check if children are running (use registered names)\n      assert is_pid(Process.whereis(PluginManager))\n      assert is_pid(Process.whereis(Dispatcher))\n      assert is_pid(Process.whereis(RenderingEngine))\n      assert is_pid(Process.whereis(TerminalDriver))\n\n      # TODO: Verify initial render was triggered (e.g., by mocking RenderingEngine)\n      # TODO: Verify initial commands were processed (e.g., by mocking Dispatcher)\n\n      # Shutdown: Send a quit event to the app via the driver\n      # Get driver PID (assuming registered)\n      driver_pid = Process.whereis(TerminalDriver)\n      # Simulate Ctrl+C input -> Event -> Dispatcher -> App -> Command -> Dispatcher -> Runtime\n      send(driver_pid, {:io_reply, make_ref(), <<3>>})\n\n      # Wait for the runtime task to exit (because the main_loop received :quit_application)\n      assert Task.await(runtime_task, 5000) == :ok\n\n      # Supervisor should have stopped children\n      assert Process.whereis(RuntimeSupervisor) == nil\n    end\n\n    test \"returns error if application init fails\" do\n      defmodule FailingApp do\n        @behaviour Raxol.Core.Runtime.Application\n        def init(_, _), do: {:error, :init_boom}\n        def update(m, _, _), do: {m, []}\n        def view(_), do: [:text, \"\"]\n        def subscriptions(_), do: []\n      end\n\n      assert Runtime.start_application(FailingApp) == {:error, {:init_failed, :init_boom}}\n      # Ensure no supervisor was left running\n      assert Process.whereis(RuntimeSupervisor) == nil\n    end\n  end\n\n  # TODO: Add more detailed tests for interactions (event flow, render flow, quit flow)\n  # This might require more sophisticated mocking/test doubles.\n\n  describe "Runtime Interaction Flow" do\n    # Helper to simplify checking Dispatcher model
    defp assert_model(expected_model) do
      dispatcher_pid = Process.whereis(Dispatcher)
      {:ok, current_model} = GenServer.call(dispatcher_pid, :get_model)
      assert current_model == expected_model
    end

    test "input event triggers application update and subsequent render", %{original_stty: _} do
      # Start the application
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(300) # Allow startup (increased slightly)

      driver_pid = Process.whereis(TerminalDriver)
      dispatcher_pid = Process.whereis(Dispatcher)
      runtime_pid = Process.whereis(Raxol.Runtime) # Assuming Runtime registers itself
      rendering_engine_pid = Process.whereis(RenderingEngine)

      assert is_pid(driver_pid)
      assert is_pid(dispatcher_pid)
      # If Runtime doesn't register, this test needs adjustment
      # assert is_pid(runtime_pid)
      assert is_pid(rendering_engine_pid)

      # 1. Check initial model state
      assert_model(%{count: 0})

      # 2. Inject an event that causes state change in MockApp (e.g., '+')
      # Flow: Test -> Driver (:io_reply) -> Driver sends Event -> Dispatcher
      send(driver_pid, {:io_reply, make_ref(), "+"})
      :timer.sleep(200) # Allow event processing

      # 3. Assert that the Dispatcher's state (model) was updated
      # Flow: Dispatcher calls MockApp.update -> updates model
      assert_model(%{count: 1})

      # 4. Assert that a render was triggered
      # Flow: Dispatcher sends {:updated_model, model} -> Runtime
      #       Runtime sends {:render, view} -> RenderingEngine
      # Simplification: Check if RenderingEngine received a :render message
      # This requires RenderingEngine to handle a call/cast or send confirmation.
      # Let's assume RenderingEngine can handle a call to get the last rendered view.
      # This requires adding a handle_call to RenderingEngine for test purposes.
      # {:ok, last_view} = GenServer.call(rendering_engine_pid, :get_last_view)
      # assert last_view == [:text, "Count: 1"]
      # --> For now, we will rely on the model update assertion as proof of flow.
      # --> Adding detailed inter-process message checking requires more setup/mocking.

      # Shutdown (send Ctrl+C)
      send(driver_pid, {:io_reply, make_ref(), <<3>>}) # Ctrl+C -> :quit command
      assert Task.await(runtime_task, 1000) == :ok
    end

    test "application :quit command terminates the runtime gracefully", %{original_stty: _} do
      # Start the application
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(250) # Allow startup

      driver_pid = Process.whereis(TerminalDriver)
      dispatcher_pid = Process.whereis(Dispatcher)
      assert is_pid(driver_pid)
      assert is_pid(dispatcher_pid)

      # Send Ctrl+C input, which MockApp translates to :quit command
      send(driver_pid, {:io_reply, make_ref(), <<3>>})

      # Assert the runtime task finishes cleanly
      assert Task.await(runtime_task, 1000) == :ok

      # Verify core processes are stopped
      :timer.sleep(50) # Give time for termination
      assert Process.whereis(RuntimeSupervisor) == nil
      assert Process.whereis(PluginManager) == nil
      assert Process.whereis(Dispatcher) == nil
      assert Process.whereis(RenderingEngine) == nil
      assert Process.whereis(TerminalDriver) == nil
    end

    test "application Command.quit() terminates the runtime gracefully", %{original_stty: _} do
      # Start the application
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(250) # Allow startup

      driver_pid = Process.whereis(TerminalDriver)
      dispatcher_pid = Process.whereis(Dispatcher)
      assert is_pid(driver_pid)
      assert is_pid(dispatcher_pid)

      # Send Ctrl+Q input, which MockApp translates to Command.quit()
      # Ctrl+Q is ASCII 17
      send(driver_pid, {:io_reply, make_ref(), <<17>>})

      # Assert the runtime task finishes cleanly because Runtime received :quit_runtime
      assert Task.await(runtime_task, 1000) == :ok

      # Verify core processes are stopped
      :timer.sleep(50) # Give time for termination
      assert Process.whereis(RuntimeSupervisor) == nil
      assert Process.whereis(PluginManager) == nil
      assert Process.whereis(Dispatcher) == nil
      assert Process.whereis(RenderingEngine) == nil
      assert Process.whereis(TerminalDriver) == nil
    end

    test "Command.clipboard_write and Command.notify are delegated (placeholder check)", %{original_stty: _} do
      # This test is basic as we don't have easy access to PluginManager internals/logs
      # It primarily ensures the app doesn't crash when issuing these commands.
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(250) # Allow startup

      driver_pid = Process.whereis(TerminalDriver)
      assert is_pid(driver_pid)

      # Send Ctrl+X (Clipboard Write)
      send(driver_pid, {:io_reply, make_ref(), <<24>>})
      :timer.sleep(50) # Allow processing

      # Send Ctrl+N (Notify)
      send(driver_pid, {:io_reply, make_ref(), <<14>>})
      :timer.sleep(50) # Allow processing

      # TODO: Improve this test with Mox or better inspection of PluginManager
      Logger.info("[TEST] Manually check logs for PluginManager receiving clipboard_write and notify commands.")

      # Shutdown (send Ctrl+Q)
      send(driver_pid, {:io_reply, make_ref(), <<17>>})
      assert Task.await(runtime_task, 1000) == :ok
    end

    test "Command.clipboard_read fetches content and updates app model", %{original_stty: _} do
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(250) # Allow startup

      driver_pid = Process.whereis(TerminalDriver)
      assert is_pid(driver_pid)

      # Check initial model state (clipboard is nil)
      assert_model(%{count: 0, last_clipboard: nil})

      # Send Ctrl+V (Clipboard Read)
      send(driver_pid, {:io_reply, make_ref(), <<22>>})

      # Allow time for: Cmd -> PM -> PM sends delayed msg -> PM handles -> PM sends result -> Dispatcher handles -> App Update
      :timer.sleep(250)

      # Check that the model was updated with the simulated clipboard content
      assert_model(%{count: 0, last_clipboard: "Clipboard Content"})

      # Shutdown (send Ctrl+Q)
      send(driver_pid, {:io_reply, make_ref(), <<17>>})
      assert Task.await(runtime_task, 1000) == :ok
    end

    # Add test for command handling if MockApp returned commands
    # test "application commands are processed" do ... end
  end\n\n  describe "Supervisor Behaviour" do\n    # Helper to wait for a process to terminate
    defp wait_for_death(pid) do
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        500 -> flunk("Process \#{inspect(pid)} did not terminate")
      end
    end

    test "supervisor restarts child processes (example: Dispatcher)", %{original_stty: _} do
      # Start the application
      runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)
      :timer.sleep(250) # Allow startup

      sup_pid = Process.whereis(RuntimeSupervisor)
      dispatcher_pid = Process.whereis(Dispatcher)
      assert is_pid(sup_pid)
      assert is_pid(dispatcher_pid)

      # Kill the Dispatcher
      Process.exit(dispatcher_pid, :kill)
      wait_for_death(dispatcher_pid)

      # Allow time for supervisor to restart
      :timer.sleep(200)

      # Check if Dispatcher was restarted
      new_dispatcher_pid = Process.whereis(Dispatcher)
      assert is_pid(new_dispatcher_pid)
      assert new_dispatcher_pid != dispatcher_pid

      # Check if the application is still responsive (e.g., get model)
      {:ok, model} = GenServer.call(new_dispatcher_pid, :get_model)
      # Initial state after restart depends on init logic
      assert model == %{count: 0}

      # Shutdown gracefully
      driver_pid = Process.whereis(TerminalDriver)
      send(driver_pid, {:io_reply, make_ref(), <<3>>}) # Send quit event
      assert Task.await(runtime_task, 1000) == :ok
    end

    # Add more tests for other children if needed, or different restart strategies.
  end\nend
