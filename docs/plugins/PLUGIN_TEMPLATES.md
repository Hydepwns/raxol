# Plugin Templates and Examples

**Version**: v1.6.0
**Last Updated**: 2025-09-26
**Target**: Plugin developers

## Template Overview

This document provides ready-to-use templates for common plugin types, based on the existing successful plugins in the Raxol ecosystem.

## Basic Plugin Template

### Minimal Plugin Structure

```elixir
defmodule Raxol.Plugins.MyBasicPlugin do
  @moduledoc """
  Basic template for Raxol plugins.

  Replace MyBasicPlugin with your plugin name and implement the desired functionality.
  """

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  # Plugin manifest - always required
  def manifest do
    %{
      name: "my-basic-plugin",
      version: "1.0.0",
      description: "A basic plugin template",
      author: "Your Name",
      license: "MIT",
      api_version: "2.0",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [:command_handler],
      trust_level: :trusted,
      config_schema: %{
        enabled: %{type: :boolean, default: true},
        debug: %{type: :boolean, default: false}
      }
    }
  end

  # Plugin state structure
  defstruct [
    :config,
    :enabled,
    :data
  ]

  # Required callbacks
  def init(config) do
    state = %__MODULE__{
      config: config,
      enabled: true,
      data: %{}
    }

    Logger.info("[MyBasicPlugin] Initialized with config: #{inspect(config)}")
    {:ok, state}
  end

  def terminate(_reason, _state) do
    Logger.info("[MyBasicPlugin] Terminated")
    :ok
  end

  def enable(state) do
    Logger.info("[MyBasicPlugin] Enabled")
    {:ok, %{state | enabled: true}}
  end

  def disable(state) do
    Logger.info("[MyBasicPlugin] Disabled")
    {:ok, %{state | enabled: false}}
  end

  # Optional callbacks
  def filter_event(event, state) do
    # Default: pass all events through unchanged
    {:ok, event}
  end

  def handle_command(:hello, _args, state) do
    message = "Hello from #{__MODULE__}!"
    Logger.info(message)
    {:ok, state, message}
  end

  def handle_command(command, _args, state) do
    {:error, "Unknown command: #{command}", state}
  end

  def get_commands do
    [{:hello, :handle_command, 3}]
  end
end
```

## UI Plugin Template

### Interactive UI Plugin

```elixir
defmodule Raxol.Plugins.MyUIPlugin do
  @moduledoc """
  Template for plugins that create interactive UI components.
  """

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  def manifest do
    %{
      name: "my-ui-plugin",
      version: "1.0.0",
      description: "Interactive UI plugin template",
      author: "Your Name",
      api_version: "2.0",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [:ui_overlay, :keyboard_input, :command_handler],
      trust_level: :trusted,
      config_schema: %{
        hotkey: %{type: :string, default: "ctrl+u"},
        max_items: %{type: :integer, default: 10, min: 1, max: 100},
        theme: %{type: :string, default: "dark", enum: ["dark", "light", "auto"]}
      }
    }
  end

  defstruct [
    :config,
    :visible,
    :selected_index,
    :items,
    :search_query,
    :emulator_pid
  ]

  def init(config) do
    state = %__MODULE__{
      config: config,
      visible: false,
      selected_index: 0,
      items: [],
      search_query: "",
      emulator_pid: nil
    }

    {:ok, state}
  end

  def terminate(_reason, state) do
    if state.emulator_pid do
      send(state.emulator_pid, {:plugin_terminated, __MODULE__})
    end
    :ok
  end

  def enable(state) do
    # Register hotkey handler
    {:ok, %{state | visible: false}}
  end

  def disable(state) do
    # Unregister hotkey handler
    {:ok, %{state | visible: false}}
  end

  def filter_event({:key_press, key}, %{visible: true} = state) do
    # Handle keys when UI is visible
    new_state = case key do
      "escape" ->
        %{state | visible: false}

      "enter" ->
        execute_selected_item(state)

      "up" ->
        move_selection(state, -1)

      "down" ->
        move_selection(state, 1)

      char when byte_size(char) == 1 ->
        # Add to search query
        new_query = state.search_query <> char
        %{state | search_query: new_query}
        |> update_filtered_items()

      _ ->
        state
    end

    {:ok, {:plugin_event, {:ui_updated, new_state}}}
  end

  def filter_event({:key_press, hotkey}, %{config: %{hotkey: hotkey}} = state) do
    # Toggle visibility on hotkey
    new_state = %{state | visible: not state.visible}
    |> load_items_if_needed()

    {:ok, {:plugin_event, {:ui_toggled, new_state.visible}}}
  end

  def filter_event(event, _state) do
    # Pass through other events
    {:ok, event}
  end

  def handle_command(:show, _args, state) do
    new_state = %{state | visible: true} |> load_items_if_needed()
    {:ok, new_state, :shown}
  end

  def handle_command(:hide, _args, state) do
    new_state = %{state | visible: false}
    {:ok, new_state, :hidden}
  end

  def handle_command(:toggle, _args, state) do
    new_state = %{state | visible: not state.visible}
    |> load_items_if_needed()

    {:ok, new_state, if(new_state.visible, do: :shown, else: :hidden)}
  end

  def get_commands do
    [
      {:show, :handle_command, 3},
      {:hide, :handle_command, 3},
      {:toggle, :handle_command, 3}
    ]
  end

  # UI rendering (would be called by terminal renderer)
  def render_overlay(%{visible: true} = state, width, height) do
    lines = [
      render_header(state, width),
      render_search_box(state, width),
      render_separator(width)
    ] ++ render_items(state, width, height - 3)

    {:ok, lines}
  end

  def render_overlay(_state, _width, _height) do
    {:ok, []}
  end

  # Private functions
  defp move_selection(state, direction) do
    max_index = max(0, length(state.items) - 1)
    new_index = state.selected_index + direction
    new_index = max(0, min(new_index, max_index))

    %{state | selected_index: new_index}
  end

  defp execute_selected_item(%{items: items, selected_index: index} = state) do
    case Enum.at(items, index) do
      nil ->
        state
      item ->
        # Execute the selected item
        Logger.info("Executing: #{inspect(item)}")
        %{state | visible: false}
    end
  end

  defp load_items_if_needed(%{visible: true, items: []} = state) do
    # Load items when UI becomes visible
    items = load_available_items(state.config)
    %{state | items: items}
  end

  defp load_items_if_needed(state), do: state

  defp load_available_items(_config) do
    # Implementation-specific: load your items here
    [
      %{name: "Item 1", action: :action1},
      %{name: "Item 2", action: :action2},
      %{name: "Item 3", action: :action3}
    ]
  end

  defp update_filtered_items(%{search_query: ""} = state) do
    # Show all items when no search query
    items = load_available_items(state.config)
    %{state | items: items, selected_index: 0}
  end

  defp update_filtered_items(%{search_query: query} = state) do
    all_items = load_available_items(state.config)

    filtered_items =
      all_items
      |> Enum.filter(fn item ->
        String.contains?(String.downcase(item.name), String.downcase(query))
      end)

    %{state | items: filtered_items, selected_index: 0}
  end

  defp render_header(_state, width) do
    title = " My UI Plugin "
    padding = max(0, width - String.length(title)) |> div(2)

    %{
      text: String.pad_leading(title, width - padding) |> String.pad_trailing(width),
      style: %{bold: true, bg_color: :blue, fg_color: :white}
    }
  end

  defp render_search_box(%{search_query: query}, width) do
    search_text = " Search: #{query}"

    %{
      text: String.pad_trailing(search_text, width),
      style: %{bg_color: :gray}
    }
  end

  defp render_separator(width) do
    %{
      text: String.duplicate("-", width),
      style: %{fg_color: :gray}
    }
  end

  defp render_items(state, width, available_height) do
    state.items
    |> Enum.take(available_height)
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      selected = index == state.selected_index
      prefix = if selected, do: "> ", else: "  "
      text = prefix <> item.name

      %{
        text: String.pad_trailing(text, width),
        style: %{
          bg_color: if(selected, do: :cyan, else: :default),
          fg_color: if(selected, do: :black, else: :white)
        }
      }
    end)
  end
end
```

## Background Task Plugin Template

### Plugin with Periodic Updates

```elixir
defmodule Raxol.Plugins.MyBackgroundPlugin do
  @moduledoc """
  Template for plugins that run background tasks and periodic updates.
  """

  use GenServer
  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  def manifest do
    %{
      name: "my-background-plugin",
      version: "1.0.0",
      description: "Background task plugin template",
      author: "Your Name",
      api_version: "2.0",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [:status_line, :command_handler, :file_system_access],
      trust_level: :trusted,
      config_schema: %{
        update_interval_ms: %{type: :integer, default: 5000, min: 1000},
        watch_path: %{type: :string, default: "."},
        enabled: %{type: :boolean, default: true}
      }
    }
  end

  defstruct [
    :config,
    :enabled,
    :update_timer,
    :last_update,
    :cached_data,
    :status_info
  ]

  # GenServer API
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # Plugin behaviour callbacks
  def init(config) do
    state = %__MODULE__{
      config: config,
      enabled: false,
      update_timer: nil,
      last_update: nil,
      cached_data: %{},
      status_info: ""
    }

    {:ok, state}
  end

  def terminate(_reason, state) do
    if state.update_timer do
      :timer.cancel(state.update_timer)
    end
    :ok
  end

  def enable(state) do
    # Start background tasks
    {:ok, timer} = :timer.send_interval(
      state.config.update_interval_ms,
      :update_data
    )

    # Perform initial update
    send(self(), :update_data)

    new_state = %{state |
      enabled: true,
      update_timer: timer
    }

    Logger.info("[MyBackgroundPlugin] Background tasks started")
    {:ok, new_state}
  end

  def disable(state) do
    # Stop background tasks
    if state.update_timer do
      :timer.cancel(state.update_timer)
    end

    new_state = %{state |
      enabled: false,
      update_timer: nil
    }

    Logger.info("[MyBackgroundPlugin] Background tasks stopped")
    {:ok, new_state}
  end

  def handle_command(:status, _args, state) do
    status = generate_status_report(state)
    {:ok, state, status}
  end

  def handle_command(:refresh, _args, state) do
    send(self(), :update_data)
    {:ok, state, :refresh_requested}
  end

  def handle_command(:get_data, _args, state) do
    {:ok, state, state.cached_data}
  end

  def get_commands do
    [
      {:status, :handle_command, 3},
      {:refresh, :handle_command, 3},
      {:get_data, :handle_command, 3}
    ]
  end

  # GenServer callbacks for background processing
  @impl GenServer
  def handle_info(:update_data, state) do
    if state.enabled do
      new_data = collect_data(state.config)
      status_info = format_status_info(new_data)

      new_state = %{state |
        cached_data: new_data,
        status_info: status_info,
        last_update: DateTime.utc_now()
      }

      Logger.debug("[MyBackgroundPlugin] Data updated: #{inspect(new_data)}")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("[MyBackgroundPlugin] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_status_info, _from, state) do
    {:reply, state.status_info, state}
  end

  @impl GenServer
  def handle_cast({:update_config, new_config}, state) do
    # Handle config updates
    new_state = %{state | config: Map.merge(state.config, new_config)}
    {:noreply, new_state}
  end

  # Status line integration
  def get_status_line_info do
    try do
      GenServer.call(__MODULE__, :get_status_info, 1000)
    catch
      :exit, {:timeout, _} -> ""
      :exit, {:noproc, _} -> ""
    end
  end

  # Private functions
  defp collect_data(config) do
    # Implementation-specific data collection
    case File.stat(config.watch_path) do
      {:ok, stat} ->
        %{
          path: config.watch_path,
          size: stat.size,
          modified: stat.mtime,
          type: stat.type
        }

      {:error, reason} ->
        %{
          path: config.watch_path,
          error: reason
        }
    end
  end

  defp format_status_info(%{error: reason}) do
    "Error: #{reason}"
  end

  defp format_status_info(%{path: path, size: size}) do
    "#{Path.basename(path)}: #{format_size(size)}"
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{div(bytes, 1024)}KB"
  defp format_size(bytes), do: "#{div(bytes, 1024 * 1024)}MB"

  defp generate_status_report(state) do
    %{
      enabled: state.enabled,
      last_update: state.last_update,
      cached_data: state.cached_data,
      config: state.config
    }
  end
end
```

## File System Plugin Template

### Plugin that Monitors File Changes

```elixir
defmodule Raxol.Plugins.MyFileSystemPlugin do
  @moduledoc """
  Template for plugins that interact with the file system and monitor changes.
  """

  use GenServer
  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  def manifest do
    %{
      name: "my-filesystem-plugin",
      version: "1.0.0",
      description: "File system monitoring plugin template",
      author: "Your Name",
      api_version: "2.0",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [:file_system_access, :file_watcher, :command_handler],
      trust_level: :trusted,
      config_schema: %{
        watch_directories: %{type: :list, default: ["."]},
        watch_patterns: %{type: :list, default: ["**/*.ex", "**/*.exs"]},
        ignore_patterns: %{type: :list, default: ["**/.git/**", "**/node_modules/**"]},
        max_file_size_mb: %{type: :integer, default: 10}
      }
    }
  end

  defstruct [
    :config,
    :watchers,
    :file_index,
    :recent_changes
  ]

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  # Plugin behaviour callbacks
  def init(config) do
    state = %__MODULE__{
      config: config,
      watchers: %{},
      file_index: %{},
      recent_changes: []
    }

    {:ok, state}
  end

  def terminate(_reason, state) do
    # Stop all file watchers
    Enum.each(state.watchers, fn {_path, watcher} ->
      stop_file_watcher(watcher)
    end)
    :ok
  end

  def enable(state) do
    # Start file watchers for configured directories
    watchers =
      state.config.watch_directories
      |> Enum.reduce(%{}, fn dir, acc ->
        case start_file_watcher(dir, state.config) do
          {:ok, watcher} ->
            Map.put(acc, dir, watcher)
          {:error, reason} ->
            Logger.warning("Failed to watch #{dir}: #{reason}")
            acc
        end
      end)

    # Build initial file index
    file_index = build_file_index(state.config)

    new_state = %{state |
      watchers: watchers,
      file_index: file_index
    }

    Logger.info("[MyFileSystemPlugin] Started watching #{map_size(watchers)} directories")
    {:ok, new_state}
  end

  def disable(state) do
    # Stop all watchers
    Enum.each(state.watchers, fn {_path, watcher} ->
      stop_file_watcher(watcher)
    end)

    new_state = %{state |
      watchers: %{},
      file_index: %{}
    }

    {:ok, new_state}
  end

  def handle_command(:list_files, [pattern], state) do
    files = find_files_by_pattern(state.file_index, pattern)
    {:ok, state, files}
  end

  def handle_command(:recent_changes, _args, state) do
    changes = Enum.take(state.recent_changes, 10)
    {:ok, state, changes}
  end

  def handle_command(:file_info, [path], state) do
    info = get_file_info(path, state.file_index)
    {:ok, state, info}
  end

  def get_commands do
    [
      {:list_files, :handle_command, 3},
      {:recent_changes, :handle_command, 3},
      {:file_info, :handle_command, 3}
    ]
  end

  # GenServer callbacks for file events
  @impl GenServer
  def handle_info({:file_event, path, events}, state) do
    new_state = process_file_events(path, events, state)
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    Logger.debug("[MyFileSystemPlugin] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # File system operations
  defp start_file_watcher(path, config) do
    # This would integrate with the actual file watching system
    # For now, simulate with a process that sends periodic updates
    watcher = spawn_link(fn ->
      file_watcher_loop(path, config, self())
    end)

    {:ok, watcher}
  end

  defp stop_file_watcher(watcher) when is_pid(watcher) do
    Process.exit(watcher, :normal)
  end

  defp file_watcher_loop(path, config, parent) do
    # Simulate file change detection
    receive do
      :stop -> :ok
    after
      5000 ->
        # Check for actual changes (simplified)
        case scan_directory(path, config) do
          {:changes, changes} ->
            Enum.each(changes, fn change ->
              send(parent, {:file_event, change.path, [:modified]})
            end)
          :no_changes ->
            :ok
        end
        file_watcher_loop(path, config, parent)
    end
  end

  defp build_file_index(config) do
    config.watch_directories
    |> Enum.reduce(%{}, fn dir, acc ->
      case scan_directory(dir, config) do
        {:files, files} ->
          Enum.reduce(files, acc, fn file, file_acc ->
            Map.put(file_acc, file.path, file)
          end)
        {:error, _reason} ->
          acc
      end
    end)
  end

  defp scan_directory(path, config) do
    try do
      files =
        Path.wildcard(Path.join(path, "**/*"))
        |> Enum.filter(&File.regular?/1)
        |> Enum.filter(&matches_patterns?(&1, config.watch_patterns))
        |> Enum.reject(&matches_patterns?(&1, config.ignore_patterns))
        |> Enum.map(&create_file_entry/1)
        |> Enum.filter(fn file ->
          file.size_mb <= config.max_file_size_mb
        end)

      {:files, files}
    rescue
      error ->
        {:error, error}
    end
  end

  defp matches_patterns?(path, patterns) do
    Enum.any?(patterns, fn pattern ->
      # Simple pattern matching - in practice you'd use a proper glob library
      String.contains?(path, String.replace(pattern, "*", ""))
    end)
  end

  defp create_file_entry(path) do
    stat = File.stat!(path)

    %{
      path: path,
      name: Path.basename(path),
      directory: Path.dirname(path),
      size: stat.size,
      size_mb: stat.size / (1024 * 1024),
      modified: stat.mtime,
      type: get_file_type(path)
    }
  end

  defp get_file_type(path) do
    case Path.extname(path) do
      ".ex" -> :elixir
      ".exs" -> :elixir_script
      ".md" -> :markdown
      ".json" -> :json
      ".toml" -> :toml
      _ -> :other
    end
  end

  defp process_file_events(path, events, state) do
    change_entry = %{
      path: path,
      events: events,
      timestamp: DateTime.utc_now()
    }

    # Update file index
    new_file_index = case :modified in events do
      true ->
        updated_entry = create_file_entry(path)
        Map.put(state.file_index, path, updated_entry)
      false ->
        state.file_index
    end

    # Add to recent changes (keep last 50)
    new_recent_changes =
      [change_entry | state.recent_changes]
      |> Enum.take(50)

    %{state |
      file_index: new_file_index,
      recent_changes: new_recent_changes
    }
  end

  defp find_files_by_pattern(file_index, pattern) do
    file_index
    |> Enum.filter(fn {path, _info} ->
      String.contains?(String.downcase(path), String.downcase(pattern))
    end)
    |> Enum.map(fn {_path, info} -> info end)
    |> Enum.sort_by(& &1.modified, {:desc, DateTime})
  end

  defp get_file_info(path, file_index) do
    case Map.get(file_index, path) do
      nil -> {:error, :not_found}
      info -> {:ok, info}
    end
  end
end
```

## Testing Template

### Comprehensive Plugin Tests

```elixir
defmodule MyPluginTest do
  use ExUnit.Case, async: true

  alias Raxol.Plugins.MyPlugin

  describe "plugin manifest" do
    test "returns valid manifest structure" do
      manifest = MyPlugin.manifest()

      assert is_binary(manifest.name)
      assert is_binary(manifest.version)
      assert is_binary(manifest.description)
      assert is_binary(manifest.author)
      assert is_map(manifest.dependencies)
      assert is_list(manifest.capabilities)
      assert manifest.trust_level in [:trusted, :sandboxed, :untrusted]
    end

    test "has required dependencies" do
      manifest = MyPlugin.manifest()
      assert Map.has_key?(manifest.dependencies, "raxol-core")
    end
  end

  describe "plugin lifecycle" do
    test "initializes with valid config" do
      config = %{enabled: true, debug: false}

      assert {:ok, state} = MyPlugin.init(config)
      assert state.config == config
      assert is_boolean(state.enabled)
    end

    test "handles enable/disable cycle" do
      config = %{enabled: true}
      {:ok, initial_state} = MyPlugin.init(config)

      # Test enable
      assert {:ok, enabled_state} = MyPlugin.enable(initial_state)
      assert enabled_state.enabled == true

      # Test disable
      assert {:ok, disabled_state} = MyPlugin.disable(enabled_state)
      assert disabled_state.enabled == false
    end

    test "terminates cleanly" do
      config = %{enabled: true}
      {:ok, state} = MyPlugin.init(config)

      assert :ok = MyPlugin.terminate(:normal, state)
    end
  end

  describe "command handling" do
    setup do
      config = %{enabled: true}
      {:ok, state} = MyPlugin.init(config)
      {:ok, enabled_state} = MyPlugin.enable(state)

      {:ok, state: enabled_state}
    end

    test "handles hello command", %{state: state} do
      assert {:ok, new_state, result} = MyPlugin.handle_command(:hello, [], state)
      assert is_binary(result)
      assert String.contains?(result, "Hello")
      assert new_state.enabled == true
    end

    test "returns error for unknown command", %{state: state} do
      assert {:error, reason, _state} = MyPlugin.handle_command(:unknown, [], state)
      assert String.contains?(reason, "Unknown command")
    end

    test "declares available commands" do
      commands = MyPlugin.get_commands()
      assert is_list(commands)
      assert {:hello, :handle_command, 3} in commands
    end
  end

  describe "event filtering" do
    setup do
      config = %{enabled: true}
      {:ok, state} = MyPlugin.init(config)
      {:ok, state: state}
    end

    test "passes through events by default", %{state: state} do
      event = {:key_press, "a"}
      assert {:ok, ^event} = MyPlugin.filter_event(event, state)
    end

    test "can modify events", %{state: state} do
      # This test would be specific to your plugin's event handling
      event = {:test_event, "data"}
      assert {:ok, filtered_event} = MyPlugin.filter_event(event, state)
      # Add assertions based on your plugin's behavior
    end
  end
end

# Integration test template
defmodule MyPluginIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  setup do
    # Setup test environment
    config = %{enabled: true, debug: true}
    {:ok, config: config}
  end

  test "plugin integrates with plugin system", %{config: config} do
    # Test plugin loading and integration
    # This would require the actual plugin system to be running

    # For now, just test that the plugin can be initialized
    assert {:ok, _state} = MyPlugin.init(config)
  end

  test "plugin commands are accessible" do
    commands = MyPlugin.get_commands()

    # Verify commands are properly formatted
    Enum.each(commands, fn {name, function, arity} ->
      assert is_atom(name)
      assert is_atom(function)
      assert is_integer(arity)
      assert arity >= 0
    end)
  end
end
```

## Usage Examples

### Loading and Using Templates

1. **Choose appropriate template** based on your plugin needs:
   - Basic Plugin: Simple functionality without UI
   - UI Plugin: Interactive overlays and panels
   - Background Plugin: Periodic tasks and monitoring
   - File System Plugin: File watching and directory operations

2. **Customize the template**:
   - Replace placeholder names and descriptions
   - Implement your specific functionality
   - Add required dependencies to manifest
   - Configure appropriate capabilities

3. **Test thoroughly**:
   - Use the provided test templates
   - Test all lifecycle states
   - Verify command handling
   - Test event filtering if implemented

4. **Follow best practices**:
   - Clean up resources in `terminate/2`
   - Handle errors gracefully
   - Use appropriate logging levels
   - Document your plugin's functionality

These templates provide a solid foundation for creating robust, well-structured plugins that integrate seamlessly with the Raxol plugin system.