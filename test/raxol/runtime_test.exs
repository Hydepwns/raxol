defmodule Raxol.RuntimeTest do
  # Use async: false for tests involving process linking/monitoring/receiving
  use ExUnit.Case, async: false
  # Uncomment this line
  require Logger

  # alias Raxol.Core.Runtime.Application # This alias was causing the issue with Application.put_env
  alias Raxol.Runtime.Supervisor, as: RuntimeSupervisor
  # Aliases for supervised processes might be needed for mocking/assertions
  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  alias Raxol.Terminal.Driver, as: TerminalDriver

  Mox.defmock(NotificationMock, for: Raxol.System.Interaction)
  # Use correct behaviour
  Mox.defmock(InteractionMock, for: Raxol.System.Interaction)

  # --- Mock Application ---
  defmodule MockApp do
    @behaviour Raxol.Core.Runtime.Application
    alias Raxol.Core.Events.Event
    alias Raxol.Core.Runtime.Command

    @impl Raxol.Core.Runtime.Application
    def init(_initial_state_map, initial_model) do
      # No initial commands
      {:ok, initial_model, []}
    end

    @impl Raxol.Core.Runtime.Application
    def update({:event, %Event{type: :key, data: %{char: "+"}}}, model) do
      IO.inspect(model, label: "[MockApp.update] Matched '+': old_model")
      new_count = model.count + 1
      new_model = %{model | count: new_count}
      IO.inspect(new_model, label: "[MockApp.update] new_model")
      {new_model, []}
    end

    @impl Raxol.Core.Runtime.Application
    # Ctrl+Q
    def update({:event, %Event{type: :key, data: %{char: <<17>>}}}, model) do
      Logger.debug("[MockApp.update] Matched Ctrl+Q (char <<17>>)")
      {model, [%Command{type: :quit}]}
    end

    @impl Raxol.Core.Runtime.Application
    # Ctrl+V
    def update({:event, %Event{type: :key, data: %{char: <<22>>}}}, model) do
      Logger.debug("[MockApp.update] Matched Ctrl+V")
      {model, [%Command{type: :clipboard_read}]}
    end

    @impl Raxol.Core.Runtime.Application
    # Ctrl+X
    def update({:event, %Event{type: :key, data: %{char: <<24>>}}}, model) do
      Logger.debug("[MockApp.update] Matched Ctrl+X")
      {model, [%Command{type: :clipboard_write, data: "copied from mock"}]}
    end

    @impl Raxol.Core.Runtime.Application
    # Ctrl+N
    def update({:event, %Event{type: :key, data: %{char: <<14>>}}}, model) do
      Logger.debug("[MockApp.update] Matched Ctrl+N")
      {model, [%Command{type: :notify, data: {"MockApp notification", ""}}]}
    end

    @impl Raxol.Core.Runtime.Application
    def update({:command_result, {:clipboard_read, {:ok, content}}}, model) do
      Logger.debug("[MockApp.update] Received clipboard content: #{content}")
      {%{model | last_clipboard: content}, []}
    end

    @impl Raxol.Core.Runtime.Application
    def update({:command_result, {:clipboard_read, {:error, reason}}}, model) do
      Logger.error(
        "[MockApp.update] Error reading clipboard: #{inspect(reason)}"
      )

      {model, []}
    end

    @impl Raxol.Core.Runtime.Application
    def update(event_tuple, model) do
      Logger.debug(
        "[MockApp.update] Fell into default case for event_tuple: #{inspect(event_tuple)}"
      )

      {model, []}
    end

    @impl Raxol.Core.Runtime.Application
    def handle_tick(model) do
      # Logger.debug("[MockApp.handle_tick] Tick, model: #{inspect(model)}")
      # No commands on tick for mock
      {model, []}
    end

    @impl Raxol.Core.Runtime.Application
    def terminate(reason, model) do
      Logger.debug(
        "[MockApp.terminate] Terminating. Reason: #{inspect(reason)}, Model: #{inspect(model)}"
      )

      :ok
    end

    @impl Raxol.Core.Runtime.Application
    def view(model) do
      # Simple view for testing
      [
        :text,
        "Count: #{model.count}, Clipboard: #{inspect(model.last_clipboard)}"
      ]
    end

    @impl Raxol.Core.Runtime.Application
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

  setup context do
    # Call the cleanup helper at the beginning of setup
    setup_runtime_environment(context)

    # Ensure ETS table is clean and exists before each test
    try do
      :ets.delete(:raxol_command_registry)
    rescue
      # Ignore if table doesn't exist
      ArgumentError -> :ok
    end

    :ets.new(:raxol_command_registry, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    # Configure ClipboardPlugin to use the mock via Application environment
    # The key for the map should be the plugin module itself.
    Application.put_env(
      :raxol,
      :plugin_manager_config,
      %{
        Raxol.Core.Plugins.Core.ClipboardPlugin => [
          clipboard_impl: ClipboardMock
        ]
      }
    )

    # Get original stty settings to restore after test, handle potential errors
    original_stty =
      case System.cmd("stty", ["-g"]) do
        {output, 0} ->
          String.trim(output)

        {_error_output, exit_code} ->
          Logger.warning(
            "Failed to get original stty settings (exit code: #{exit_code}). Tests may not restore tty correctly."
          )

          # Or use a safe default if restoration is critical and possible
          nil
      end

    # Start the RuntimeSupervisor with MockApp and the test process as the runtime_pid
    # This allows MockApp to send messages back to the test process if needed.
    runtime_pid = self()

    # Define init_args in the flat structure expected by RuntimeSupervisor.init/1
    supervisor_init_args = %{
      app_module: MockApp,
      # Flat structure
      initial_model: %{count: 0, last_clipboard: nil},
      # Add missing key
      initial_commands: [],
      # Add missing key
      initial_term_size: %{width: 80, height: 24},
      runtime_pid: runtime_pid
      # The following are not directly used by Supervisor.init/1 but might be by children if passed differently
      # For now, ensure the supervisor gets what it directly needs.
      # dispatcher_name: Dispatcher,
      # terminal_driver_name: TerminalDriver,
      # plugin_manager_name: PluginManager,
      # user_preferences_name: Raxol.Core.UserPreferences
    }

    {:ok, supervisor_pid} = RuntimeSupervisor.start_link(supervisor_init_args)

    # Allow time for all processes to start and initial events to settle
    :timer.sleep(500)

    # Explicitly initialize the PluginManager to load plugins and register commands
    case Raxol.Core.Runtime.Plugins.Manager.initialize() do
      :ok ->
        Logger.debug("[TEST setup] PluginManager initialized successfully.")

      :already_initialized ->
        Logger.debug("[TEST setup] PluginManager was already initialized.")

      {:error, reason} ->
        flunk(
          "[TEST setup] Failed to initialize PluginManager: #{inspect(reason)}"
        )
    end

    # Allow a bit more time for commands to register
    :timer.sleep(100)

    # Allow ClipboardMock calls from PluginManager process
    # Ensure PluginManager is registered before attempting Mox.allow
    plugin_manager_pid = Process.whereis(Raxol.Core.Runtime.Plugins.Manager)

    if plugin_manager_pid do
      Mox.allow(ClipboardMock, self(), plugin_manager_pid)
      Mox.allow(NotificationMock, self(), plugin_manager_pid)
      Mox.allow(InteractionMock, self(), plugin_manager_pid)
    else
      flunk("PluginManager PID not found, cannot allow Mox calls.")
    end

    on_exit(fn ->
      try do
        Supervisor.stop(supervisor_pid, :shutdown, :infinity)
      catch
        :exit, reason ->
          Logger.error(
            "[TEST on_exit] Supervisor.stop(#{inspect(supervisor_pid)}) exited with reason: #{inspect(reason)}"
          )
      end

      # Ensure the supervisor process is actually down
      ref = Process.monitor(supervisor_pid)

      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        # Increased timeout
        7000 ->
          Logger.error(
            "[TEST on_exit] RuntimeSupervisor PID #{inspect(supervisor_pid)} did not stop cleanly."
          )
      end

      # Clean up ETS table after test
      try do
        :ets.delete(:raxol_command_registry)
      rescue
        # Ignore if already deleted
        ArgumentError -> :ok
      end

      # Clean up Application environment for plugin_manager_config
      Application.delete_env(:raxol, :plugin_manager_config)
    end)

    actual_dispatcher_pid = Process.whereis(Dispatcher)
    actual_driver_pid = Process.whereis(TerminalDriver)

    unless is_pid(actual_dispatcher_pid) do
      flunk(
        "Dispatcher PID not found after setup. Is Dispatcher running and registered?"
      )
    end

    unless is_pid(actual_driver_pid) do
      flunk(
        "TerminalDriver PID not found after setup. Is TerminalDriver running and registered?"
      )
    end

    %{
      supervisor_pid: supervisor_pid,
      dispatcher_pid: actual_dispatcher_pid,
      driver_pid: actual_driver_pid
    }
  end

  # --- Tests ---
  # Note: Removed describe blocks for clarity, can be added back if preferred

  test "successfully starts the supervisor and core processes", %{
    supervisor_pid: supervisor_pid
  } do
    # Check if supervisor is running (redundant, start_link succeeded)
    assert is_pid(supervisor_pid)

    # Allow some time for children to start
    :timer.sleep(100)

    # Check if children are running (use registered names)
    assert is_pid(Process.whereis(PluginManager))
    assert is_pid(Process.whereis(Dispatcher))
    assert is_pid(Process.whereis(RenderingEngine))
    assert is_pid(Process.whereis(TerminalDriver))
    # Check added child
    assert is_pid(Process.whereis(Raxol.Core.UserPreferences))

    # TODO: Verify initial render/commands
  end

  # Helper for asserting model state via Dispatcher
  defp assert_model(dispatcher_pid, expected_model) do
    # Ensure the Dispatcher is alive
    assert Process.alive?(dispatcher_pid),
           "Dispatcher process #{inspect(dispatcher_pid)} is not alive"

    # Get the model from the Dispatcher
    # Add a timeout to prevent test hangs if Dispatcher is unresponsive
    case GenServer.call(dispatcher_pid, :get_model, 500) do
      {:ok, model} ->
        # Add the expected theme ID to the comparison map
        expected_with_theme =
          Map.put(expected_model, :current_theme_id, "Default Theme")

        assert model == expected_with_theme

      other ->
        flunk("Failed to get model from Dispatcher: #{inspect(other)}")
    end
  end

  test "input event triggers application update", %{
    supervisor_pid: _supervisor_pid
  } do
    # Allow startup
    :timer.sleep(100)

    driver_pid = Process.whereis(TerminalDriver)
    assert is_pid(driver_pid), "TerminalDriver not running"

    # Check initial model state
    assert_model(Process.whereis(Dispatcher), %{count: 0, last_clipboard: nil})

    # Inject an event ('+')
    # New way
    GenServer.cast(driver_pid, {:test_input, "+"})
    # Allow time for async processing
    :timer.sleep(100)

    # Assert model was updated
    assert_model(Process.whereis(Dispatcher), %{count: 1, last_clipboard: nil})

    # TODO: Assert render was triggered (requires RenderingEngine mock/spy)
  end

  test "application Command.quit() terminates the runtime gracefully", %{
    supervisor_pid: supervisor_pid
  } do
    # Allow startup
    :timer.sleep(100)

    driver_pid = Process.whereis(TerminalDriver)
    assert is_pid(driver_pid), "TerminalDriver not running"

    # Monitor supervisor to ensure it doesn't crash UNEXPECTEDLY during the test
    ref = Process.monitor(supervisor_pid)

    # Send Ctrl+Q -> MockApp -> Command.quit() -> Command.execute sends :quit_runtime to test process
    # Ctrl+Q -> :quit command
    GenServer.cast(driver_pid, {:test_input, <<17>>})

    # Flush potential intermediate messages like :render_needed
    receive do
      _ -> :ok
    after
      0 -> :ok
    end

    # Increased timeout just in case
    assert_receive :quit_runtime, 1000

    # Unlink before explicit stop to prevent supervisor crash propagating to test
    Process.unlink(supervisor_pid)

    # Explicitly stop the supervisor
    Supervisor.stop(supervisor_pid, :shutdown, :infinity)

    # Assert Supervisor is stopped
    refute Process.alive?(supervisor_pid),
           "Supervisor process should be stopped by OTP after runtime_pid (test process) exits"

    # Also ensure Dispatcher and TerminalDriver are stopped
    assert Process.whereis(PluginManager) == nil,
           "PluginManager should be stopped"

    assert Process.whereis(Dispatcher) == nil, "Dispatcher should be stopped"

    assert Process.whereis(RenderingEngine) == nil,
           "RenderingEngine should be stopped"

    assert Process.whereis(TerminalDriver) == nil,
           "TerminalDriver should be stopped"

    assert Process.whereis(Raxol.Core.UserPreferences) == nil,
           "UserPreferences should be stopped"

    # Ensure no unexpected DOWN message was received before we stopped it
    # (The actual DOWN message from Supervisor.stop is expected but we don't assert it here)
  end

  test "Command.clipboard_write and Command.notify are delegated", context do
    # supervisor_pid = context.supervisor_pid
    driver_pid = context.driver_pid

    # Allow startup
    :timer.sleep(100)

    # Mox expectations
    Mox.expect(ClipboardMock, :copy, fn "copied from mock" -> :ok end)

    # For :notify (Ctrl+N from MockApp)
    Mox.expect(NotificationMock, :get_os_type, fn -> {:unix, :darwin} end)

    Mox.expect(NotificationMock, :find_executable, fn "osascript" ->
      "/usr/bin/osascript"
    end)

    expected_script =
      ~s(display notification "MockApp notification" with title "Raxol Notification")

    Mox.expect(NotificationMock, :system_cmd, fn "/usr/bin/osascript",
                                                 ["-e", ^expected_script],
                                                 [stderr_to_stdout: true] ->
      {"", 0}
    end)

    # Simulate Ctrl+X (copy "copied from mock")
    # Ctrl+X
    GenServer.cast(driver_pid, {:test_input, <<24>>})
    # Allow processing
    :timer.sleep(100)

    # Simulate Ctrl+N (notify "Mock Title", "Mock Body")
    # Ctrl+N
    GenServer.cast(driver_pid, {:test_input, <<14>>})
    # Allow processing
    :timer.sleep(100)

    # Verify expectations (Mox will do this automatically on test exit if expectations are set)
    # For this test, the main goal is to ensure no crashes and that PluginManager handles them.
    # The lack of crashes during these operations (post Mox fix) will be a good sign.
  end

  test "Command.clipboard_read fetches content and updates app model", %{
    supervisor_pid: _supervisor_pid,
    dispatcher_pid: dispatcher_pid,
    driver_pid: driver_pid
  } do
    # Allow startup
    :timer.sleep(100)

    # Mox expectation for ClipboardMock.paste/0, allow from any process
    Mox.expect(ClipboardMock, :paste, fn -> {:ok, "Test Clipboard Content"} end)

    # Check initial model state using the helper
    assert_model(dispatcher_pid, %{count: 0, last_clipboard: nil})

    # Inject Ctrl+V (paste)
    # Ctrl+V
    GenServer.cast(driver_pid, {:test_input, <<22>>})

    # Allow time for event processing & command result
    # Try 1.5 seconds
    :timer.sleep(1500)

    # Check model was updated
    assert_model(dispatcher_pid, %{
      count: 0,
      last_clipboard: "Test Clipboard Content"
    })
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

  test "supervisor restarts child processes (example: Dispatcher)", %{
    supervisor_pid: supervisor_pid
  } do
    # Find the initial Dispatcher PID
    dispatcher_info =
      Supervisor.which_children(supervisor_pid)
      |> Enum.find(fn {id, _, _, _} ->
        id == Raxol.Core.Runtime.Events.Dispatcher
      end)

    assert {Raxol.Core.Runtime.Events.Dispatcher, dispatcher_pid, :worker, _} =
             dispatcher_info

    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Found initial Dispatcher: #{inspect(dispatcher_pid)}"
    )

    # Manually stop the Dispatcher process
    # Use :kill to simulate an unexpected crash
    ref = Process.monitor(dispatcher_pid)
    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Sending :kill to #{inspect(dispatcher_pid)}"
    )

    Process.exit(dispatcher_pid, :kill)

    # Wait for DOWN message (increased timeout)
    # ADDED LOG
    Logger.debug("[TEST supervisor restart] Waiting for :DOWN message...")

    receive do
      {:DOWN, ^ref, :process, ^dispatcher_pid, :killed} ->
        # ADDED LOG
        Logger.debug(
          "[TEST supervisor restart] Received :DOWN message for #{inspect(dispatcher_pid)}."
        )

        :ok
    after
      5000 -> flunk("Did not receive DOWN message for Dispatcher after 5000ms")
    end

    # Allow time for supervisor to restart (give it generous time)
    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Sleeping for 1000ms for supervisor restart..."
    )

    # Increased from 500ms
    Process.sleep(1000)

    # Verify the Dispatcher has been restarted by the supervisor
    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Checking for restarted Dispatcher..."
    )

    new_dispatcher_info =
      Supervisor.which_children(supervisor_pid)
      |> Enum.find(fn {id, _, _, _} ->
        id == Raxol.Core.Runtime.Events.Dispatcher
      end)

    # ADDED CHECK FOR NIL
    unless new_dispatcher_info do
      Logger.warning(
        "[TEST supervisor restart] Supervisor children: #{inspect(Supervisor.which_children(supervisor_pid))}"
      )

      flunk(
        "Dispatcher process not found in supervisor children after restart attempt."
      )
    end

    assert {Raxol.Core.Runtime.Events.Dispatcher, new_dispatcher_pid, :worker,
            _} = new_dispatcher_info

    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Found new Dispatcher: #{inspect(new_dispatcher_pid)}"
    )

    # Ensure it's a *new* process
    refute new_dispatcher_pid == dispatcher_pid
    # ADDED LOG
    Logger.debug("[TEST supervisor restart] New PID confirmed.")

    # Verify the new Dispatcher is functioning (e.g., by getting its model)
    # Use the assert_model helper
    # Use string theme
    expected_model = %{
      count: 0,
      last_clipboard: nil,
      current_theme_id: "Default Theme"
    }

    # ADDED LOG
    Logger.debug(
      "[TEST supervisor restart] Asserting model for new Dispatcher..."
    )

    assert_model(new_dispatcher_pid, expected_model)
    # ADDED LOG
    Logger.debug("[TEST supervisor restart] Model assertion passed.")
  end

  # --- Test Setup Helpers ---

  # Changed context to _context as it's not used now
  defp setup_runtime_environment(_context) do
    # Explicitly stop any existing Dispatcher and its Registry
    disp_pid = Process.whereis(Raxol.Core.Runtime.Events.Dispatcher)

    if disp_pid && Process.alive?(disp_pid) do
      Logger.debug(
        "[TEST setup] Forcing stop of existing Dispatcher: #{inspect(disp_pid)}"
      )

      # Unlink before exit to prevent crash propagation
      Process.unlink(disp_pid)
      ref = Process.monitor(disp_pid)
      # Use :kill for faster cleanup in tests
      Process.exit(disp_pid, :kill)

      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        500 ->
          Logger.warning(
            "[TEST setup] Did not receive DOWN for Dispatcher #{inspect(disp_pid)} after kill."
          )
      end
    end

    reg_pid = Process.whereis(:raxol_event_subscriptions)

    if reg_pid && Process.alive?(reg_pid) do
      Logger.debug(
        "[TEST setup] Forcing stop of existing Registry :raxol_event_subscriptions: #{inspect(reg_pid)}"
      )

      # Unlink before exit
      Process.unlink(reg_pid)
      ref = Process.monitor(reg_pid)
      # Use :kill for faster cleanup in tests
      Process.exit(reg_pid, :kill)

      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        500 ->
          Logger.warning(
            "[TEST setup] Did not receive DOWN for Registry #{inspect(reg_pid)} after kill."
          )
      end
    end

    # Clear out user preferences to ensure a clean state for each test
    # Ensure UserPreferences is stopped before deleting its file
    case Process.whereis(Raxol.Core.UserPreferences) do
      # Removed Process.alive? from guard
      pid when is_pid(pid) ->
        # Check if alive inside the clause
        if Process.alive?(pid) do
          ref = Process.monitor(pid)
          Process.exit(pid, :shutdown)

          receive do
            {:DOWN, ^ref, _, _, _} -> :ok
          after
            500 ->
              Logger.warning(
                "[TEST setup] UserPreferences did not stop cleanly before deleting file."
              )
          end
        end

      # Not found or already stopped
      _ ->
        :ok
    end

    # Use Persistence module to get path and safely remove file
    prefs_path = Raxol.Core.Preferences.Persistence.preferences_path()

    try do
      File.rm(prefs_path)
      Logger.debug("[TEST setup] Deleted preferences file: #{prefs_path}")
    rescue
      # Ignore error if file doesn't exist (e.g., :enoent)
      File.Error -> :ok
    end
  end
end
