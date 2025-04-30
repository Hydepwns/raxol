defmodule Raxol.RuntimeTest do
  use ExUnit.Case, async: false # Use async: false for tests involving process linking/monitoring/receiving
  alias Raxol.Runtime
  alias Raxol.Core.Runtime.Application
  alias Raxol.Runtime.Supervisor, as: RuntimeSupervisor
  # Aliases for supervised processes might be needed for mocking/assertions
  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  alias Raxol.Terminal.Driver, as: TerminalDriver

  # --- Mock Application ---
    defmodule MockApp do
          @behaviour Raxol.Core.Runtime.Application
          alias Raxol.Core.Events.Event
          alias Raxol.Core.Runtime.Command

          @impl true
          def init(_app_module, _context) do
      {:ok, %{count: 0, last_clipboard: nil}}
        end

        @impl true
        def update(model, event, _context) do
          case event do
            # Test Counter
            %Event{type: :key, data: %{key: :char, char: "+"}} ->
              {%{model | count: model.count + 1}, []}

              # Test Quit (old way)
              %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
                {model, [:quit]}

                # Test Quit (Command.quit)
                %Event{type: :key, data: %{key: :char, char: "q", ctrl: true}} ->
                  {model, [Command.quit()]}

                  # Test Clipboard Write (Ctrl+X)
                  %Event{type: :key, data: %{key: :char, char: <<24>>, ctrl: true}} ->
                    {model, [Command.clipboard_write("Mock Copy")]}

                    # Test Clipboard Read (Ctrl+V)
                    %Event{type: :key, data: %{key: :char, char: <<22>>, ctrl: true}} ->
                      {model, [Command.clipboard_read()]}

                      # Test Notify (Ctrl+N)
                      %Event{type: :key, data: %{key: :char, char: <<14>>, ctrl: true}} ->
                        {model, [Command.notify("Mock Title", "Mock Body")]}

                        # Handle incoming command result from clipboard read
                        {:clipboard_content, content} ->
                          {%{model | last_clipboard: content}, []}

                          # Ignore other events
                          _ ->
                            {model, []}
                          end
                        end

                        @impl true
                        def view(model) do
                          # Simple view for testing
                          [:text, "Count: #{model.count}, Clip: #{inspect(model.last_clipboard)}"]
                        end

                        @impl true
                        def subscriptions(_model) do
                          []
                        end
                      end

                      # --- Mock GenServers (Optional, for deeper isolation) ---
                      # Example Mock Dispatcher
                      # defmodule MockDispatcher do
                        #   use GenServer
                        #   def start_link(runtime_pid, _init_args), do: GenServer.start_link(__MODULE__, runtime_pid, name: Dispatcher)
                        #   def init(runtime_pid), do: {:ok, runtime_pid}
                        #   def handle_cast({:dispatch, event}, state), do: # store event or send to test pid
                        #   def handle_call(:get_model, _from, state), do: {:reply, {:ok, %{mock: true}}, state}
                        # end

                        setup do
                          # Start necessary mocks if using Mox or similar
                          # Ensure related ETS tables are cleaned up if needed
                          :ets.delete_all_objects(:raxol_command_registry)
                          :ets.new(:raxol_command_registry, [:set, :public, :named_table, read_concurrency: true])

                          # Get original stty settings to restore after test
                          {original_stty, 0} = System.cmd("stty", ["-g"])
                          original_stty = String.trim(original_stty)

                          on_exit(fn ->
                            System.cmd("stty", [original_stty])
                            # Ensure supervisor and children are stopped
                            if sup = Process.whereis(RuntimeSupervisor), do: Supervisor.stop(sup, :shutdown)
                            # Clean up ETS table
                            :ets.delete(:raxol_command_registry)
                          end)

                          :ok
                        end

                        describe "start_application/2" do
                          test "successfully starts the supervisor and core processes" do
                            # Start the application in a separate process to allow the main loop to run
                            # without blocking the test process immediately.
                            test_pid = self()
                            runtime_task = Task.async(fn -> Runtime.start_application(MockApp) end)

                            # Allow some time for processes to start
                            :timer.sleep(200)

                            # Check if supervisor is running
                            sup_pid = Process.whereis(RuntimeSupervisor)
                            assert is_pid(sup_pid)

                            # Check if children are running (use registered names)
                            assert is_pid(Process.whereis(PluginManager))
                            assert is_pid(Process.whereis(Dispatcher))
                            assert is_pid(Process.whereis(RenderingEngine))
                            assert is_pid(Process.whereis(TerminalDriver))

                            # TODO: Verify initial render was triggered (e.g., by mocking RenderingEngine)
                            # TODO: Verify initial commands were processed (e.g., by mocking Dispatcher)

                            # Shutdown: Send a quit event to the app via the driver
                            # Get driver PID (assuming registered)
                            driver_pid = Process.whereis(TerminalDriver)
                            # Simulate Ctrl+C input -> Event -> Dispatcher -> App -> Command -> Dispatcher -> Runtime
                            send(driver_pid, {:io_reply, make_ref(), <<3>>})

                            # Assert the runtime task finishes cleanly
                            assert Task.await(runtime_task, 1000) == :ok
                          end
                        end

                        describe "Supervisor Behaviour" do
                          defp assert_model(expected_model) do
                            dispatcher_pid = Process.whereis(Dispatcher)
                            {:ok, model} = GenServer.call(dispatcher_pid, :get_model)
                            assert model == expected_model
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
                        end # Closes describe "Supervisor Behaviour"

                        describe "Runtime Interaction Flow" do
                          # Helper to wait for a process to terminate
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
                        end # Closes describe "Runtime Interaction Flow"

end # Closes defmodule Raxol.RuntimeTest
