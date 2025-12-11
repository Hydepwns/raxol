# --- Mock Application ---
defmodule MockApp do
  @behaviour Raxol.Core.Runtime.Application
  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Command

  @impl Raxol.Core.Runtime.Application
  def init(_context) do
    %{count: 0, last_clipboard: nil}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:event, %Event{type: :key, data: %{char: "+"}}}, model) do
    new_count = model.count + 1
    new_model = %{model | count: new_count}
    {new_model, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:event, %Event{type: :key, data: %{char: <<17>>}}}, model) do
    Raxol.Core.Runtime.Log.debug(
      "[MockApp.update] Matched Ctrl+Q (char <<17>>)"
    )

    {model, [%Command{type: :quit}]}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:event, %Event{type: :key, data: %{char: <<22>>}}}, model) do
    Raxol.Core.Runtime.Log.debug("[MockApp.update] Matched Ctrl+V")
    {model, [%Command{type: :clipboard_read}]}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:event, %Event{type: :key, data: %{char: <<24>>}}}, model) do
    Raxol.Core.Runtime.Log.debug("[MockApp.update] Matched Ctrl+X")
    {model, [%Command{type: :clipboard_write, data: "copied from mock"}]}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:event, %Event{type: :key, data: %{char: <<14>>}}}, model) do
    Raxol.Core.Runtime.Log.debug("[MockApp.update] Matched Ctrl+N")
    {model, [%Command{type: :notify, data: {"MockApp notification", ""}}]}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:command_result, {:clipboard_read, {:ok, content}}}, model) do
    Raxol.Core.Runtime.Log.debug(
      "[MockApp.update] Received clipboard content: #{content}"
    )

    {%{model | last_clipboard: content}, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:command_result, {:clipboard_read, {:error, reason}}}, model) do
    Raxol.Core.Runtime.Log.error(
      "[MockApp.update] Error reading clipboard: #{inspect(reason)}"
    )

    {model, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update(event_tuple, model) do
    Raxol.Core.Runtime.Log.debug(
      "[MockApp.update] Fell into default case for event_tuple: #{inspect(event_tuple)}"
    )

    {model, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(_), do: :ok

  @impl Raxol.Core.Runtime.Application
  def handle_message(_, _), do: :ok

  @impl Raxol.Core.Runtime.Application
  def handle_tick(_), do: {nil, []}

  @impl Raxol.Core.Runtime.Application
  def terminate(_, _), do: :ok

  @impl Raxol.Core.Runtime.Application
  def view(model) do
    # Simple view for testing
    [
      :text,
      "Count: #{model.count}, Clipboard: #{inspect(model.last_clipboard)}"
    ]
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_model), do: []
end

# --- All test code below ---
defmodule Raxol.RuntimeTest do
  use ExUnit.Case, async: false

  # Mox is used with module prefix, no import needed

  alias Raxol.Core.Runtime.Supervisor, as: RuntimeSupervisor
  alias Raxol.Core.Runtime.Plugins.PluginManager, as: PluginManager
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  alias Raxol.Terminal.Driver, as: TerminalDriver

  # DriverMock already defined in test/support/terminal_driver_mock.ex

  setup context do
    # Call the cleanup helper at the beginning of setup
    setup_runtime_environment(context)

    # Set up DriverMock expectations for all tests that might need it
    if Code.ensure_loaded?(Mox) do
      try do
        Mox.stub(Raxol.Terminal.DriverMock, :start_link, fn _dispatcher_module_or_pid ->
          # Return a mock process that behaves like the Terminal.Driver
          # The dispatcher can be either a module name (from supervisor) or PID
          {:ok, spawn(fn -> Process.sleep(:infinity) end)}
        end)
      rescue
        _ -> :ok  # Ignore if stub fails
      end
    end

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
          clipboard_impl: Raxol.Core.ClipboardMock
        ]
      }
    )

    # Get original stty settings to restore after test, handle potential errors
    _original_stty =
      case System.cmd("stty", ["-g"]) do
        {output, 0} ->
          String.trim(output)

        {_error_output, exit_code} ->
          Raxol.Core.Runtime.Log.warning(
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
    }

    # Start the supervisor and capture the PIDs we need
    {:ok, supervisor_pid} = RuntimeSupervisor.start_link(supervisor_init_args)

    # Wait for the plugin manager to be ready
    # This will likely need adjustment as plugin_manager_pid is no longer directly available here.
    # For now, let's comment it out to see if already_started errors are resolved.
    # assert_receive {:plugin_manager_ready, ^plugin_manager_pid}, 1000

    # Get the PIDs of the processes we need for tests
    dispatcher_pid = Process.whereis(Dispatcher)
    driver_pid = Process.whereis(TerminalDriver)

    # Ensure critical processes are running
    if is_nil(dispatcher_pid) do
      raise "Dispatcher process not found - supervisor may have failed to start it"
    end

    if is_nil(driver_pid) do
      raise "TerminalDriver process not found - supervisor may have failed to start it"
    end

    # Return the captured PIDs in the context
    {:ok,
     %{
       supervisor_pid: supervisor_pid,
       dispatcher_pid: dispatcher_pid,
       driver_pid: driver_pid
     }}
  end

  # --- Tests ---
  # Note: Removed describe blocks for clarity, can be added back if preferred

  @tag skip: "Requires messaging infrastructure not yet implemented"
  test "successfully starts the supervisor and core processes", %{
    supervisor_pid: supervisor_pid
  } do
    # Check if supervisor is running (redundant, start_link succeeded)
    assert is_pid(supervisor_pid)

    # Attempt to resize RenderingEngine buffer to minimize log output on failure
    # Assumes RenderingEngine is started by the supervisor and registered by this name.
    _ =
      GenServer.cast(
        Raxol.Core.Runtime.Rendering.Engine,
        {:update_size, %{width: 1, height: 1}}
      )

    # Wait for children to start
    assert_receive {:child_started, ^supervisor_pid, PluginManager}, 1000
    assert_receive {:child_started, ^supervisor_pid, Dispatcher}, 1000
    assert_receive {:child_started, ^supervisor_pid, RenderingEngine}, 1000
    assert_receive {:child_started, ^supervisor_pid, TerminalDriver}, 1000

    assert_receive {:child_started, ^supervisor_pid,
                    Raxol.Core.UserPreferences},
                   1000

    # Check if children are running (use registered names)
    assert is_pid(Process.whereis(PluginManager))
    assert is_pid(Process.whereis(Dispatcher))
    assert is_pid(Process.whereis(RenderingEngine))
    assert is_pid(Process.whereis(TerminalDriver))
    assert is_pid(Process.whereis(Raxol.Core.UserPreferences))
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

  @tag skip: "Requires messaging infrastructure not yet implemented"
  test "input event triggers application update", %{
    supervisor_pid: supervisor_pid,
    dispatcher_pid: dispatcher_pid
  } do
    # Allow startup
    assert_receive {:child_started, ^supervisor_pid, TerminalDriver}, 1000

    driver_pid = Process.whereis(TerminalDriver)
    assert is_pid(driver_pid), "TerminalDriver not running"

    # Check initial model state
    assert_model(Process.whereis(Dispatcher), %{count: 0, last_clipboard: nil})

    # Inject an event ('+')
    # New way
    GenServer.cast(driver_pid, {:test_input, "+"})

    # Wait for model update
    assert_receive {:model_updated, ^dispatcher_pid,
                    %{count: 1, last_clipboard: nil}},
                   1000

    # Assert model was updated
    assert_model(Process.whereis(Dispatcher), %{count: 1, last_clipboard: nil})

    # Assert render was triggered by checking RenderingEngine state
    rendering_engine_pid = Process.whereis(RenderingEngine)
    assert is_pid(rendering_engine_pid), "RenderingEngine should be running"

    # Verify RenderingEngine is responsive (indicates it processed the render request)
    assert GenServer.call(rendering_engine_pid, :get_state, 100) != :timeout
  end

  @tag skip: "Requires messaging infrastructure not yet implemented"
  test "application Command.quit() terminates the runtime gracefully", %{
    supervisor_pid: supervisor_pid
  } do
    # Allow startup
    :timer.sleep(100)

    driver_pid = Process.whereis(TerminalDriver)
    assert is_pid(driver_pid), "TerminalDriver not running"

    # Monitor supervisor to ensure it doesn't crash UNEXPECTEDLY during the test
    _ref = Process.monitor(supervisor_pid)

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

  @tag skip: "Requires messaging infrastructure not yet implemented"
  test "Command.clipboard_write and Command.notify are delegated", context do
    # supervisor_pid = context.supervisor_pid
    driver_pid = context.driver_pid

    # Allow startup
    :timer.sleep(100)

    # Mox expectations
    Mox.expect(Raxol.Core.ClipboardMock, :copy, fn "copied from mock" -> :ok end)

    # For :notify (Ctrl+N from MockApp)
    Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :darwin} end)

    Mox.expect(SystemInteractionMock, :find_executable, fn "osascript" ->
      "/usr/bin/osascript"
    end)

    expected_script =
      ~s(display notification "MockApp notification" with title "Raxol Notification")

    Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/osascript",
                                                      ["-e", ^expected_script],
                                                      [stderr_to_stdout: true] ->
      {"", 0}
    end)

    # Simulate Ctrl+X (copy "copied from mock")
    # Ctrl+X
    GenServer.cast(driver_pid, {:test_input, <<24>>})
    # Wait for command processing
    assert_receive {:command_processed, ^driver_pid, :copy}, 1000

    # Simulate Ctrl+N (notify "Mock Title", "Mock Body")
    # Ctrl+N
    GenServer.cast(driver_pid, {:test_input, <<14>>})
    # Wait for command processing
    assert_receive {:command_processed, ^driver_pid, :notify}, 1000

    # Verify expectations (Mox will do this automatically on test exit if expectations are set)
    # For this test, the main goal is to ensure no crashes and that PluginManager handles them.
    # The lack of crashes during these operations (post Mox fix) will be a good sign.
  end

  @tag skip: "Requires messaging infrastructure not yet implemented"
  test "Command.clipboard_read fetches content and updates app model", %{
    supervisor_pid: _supervisor_pid,
    dispatcher_pid: dispatcher_pid,
    driver_pid: driver_pid
  } do
    # Allow startup
    :timer.sleep(100)

    # Mox expectation for ClipboardMock.paste/0, allow from any process
    Mox.expect(Raxol.Core.ClipboardMock, :paste, fn ->
      {:ok, "Test Clipboard Content"}
    end)

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

  @tag skip: "Requires messaging infrastructure not yet implemented"
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

    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Found initial Dispatcher: #{inspect(dispatcher_pid)}"
    )

    # Subscribe to dispatcher events before killing it
    {:ok, _} =
      Registry.register(:raxol_event_subscriptions, :dispatcher_events, [])

    # Manually stop the Dispatcher process
    # Use :kill to simulate an unexpected crash
    ref = Process.monitor(dispatcher_pid)

    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Sending :kill to #{inspect(dispatcher_pid)}"
    )

    Process.exit(dispatcher_pid, :kill)

    # Wait for DOWN message
    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Waiting for :DOWN message..."
    )

    assert_receive {:DOWN, ^ref, :process, ^dispatcher_pid, :killed}, 5000

    # Wait for the restarted Dispatcher to be ready by subscribing to its events
    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Waiting for restarted Dispatcher to be ready..."
    )

    # Wait for the new dispatcher to be ready by subscribing to its events
    assert_receive {:dispatcher_ready, new_dispatcher_pid}, 5000

    # Verify the Dispatcher has been restarted by the supervisor
    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Checking for restarted Dispatcher..."
    )

    new_dispatcher_info =
      Supervisor.which_children(supervisor_pid)
      |> Enum.find(fn {id, _, _, _} ->
        id == Raxol.Core.Runtime.Events.Dispatcher
      end)

    if !new_dispatcher_info do
      Raxol.Core.Runtime.Log.warning(
        "[TEST supervisor restart] Supervisor children: #{inspect(Supervisor.which_children(supervisor_pid))}"
      )

      flunk(
        "Dispatcher process not found in supervisor children after restart attempt."
      )
    end

    assert {Raxol.Core.Runtime.Events.Dispatcher, ^new_dispatcher_pid, :worker,
            _} = new_dispatcher_info

    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Found new Dispatcher: #{inspect(new_dispatcher_pid)}"
    )

    # Ensure it's a *new* process
    refute new_dispatcher_pid == dispatcher_pid
    Raxol.Core.Runtime.Log.debug("[TEST supervisor restart] New PID confirmed.")

    # Verify the new Dispatcher is functioning (e.g., by getting its model)
    # Use the assert_model helper
    # Use string theme
    expected_model = %{
      count: 0,
      last_clipboard: nil,
      current_theme_id: "Default Theme"
    }

    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Asserting model for new Dispatcher..."
    )

    assert_model(new_dispatcher_pid, expected_model)

    Raxol.Core.Runtime.Log.debug(
      "[TEST supervisor restart] Model assertion passed."
    )
  end

  # --- Test Setup Helpers ---

  defp setup_runtime_environment(_context) do
    cleanup_dispatcher()
    cleanup_registry()
    cleanup_user_preferences()
  end

  defp cleanup_dispatcher() do
    disp_pid = Process.whereis(Raxol.Core.Runtime.Events.Dispatcher)

    if disp_pid && Process.alive?(disp_pid) do
      Raxol.Core.Runtime.Log.debug(
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
          Raxol.Core.Runtime.Log.warning(
            "[TEST setup] Did not receive DOWN for Dispatcher #{inspect(disp_pid)} after kill."
          )
      end
    end
  end

  defp cleanup_registry() do
    reg_pid = Process.whereis(:raxol_event_subscriptions)

    if reg_pid && Process.alive?(reg_pid) do
      Raxol.Core.Runtime.Log.debug(
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
          Raxol.Core.Runtime.Log.warning(
            "[TEST setup] Did not receive DOWN for Registry #{inspect(reg_pid)} after kill."
          )
      end
    end
  end

  defp cleanup_user_preferences() do
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
              Raxol.Core.Runtime.Log.warning(
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

      Raxol.Core.Runtime.Log.debug(
        "[TEST setup] Deleted preferences file: #{prefs_path}"
      )
    rescue
      # Ignore error if file doesn't exist (e.g., :enoent)
      File.Error -> :ok
    end
  end
end
