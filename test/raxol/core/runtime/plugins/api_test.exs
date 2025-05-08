defmodule Raxol.Core.Runtime.Plugins.APITest do
  use ExUnit.Case, async: true
  import Mox

  alias Raxol.Core.Runtime.Plugins.API
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Debug
  alias Application

  # Define Mocks
  defmock(DispatcherMock, for: Raxol.Core.Runtime.Events.Dispatcher.Behaviour)

  # Mock event handler for testing
  defmodule TestEventHandler do
    def handle_event(event_data) do
      send(self(), {:event_received, event_data})
    end
  end

  # Mock for commands
  defmodule MockCommands do
    def register(name, handler, help, options) do
      send(self(), {:command_registered, name, handler, help, options})
      :ok
    end

    def unregister(name) do
      send(self(), {:command_unregistered, name})
      :ok
    end
  end

  # Mock for rendering
  defmodule MockRenderEngine do
    def render(region, content, options) do
      send(self(), {:render_called, region, content, options})
      :ok
    end
  end

  # Mock for buffer
  defmodule MockBuffer do
    def create(width, height, options) do
      send(self(), {:buffer_created, width, height, options})
      {:ok, %{width: width, height: height}}
    end
  end

  setup do
    Mox.verify_on_exit!()

    # Mox stubs/expectations for DispatcherMock
    Mox.expect(DispatcherMock, :subscribe, fn event_type, handler, function ->
      send(self(), {:subscribe_called, event_type, handler, function})
      :ok
    end)

    Mox.expect(DispatcherMock, :unsubscribe, fn event_type, handler ->
      send(self(), {:unsubscribe_called, event_type, handler})
      :ok
    end)

    Mox.expect(DispatcherMock, :broadcast, fn event_type, payload ->
      send(self(), {:broadcast_called, event_type, payload})
      :ok
    end)

    # Mox stubs for Debug module
    Mox.stub(Raxol.Core.Runtime.Debug, :info, fn message ->
      send(self(), {:debug_info, message})
      :ok
    end)

    Mox.stub(Raxol.Core.Runtime.Debug, :error, fn message ->
      send(self(), {:debug_error, message})
      :ok
    end)

    # Removed :meck setup for Raxol.Core.Runtime.Plugins.Commands (already gone)
    # Removed :meck setup for Raxol.Core.Runtime.Rendering.Engine (tests are skipped)
    # Removed :meck setup for Raxol.Core.Runtime.Rendering.Buffer (API removed/tests skipped)

    # API module needs to know to use DispatcherMock. For this test, we might need
    # to consider how API resolves Dispatcher. If it calls Dispatcher directly,
    # then the functions of Raxol.Core.Runtime.Events.Dispatcher itself would need to be stubbed.
    # For now, assuming API can be configured or will pick up the mock via other means, or we adjust API for testability.
    # The current API.ex seems to call `EventManager.dispatch` which might be an alias or another module.
    # Let's assume for now API calls DispatcherMock for subscribe/unsubscribe/broadcast.
    # If API calls Raxol.Core.Runtime.Events.Dispatcher directly, then we need to stub that module instead of DispatcherMock.

    # The test code calls API.subscribe etc. API then calls Dispatcher functions.
    # So, we need to ensure API uses our DispatcherMock or we stub the real Dispatcher.
    # Given API is `alias Raxol.Core.Runtime.Events.Dispatcher`, it refers to the real one.
    # So, stubs should be on `Raxol.Core.Runtime.Events.Dispatcher` directly.

    # Corrected Mox stubs for direct module interaction:
    Mox.stub(Raxol.Core.Runtime.Events.Dispatcher, :subscribe, fn event_type,
                                                                  handler,
                                                                  function ->
      send(self(), {:subscribe_called, event_type, handler, function})
      :ok
    end)

    Mox.stub(Raxol.Core.Runtime.Events.Dispatcher, :unsubscribe, fn event_type,
                                                                    handler ->
      send(self(), {:unsubscribe_called, event_type, handler})
      :ok
    end)

    Mox.stub(Raxol.Core.Runtime.Events.Dispatcher, :broadcast, fn event_type,
                                                                  payload ->
      send(self(), {:broadcast_called, event_type, payload})
      :ok
    end)

    :ok
  end

  describe "event handling" do
    test "subscribe forwards calls to dispatcher" do
      API.subscribe(:test_event, TestEventHandler)

      assert_received {:subscribe_called, :test_event, TestEventHandler,
                       :handle_event}
    end

    test "subscribe with custom function forwards function name" do
      API.subscribe(:test_event, TestEventHandler, :custom_handler)

      assert_received {:subscribe_called, :test_event, TestEventHandler,
                       :custom_handler}
    end

    test "unsubscribe forwards calls to dispatcher" do
      API.unsubscribe(:test_event, TestEventHandler)
      assert_received {:unsubscribe_called, :test_event, TestEventHandler}
    end

    test "broadcast forwards calls to dispatcher" do
      payload = %{test: "data"}
      API.broadcast(:test_event, payload)
      assert_received {:broadcast_called, :test_event, ^payload}
    end
  end

  # Skip: Rendering API in Raxol.Core.Runtime.Plugins.API has been removed/refactored
  @tag :skip
  describe "rendering" do
    test "render forwards calls to rendering engine" do
      content = "Test content"
      API.render(:test_region, content)
      assert_received {:render_called, :test_region, ^content, []}
    end

    test "render with options forwards options" do
      content = "Test content"
      options = [color: :red]
      API.render(:test_region, content, options)
      assert_received {:render_called, :test_region, ^content, ^options}
    end

    test "create_buffer forwards calls to buffer module" do
      API.create_buffer(80, 24)
      assert_received {:buffer_created, 80, 24, []}
    end
  end

  describe "logging" do
    test "log at info level uses debug module info function" do
      API.log("test_plugin", :info, "Test message")
      assert_received {:debug_info, "[Plugin:test_plugin] Test message"}
    end

    test "log at error level uses debug module error function" do
      API.log("test_plugin", :error, "Error message")
      assert_received {:debug_error, "[Plugin:test_plugin] Error message"}
    end
  end

  describe "configuration" do
    test "get_config forwards to Application.get_env" do
      # Test environment setup
      Mox.stub(Application, :get_env, fn :raxol, :test_key, nil ->
        "test_value"
      end)

      # Test the function
      assert API.get_config(:test_key) == "test_value"
      # Verify this specific stub if needed, or rely on verify_on_exit!
      Mox.verify!(Application)
    end

    test "plugin_data_dir returns correct path" do
      # Test environment setup
      Mox.stub(Application, :get_env, fn :raxol,
                                         :plugin_data_path,
                                         "data/plugins" ->
        "custom/path"
      end)

      # Test the function
      assert API.plugin_data_dir("test_plugin") == "custom/path/test_plugin"
      # Verify this specific stub if needed
      Mox.verify!(Application)
    end
  end
end
