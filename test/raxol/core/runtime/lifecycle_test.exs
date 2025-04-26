defmodule Raxol.Core.Runtime.LifecycleTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Raxol.Core.Runtime.Lifecycle

  # Mock app module for testing
  defmodule TestApp do
    def init(_) do
      {:ok, %{initialized: true}}
    end

    def update(model, _msg) do
      {:ok, model, nil}
    end

    def view(_model) do
      "Test App View"
    end

    def app_name do
      :test_app
    end

    def terminate(model) do
      send(Process.group_leader(), {:test_app_terminated, model})
      :ok
    end
  end

  # Mock module for terminal utils
  defmodule MockTerminalUtils do
    def set_terminal_title(_title), do: :ok
    def initialize_terminal(_width, _height), do: :ok
    def restore_terminal, do: :ok
  end

  setup do
    # Ensure application registry is started for our tests
    start_supervised!(Raxol.DynamicSupervisor)
    start_supervised!(Raxol.Terminal.Registry)
    :ok
  end

  describe "application lifecycle" do
    test "register_application registers an app with the registry" do
      :ok = Lifecycle.register_application(:test_app, self())
      assert {:ok, self()} == Lifecycle.lookup_app(:test_app)
    end

    test "lookup_app returns error for non-existent app" do
      assert :error == Lifecycle.lookup_app(:nonexistent_app)
    end

    test "get_app_name returns module's app_name if available" do
      app_module = TestApp
      result = Lifecycle.get_app_name(app_module)
      assert result == :test_app
    end

    # TODO: Add this test when app_module without app_name/0 function is available
    # test "get_app_name returns :default if app_name/0 not available" do
    #   app_module = ModuleWithoutAppName
    #   result = Lifecycle.get_app_name(app_module)
    #   assert result == :default
    # end
  end

  describe "error handling" do
    test "handle_error logs termbox errors and attempts retry" do
      state = %{
        app_module: TestApp,
        model: %{},
        app_name: :test_app,
        environment: :terminal
      }

      error = {:termbox_error, :some_reason}

      log =
        capture_log(fn ->
          result = Lifecycle.handle_error(error, state)
          assert result == {:retry, state}
        end)

      assert log =~ "Termbox error"
    end

    test "handle_error logs application errors and stops" do
      state = %{
        app_module: TestApp,
        model: %{},
        app_name: :test_app,
        environment: :terminal
      }

      error = {:application_error, :crash}

      log =
        capture_log(fn ->
          result = Lifecycle.handle_error(error, state)
          assert result == {:stop, state}
        end)

      assert log =~ "Application error"
    end

    test "handle_error logs unknown errors and continues" do
      state = %{
        app_module: TestApp,
        model: %{},
        app_name: :test_app,
        environment: :terminal
      }

      error = {:unknown_error, :reason}

      log =
        capture_log(fn ->
          result = Lifecycle.handle_error(error, state)
          assert result == {:continue, state}
        end)

      assert log =~ "Unknown error"
    end
  end

  describe "environment handling" do
    test "initialize_environment with :terminal option" do
      # Mock TerminalUtils module
      original_module = Raxol.Terminal.TerminalUtils
      :meck.new(Raxol.Terminal.TerminalUtils, [:passthrough])

      :meck.expect(Raxol.Terminal.TerminalUtils, :initialize_terminal, fn _,
                                                                          _ ->
        :ok
      end)

      :meck.expect(Raxol.Terminal.TerminalUtils, :set_terminal_title, fn _ ->
        :ok
      end)

      options = [
        environment: :terminal,
        width: 100,
        height: 50,
        title: "Test Title"
      ]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)

          assert {:ok, %{environment: :terminal, width: 100, height: 50}} =
                   result
        end)

      assert log =~ "Terminal environment initialized"

      # Clean up
      :meck.unload(Raxol.Terminal.TerminalUtils)
    end

    test "initialize_environment handles terminal initialization failure" do
      # Mock TerminalUtils module to fail
      original_module = Raxol.Terminal.TerminalUtils
      :meck.new(Raxol.Terminal.TerminalUtils, [:passthrough])

      :meck.expect(Raxol.Terminal.TerminalUtils, :initialize_terminal, fn _,
                                                                          _ ->
        {:error, :test_failure}
      end)

      :meck.expect(Raxol.Terminal.TerminalUtils, :set_terminal_title, fn _ ->
        :ok
      end)

      options = [environment: :terminal]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)
          assert {:error, :test_failure} = result
        end)

      assert log =~ "Failed to initialize terminal"

      # Clean up
      :meck.unload(Raxol.Terminal.TerminalUtils)
    end

    test "initialize_environment with unknown environment type" do
      options = [environment: :unknown]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)
          assert result == {:error, :unknown_environment}
        end)

      assert log =~ "Unknown environment type"
    end
  end

  describe "cleanup handling" do
    test "handle_cleanup performs proper cleanup" do
      # Register app for testing unregister
      Lifecycle.register_application(:test_app, self())

      # Mock TerminalUtils module for cleanup
      :meck.new(Raxol.Terminal.TerminalUtils, [:passthrough])

      :meck.expect(Raxol.Terminal.TerminalUtils, :restore_terminal, fn ->
        :ok
      end)

      state = %{
        app_module: TestApp,
        model: %{data: "test"},
        app_name: :test_app,
        environment: :terminal
      }

      # Capture leader process for checking terminate callback
      Process.group_leader(self())

      log =
        capture_log(fn ->
          result = Lifecycle.handle_cleanup(state)
          assert result == :ok

          # Test app should be unregistered
          assert :error == Lifecycle.lookup_app(:test_app)

          # Terminate callback should be called
          assert_received {:test_app_terminated, %{data: "test"}}
        end)

      assert log =~ "Cleaning up application resources"

      # Clean up
      :meck.unload(Raxol.Terminal.TerminalUtils)
    end
  end
end
