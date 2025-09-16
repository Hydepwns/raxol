#!/usr/bin/env elixir

# Plugin Memory Benchmark
# Tests memory usage patterns for plugin system operations

Mix.install([
  {:benchee, "~> 1.1"},
  {:jason, "~> 1.4"}
])

# Add project lib path
Code.append_path("lib")

defmodule PluginMemoryBenchmark do
  @moduledoc """
  Memory benchmarks for plugin system operations.

  This benchmark suite tests memory usage patterns for:
  - Plugin loading and initialization
  - Plugin lifecycle management
  - Event dispatching
  - Plugin communication
  - Resource management
  """

  alias Raxol.Core.Runtime.{PluginManager, EventSystem}

  def run_benchmarks(opts \\ []) do
    config = [
      time: 3,
      memory_time: 2,
      warmup: 1,
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console,
        {Benchee.Formatters.JSON, file: "bench/output/plugin_memory.json"}
      ]
    ] |> Keyword.merge(opts)

    IO.puts("Running Plugin Memory Benchmarks...")
    IO.puts("Config: #{inspect(config)}")

    Benchee.run(
      %{
        "single_plugin_load" => fn -> single_plugin_load() end,
        "multiple_plugin_load" => fn -> multiple_plugin_load() end,
        "plugin_lifecycle" => fn -> plugin_lifecycle_operations() end,
        "event_dispatching" => fn -> event_dispatching_operations() end,
        "plugin_communication" => fn -> plugin_communication_operations() end,
        "resource_management" => fn -> resource_management_operations() end,
        "plugin_hot_reload" => fn -> plugin_hot_reload_operations() end,
        "memory_intensive_plugins" => fn -> memory_intensive_plugin_operations() end
      },
      config
    )
  end

  # Test loading a single plugin
  defp single_plugin_load do
    plugin_config = %{
      name: "test_plugin",
      version: "1.0.0",
      module: TestPlugin,
      config: %{}
    }

    {:ok, _manager} = PluginManager.start_link([])
    {:ok, _plugin} = PluginManager.load_plugin(plugin_config)
  end

  # Test loading multiple plugins
  defp multiple_plugin_load do
    plugins = Enum.map(1..5, fn i ->
      %{
        name: "test_plugin_#{i}",
        version: "1.0.0",
        module: String.to_atom("TestPlugin#{i}"),
        config: %{id: i}
      }
    end)

    {:ok, _manager} = PluginManager.start_link([])

    Enum.map(plugins, fn plugin_config ->
      {:ok, _plugin} = PluginManager.load_plugin(plugin_config)
    end)
  end

  # Test plugin lifecycle operations
  defp plugin_lifecycle_operations do
    plugin_config = %{
      name: "lifecycle_test_plugin",
      version: "1.0.0",
      module: LifecycleTestPlugin,
      config: %{}
    }

    {:ok, _manager} = PluginManager.start_link([])

    # Load plugin
    {:ok, plugin} = PluginManager.load_plugin(plugin_config)

    # Initialize plugin
    PluginManager.initialize_plugin(plugin)

    # Start plugin
    PluginManager.start_plugin(plugin)

    # Stop plugin
    PluginManager.stop_plugin(plugin)

    # Unload plugin
    PluginManager.unload_plugin(plugin)
  end

  # Test event dispatching operations
  defp event_dispatching_operations do
    {:ok, _event_system} = EventSystem.start_link([])

    # Register multiple event handlers
    handlers = Enum.map(1..10, fn i ->
      handler_fn = fn event ->
        # Simulate some processing
        Process.sleep(1)
        {:ok, "Processed #{event.type} by handler #{i}"}
      end

      EventSystem.register_handler("test_event", handler_fn)
      handler_fn
    end)

    # Dispatch multiple events
    events = Enum.map(1..20, fn i ->
      %{type: "test_event", data: %{id: i, payload: "Event #{i}"}}
    end)

    Enum.map(events, fn event ->
      EventSystem.dispatch(event)
    end)

    {handlers, events}
  end

  # Test plugin communication operations
  defp plugin_communication_operations do
    {:ok, _manager} = PluginManager.start_link([])

    # Create communicating plugins
    plugin_a_config = %{
      name: "plugin_a",
      version: "1.0.0",
      module: CommunicationPluginA,
      config: %{}
    }

    plugin_b_config = %{
      name: "plugin_b",
      version: "1.0.0",
      module: CommunicationPluginB,
      config: %{}
    }

    {:ok, plugin_a} = PluginManager.load_plugin(plugin_a_config)
    {:ok, plugin_b} = PluginManager.load_plugin(plugin_b_config)

    # Simulate inter-plugin communication
    messages = Enum.map(1..10, fn i ->
      %{from: "plugin_a", to: "plugin_b", data: "Message #{i}"}
    end)

    Enum.map(messages, fn message ->
      PluginManager.send_message(plugin_a, plugin_b, message)
    end)

    {plugin_a, plugin_b, messages}
  end

  # Test resource management operations
  defp resource_management_operations do
    {:ok, _manager} = PluginManager.start_link([])

    # Create plugins that manage resources
    resource_plugins = Enum.map(1..3, fn i ->
      plugin_config = %{
        name: "resource_plugin_#{i}",
        version: "1.0.0",
        module: String.to_atom("ResourcePlugin#{i}"),
        config: %{
          resources: Enum.map(1..5, fn j ->
            %{id: "resource_#{i}_#{j}", type: "memory", size: 1024 * j}
          end)
        }
      }

      {:ok, plugin} = PluginManager.load_plugin(plugin_config)

      # Allocate resources
      PluginManager.allocate_resources(plugin)

      plugin
    end)

    # Simulate resource usage
    Enum.map(resource_plugins, fn plugin ->
      PluginManager.use_resources(plugin, %{operation: "process_data", size: 2048})
    end)

    # Cleanup resources
    Enum.map(resource_plugins, fn plugin ->
      PluginManager.deallocate_resources(plugin)
    end)

    resource_plugins
  end

  # Test plugin hot reload operations
  defp plugin_hot_reload_operations do
    {:ok, _manager} = PluginManager.start_link([])

    plugin_config = %{
      name: "hot_reload_plugin",
      version: "1.0.0",
      module: HotReloadPlugin,
      config: %{}
    }

    {:ok, plugin} = PluginManager.load_plugin(plugin_config)
    PluginManager.start_plugin(plugin)

    # Simulate hot reload process
    updated_config = %{plugin_config | version: "1.0.1"}

    # Stop current plugin
    PluginManager.stop_plugin(plugin)

    # Unload current plugin
    PluginManager.unload_plugin(plugin)

    # Load updated plugin
    {:ok, updated_plugin} = PluginManager.load_plugin(updated_config)

    # Start updated plugin
    PluginManager.start_plugin(updated_plugin)

    updated_plugin
  end

  # Memory intensive plugin operations
  defp memory_intensive_plugin_operations do
    {:ok, _manager} = PluginManager.start_link([])

    # Create memory-intensive plugins
    memory_plugins = Enum.map(1..3, fn i ->
      plugin_config = %{
        name: "memory_intensive_plugin_#{i}",
        version: "1.0.0",
        module: String.to_atom("MemoryIntensivePlugin#{i}"),
        config: %{
          memory_size: 1024 * 1024 * i,  # 1MB, 2MB, 3MB
          operations: 1000
        }
      }

      {:ok, plugin} = PluginManager.load_plugin(plugin_config)
      PluginManager.start_plugin(plugin)

      # Simulate memory-intensive operations
      large_data = :binary.copy(<<0>>, plugin_config.config.memory_size)

      Enum.each(1..plugin_config.config.operations, fn _op ->
        # Simulate processing large data
        _processed = :crypto.hash(:sha256, large_data)
      end)

      {plugin, large_data}
    end)

    # Cleanup
    Enum.each(memory_plugins, fn {plugin, _data} ->
      PluginManager.stop_plugin(plugin)
      PluginManager.unload_plugin(plugin)
    end)

    memory_plugins
  end
end

# Mock plugin modules for testing
defmodule TestPlugin do
  def init(_config), do: {:ok, %{}}
  def start(_state), do: {:ok, %{}}
  def stop(_state), do: {:ok, %{}}
end

defmodule LifecycleTestPlugin do
  def init(_config), do: {:ok, %{initialized: true}}
  def start(state), do: {:ok, Map.put(state, :started, true)}
  def stop(state), do: {:ok, Map.put(state, :stopped, true)}
end

defmodule CommunicationPluginA do
  def init(_config), do: {:ok, %{name: "plugin_a"}}
  def handle_message(state, message), do: {:ok, state, "Received: #{inspect(message)}"}
end

defmodule CommunicationPluginB do
  def init(_config), do: {:ok, %{name: "plugin_b"}}
  def handle_message(state, message), do: {:ok, state, "Processed: #{inspect(message)}"}
end

# Parse command line arguments
{opts, _args, _invalid} = OptionParser.parse(System.argv(),
  switches: [
    json: :boolean,
    time: :integer,
    memory_time: :integer,
    warmup: :integer
  ]
)

# Configure benchmark options
benchmark_opts = []

if opts[:json] do
  benchmark_opts = Keyword.put(benchmark_opts, :formatters, [
    {Benchee.Formatters.JSON, file: "/dev/stdout"}
  ])
end

if opts[:time] do
  benchmark_opts = Keyword.put(benchmark_opts, :time, opts[:time])
end

if opts[:memory_time] do
  benchmark_opts = Keyword.put(benchmark_opts, :memory_time, opts[:memory_time])
end

if opts[:warmup] do
  benchmark_opts = Keyword.put(benchmark_opts, :warmup, opts[:warmup])
end

# Ensure output directory exists
File.mkdir_p("bench/output")

# Run the benchmarks
try do
  PluginMemoryBenchmark.run_benchmarks(benchmark_opts)
rescue
  error ->
    IO.puts("Error running plugin memory benchmarks: #{inspect(error)}")
    System.halt(1)
end