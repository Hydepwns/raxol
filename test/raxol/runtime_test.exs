defmodule Raxol.RuntimeTest do
  use ExUnit.Case, async: false # Use async: false for tests involving process linking/monitoring/receiving
  require Logger # Add require for Logger
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
                          # Ensure ETS table is clean and exists before each test
                          try do
                            :ets.delete(:raxol_command_registry)
                          rescue
                            ArgumentError -> :ok # Ignore if table doesn't exist
                          end
                          :ets.new(:raxol_command_registry, [:set, :public, :named_table, read_concurrency: true])

                          # Get original stty settings to restore after test, handle potential errors
                          original_stty =
                            case System.cmd("stty", ["-g"]) do
                              {output, 0} ->
                                String.trim(output)
                              {_error_output, exit_code} ->
                                Logger.warning("Failed to get original stty settings (exit code: #{exit_code}). Tests may not restore tty correctly.")
                                nil # Or use a safe default if restoration is critical and possible
                            end

                          # Start the supervisor directly for testing
                          init_args = %{
                            app_module: MockApp,
                            initial_model: %{count: 0, last_clipboard: nil}, # Match MockApp.init
                            initial_commands: [],
                            initial_term_size: %{width: 80, height: 24},
                            runtime_pid: self() # Use test process PID as placeholder
                          }
                          {:ok, sup_pid} = Supervisor.start_link(RuntimeSupervisor, init_args)
                          # Ensure supervisor is linked so it terminates with the test
                          # Process.link(sup_pid) # Already linked via start_link

                          on_exit(fn ->
                            if original_stty do
                              System.cmd("stty", [original_stty])
                            end
                            # Ensure supervisor and children are stopped
                            # Check if supervisor is alive before trying to stop
                            if Process.alive?(sup_pid), do: Supervisor.stop(sup_pid, :shutdown, :infinity)
                            # Clean up ETS table after test
                            try do
                               :ets.delete(:raxol_command_registry)
                             rescue
                               ArgumentError -> :ok # Ignore if already deleted
                             end
                          end)

                          # Pass supervisor PID to tests if needed, though using registered names is preferred
                          {:ok, sup_pid: sup_pid, original_stty: original_stty}
                        end

                        # --- Tests ---
                        # Note: Removed describe blocks for clarity, can be added back if preferred

                        test "successfully starts the supervisor and core processes", %{sup_pid: sup_pid} do
                          # Check if supervisor is running (redundant, start_link succeeded)
                          assert is_pid(sup_pid)

                          # Allow some time for children to start
                          :timer.sleep(100)

                          # Check if children are running (use registered names)
                          assert is_pid(Process.whereis(PluginManager))
                          assert is_pid(Process.whereis(Dispatcher))
                          assert is_pid(Process.whereis(RenderingEngine))
                          assert is_pid(Process.whereis(TerminalDriver))
                          assert is_pid(Process.whereis(Raxol.Core.UserPreferences)) # Check added child

                          # TODO: Verify initial render/commands
                        end

                        # Helper for asserting model state via Dispatcher
                        defp assert_model(expected_model) do
                          dispatcher_pid = Process.whereis(Dispatcher)
                          assert is_pid(dispatcher_pid), "Dispatcher not running"
                          # Use a timeout for the call
                          case GenServer.call(dispatcher_pid, :get_model, 500) do
                            {:ok, model} -> assert model == expected_model
                            other -> flunk("Failed to get model from Dispatcher: #{inspect(other)}")
                          end
                        end

                        test "input event triggers application update", %{sup_pid: _sup_pid} do
                          # Allow startup
                          :timer.sleep(100)

                          driver_pid = Process.whereis(TerminalDriver)
                          assert is_pid(driver_pid), "TerminalDriver not running"

                          # Check initial model state
                          assert_model(%{count: 0, last_clipboard: nil})

                          # Inject an event ('+')
                          send(driver_pid, {:io_reply, make_ref(), "+"})
                          :timer.sleep(100) # Allow event processing

                          # Assert model was updated
                          assert_model(%{count: 1, last_clipboard: nil})

                          # TODO: Assert render was triggered (requires RenderingEngine mock/spy)
                        end

                        test "application Command.quit() terminates the runtime gracefully", %{sup_pid: sup_pid} do
                          # Allow startup
                          :timer.sleep(100)

                          driver_pid = Process.whereis(TerminalDriver)
                          assert is_pid(driver_pid), "TerminalDriver not running"

                          # Monitor supervisor before sending quit command
                          ref = Process.monitor(sup_pid)

                          # Send Ctrl+Q input (ASCII 17) -> MockApp -> Command.quit()
                          send(driver_pid, {:io_reply, make_ref(), <<17>>})

                          # Assert the supervisor terminates
                          receive do
                            {:DOWN, ^ref, :process, ^sup_pid, :shutdown} -> :ok # Normal shutdown
                            {:DOWN, ^ref, :process, ^sup_pid, reason} -> flunk("Supervisor terminated unexpectedly: #{inspect reason}")
                          after
                            1000 -> flunk("Supervisor did not terminate within 1 second")
                          end

                          # Verify core processes are stopped (slight delay for safety)
                          :timer.sleep(50)
                          assert Process.whereis(RuntimeSupervisor) == nil
                          assert Process.whereis(PluginManager) == nil
                          assert Process.whereis(Dispatcher) == nil
                          assert Process.whereis(RenderingEngine) == nil
                          assert Process.whereis(TerminalDriver) == nil
                        end

                        test "Command.clipboard_write and Command.notify are delegated", %{sup_pid: _sup_pid} do
                          # Allow startup
                          :timer.sleep(100)
                          driver_pid = Process.whereis(TerminalDriver)
                          assert is_pid(driver_pid), "TerminalDriver not running"

                          # Send Ctrl+X (Clipboard Write)
                          send(driver_pid, {:io_reply, make_ref(), <<24>>})
                          :timer.sleep(50) # Allow processing

                          # Send Ctrl+N (Notify)
                          send(driver_pid, {:io_reply, make_ref(), <<14>>})
                          :timer.sleep(50) # Allow processing

                          # Basic check: ensure supervisor didn't crash
                          assert Process.alive?(Process.whereis(RuntimeSupervisor))

                          # TODO: Improve with PluginManager spy/mock
                        end

                        test "Command.clipboard_read fetches content and updates app model", %{sup_pid: _sup_pid} do
                          # Allow startup
                          :timer.sleep(100)
                          driver_pid = Process.whereis(TerminalDriver)
                          assert is_pid(driver_pid), "TerminalDriver not running"

                          # Check initial model state
                          assert_model(%{count: 0, last_clipboard: nil})

                          # Mock Raxol.System.Clipboard.paste/0 using :meck
                          :meck.expect(Raxol.System.Clipboard, :paste, fn -> {:ok, "Test Clipboard Content"} end)

                          # Send Ctrl+V (Clipboard Read)
                          send(driver_pid, {:io_reply, make_ref(), <<22>>})

                          # Allow time for event processing & command result
                          :timer.sleep(200)

                          # Check model was updated
                          assert_model(%{count: 0, last_clipboard: "Test Clipboard Content"})

                          # Validate mock was called
                          assert :meck.validate(Raxol.System.Clipboard)
                          :meck.unload(Raxol.System.Clipboard) # Unload mock for this test
                        end

                        # Helper to wait for a process to terminate
                        defp wait_for_death(pid) do
                          ref = Process.monitor(pid)
                          receive do
                            {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
                          after
                            500 -> flunk("Process #{inspect(pid)} did not terminate")
                          end
                        end

                        test "supervisor restarts child processes (example: Dispatcher)", %{sup_pid: sup_pid} do
                          # Allow startup
                          :timer.sleep(100)

                          assert is_pid(sup_pid)
                          dispatcher_pid = Process.whereis(Dispatcher)
                          assert is_pid(dispatcher_pid)

                          # Monitor Dispatcher before killing
                          ref = Process.monitor(dispatcher_pid)

                          # Kill the Dispatcher
                          Process.exit(dispatcher_pid, :kill)

                          # Wait for DOWN message
                          receive do
                            {:DOWN, ^ref, :process, ^dispatcher_pid, :killed} -> :ok
                          after
                            500 -> flunk("Did not receive DOWN message for Dispatcher")
                          end

                          # Allow time for supervisor to restart
                          :timer.sleep(200)

                          # Check if Dispatcher was restarted
                          new_dispatcher_pid = Process.whereis(Dispatcher)
                          assert is_pid(new_dispatcher_pid)
                          assert new_dispatcher_pid != dispatcher_pid

                          # Check if the application is still responsive (e.g., get model)
                          assert_model(%{count: 0, last_clipboard: nil}) # Initial state after restart
                        end
                      end
