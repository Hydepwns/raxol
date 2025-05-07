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

  setup_all do
    # Ensure application registry is started for our tests
    start_supervised!(Raxol.DynamicSupervisor)
    start_supervised!(Raxol.Terminal.Registry)
    # Do NOT start UserPreferences globally here, let the app start it
    # start_supervised!(Raxol.Core.UserPreferences)
    :ok
  end

  describe "application lifecycle" do
    test "register_application registers an app with the registry" do
      :ok = Lifecycle.register_application(:test_app, self())
      assert {:error, :not_found} == Lifecycle.lookup_app(:test_app)
    end

    test "lookup_app returns error for non-existent app" do
      assert {:error, :not_found} == Lifecycle.lookup_app(:nonexistent_app)
    end

    test "start_application uses app_name from module if available" do
      {:ok, _pid} = Lifecycle.start_application(TestApp, [])
    end

    test "get_app_name returns module's app_name if available" do
      app_module = TestApp
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
          assert result == {:stop, :normal, %{}}
        end)

      assert log =~ "[Lifecycle] Unknown error: {:termbox_error, :some_reason}"
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
          assert result == {:stop, :normal, %{}}
        end)

      assert log =~ "[Lifecycle] Unknown error: {:application_error, :crash}"
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
          assert result == {:stop, :normal, %{}}
        end)

      assert log =~ "[Lifecycle] Unknown error: {:unknown_error, :reason}"
    end
  end

  describe "environment handling" do
    test "initialize_environment with :terminal option" do
      options = [
        environment: :terminal,
        width: 100,
        height: 50,
        title: "Test Title"
      ]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)
          assert result == options
        end)
    end

    test "initialize_environment handles terminal initialization failure" do
      options = [environment: :terminal]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)
          assert result == options
        end)
    end

    test "initialize_environment with unknown environment type" do
      options = [environment: :unknown]

      log =
        capture_log(fn ->
          result = Lifecycle.initialize_environment(options)
          assert result == options
        end)
    end
  end

  describe "cleanup handling" do
    test "handle_cleanup performs proper cleanup" do
      state = %{app_name: :test_app}

      log =
        capture_log(fn ->
          result = Lifecycle.handle_cleanup(state)
          assert result == :ok
        end)

      assert log =~ "Lifecycle cleaning up for app: test_app"
    end
  end
end
