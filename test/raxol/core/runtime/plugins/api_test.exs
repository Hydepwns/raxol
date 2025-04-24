defmodule Raxol.Core.Runtime.Plugins.APITest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.API
  alias Raxol.Core.Runtime.Events.Dispatcher

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
    # Create mocks for dependencies
    :meck.new(Raxol.Core.Runtime.Events.Dispatcher, [:passthrough])
    :meck.new(Raxol.Core.Runtime.Plugins.Commands, [:passthrough])
    :meck.new(Raxol.Core.Runtime.Rendering.Engine, [:passthrough])
    :meck.new(Raxol.Core.Runtime.Rendering.Buffer, [:passthrough])
    :meck.new(Raxol.Core.Runtime.Debug, [:passthrough])

    # Replace functions with our test implementations
    :meck.expect(Raxol.Core.Runtime.Events.Dispatcher, :subscribe,
      fn event_type, handler, function ->
        send(self(), {:subscribe_called, event_type, handler, function})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Events.Dispatcher, :unsubscribe,
      fn event_type, handler ->
        send(self(), {:unsubscribe_called, event_type, handler})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Events.Dispatcher, :broadcast,
      fn event_type, payload ->
        send(self(), {:broadcast_called, event_type, payload})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Plugins.Commands, :register,
      fn name, handler, help, options ->
        send(self(), {:command_registered, name, handler, help, options})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Plugins.Commands, :unregister,
      fn name ->
        send(self(), {:command_unregistered, name})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Rendering.Engine, :render,
      fn region, content, options ->
        send(self(), {:render_called, region, content, options})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Rendering.Buffer, :create,
      fn width, height, options ->
        send(self(), {:buffer_created, width, height, options})
        {:ok, %{width: width, height: height}}
      end)

    :meck.expect(Raxol.Core.Runtime.Debug, :info,
      fn message ->
        send(self(), {:debug_info, message})
        :ok
      end)

    :meck.expect(Raxol.Core.Runtime.Debug, :error,
      fn message ->
        send(self(), {:debug_error, message})
        :ok
      end)

    on_exit(fn ->
      :meck.unload(Raxol.Core.Runtime.Events.Dispatcher)
      :meck.unload(Raxol.Core.Runtime.Plugins.Commands)
      :meck.unload(Raxol.Core.Runtime.Rendering.Engine)
      :meck.unload(Raxol.Core.Runtime.Rendering.Buffer)
      :meck.unload(Raxol.Core.Runtime.Debug)
    end)

    :ok
  end

  describe "event handling" do
    test "subscribe forwards calls to dispatcher" do
      API.subscribe(:test_event, TestEventHandler)
      assert_received {:subscribe_called, :test_event, TestEventHandler, :handle_event}
    end

    test "subscribe with custom function forwards function name" do
      API.subscribe(:test_event, TestEventHandler, :custom_handler)
      assert_received {:subscribe_called, :test_event, TestEventHandler, :custom_handler}
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

  describe "command registration" do
    test "register_command forwards calls to Commands module" do
      API.register_command("test:cmd", TestEventHandler, "Test command")
      assert_received {:command_registered, "test:cmd", TestEventHandler, "Test command", []}
    end

    test "register_command with options forwards options" do
      options = [priority: 10]
      API.register_command("test:cmd", TestEventHandler, "Test command", options)
      assert_received {:command_registered, "test:cmd", TestEventHandler, "Test command", ^options}
    end

    test "unregister_command forwards calls to Commands module" do
      API.unregister_command("test:cmd")
      assert_received {:command_unregistered, "test:cmd"}
    end
  end

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
      :meck.new(Application, [:passthrough])
      :meck.expect(Application, :get_env, fn :raxol, :test_key, nil -> "test_value" end)
      on_exit(fn -> :meck.unload(Application) end)

      # Test the function
      assert API.get_config(:test_key) == "test_value"
    end

    test "plugin_data_dir returns correct path" do
      # Test environment setup
      :meck.new(Application, [:passthrough])
      :meck.expect(Application, :get_env, fn :raxol, :plugin_data_path, "data/plugins" -> "custom/path" end)
      on_exit(fn -> :meck.unload(Application) end)

      # Test the function
      assert API.plugin_data_dir("test_plugin") == "custom/path/test_plugin"
    end
  end
end
