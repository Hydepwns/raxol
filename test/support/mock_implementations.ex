defmodule Raxol.Test.Support.MockImplementations do
  @moduledoc """
  Provides default implementations for all mocks used in tests.
  These implementations provide basic functionality that can be overridden
  in individual tests as needed.
  """

  # Core mock implementations
  defmodule FileWatcherMock do
    def setup_file_watching(state), do: {:ok, Map.put(state, :file_watcher_pid, self())}
    def stop_file_watching(state), do: {:ok, Map.delete(state, :file_watcher_pid)}
    def handle_file_event(_event, state), do: {:ok, state}
  end

  defmodule LoaderMock do
    def load_plugin_module(module), do: {:ok, module}
    def initialize_plugin(_module, config), do: {:ok, Map.put(config, :initialized, true)}
    def behaviour_implemented?(_module, _behaviour), do: true
    def load_plugin_metadata(_module) do
      {:ok, %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        dependencies: []
      }}
    end
  end

  defmodule AccessibilityMock do
    def get_accessibility_state, do: {:ok, %{enabled: true}}
    def set_accessibility_state(state), do: {:ok, state}
    def is_accessibility_enabled?, do: true
  end

  defmodule ClipboardMock do
    def get_clipboard_content, do: {:ok, ""}
    def set_clipboard_content(content), do: {:ok, content}
  end

  # Runtime plugin mock implementations
  defmodule LifecycleHelperMock do
    def initialize_plugin(_module, config), do: {:ok, Map.put(config, :initialized, true)}
    def handle_plugin_event(_event, state), do: {:ok, state}
    def cleanup_plugin(_module, state), do: {:ok, state}
  end

  # System mock implementations
  defmodule DeltaUpdaterSystemAdapterMock do
    def get_system_delta, do: {:ok, %{changes: []}}
    def apply_system_delta(delta), do: {:ok, delta}
  end

  defmodule EnvironmentAdapterMock do
    def get_environment_variable(key), do: {:ok, System.get_env(key)}
    def set_environment_variable(key, value), do: {:ok, value}
  end

  defmodule FileSystemMock do
    def read_file(path), do: {:ok, "test content"}
    def write_file(path, content), do: {:ok, content}
    def delete_file(path), do: :ok
    def list_directory(path), do: {:ok, []}
  end

  defmodule SystemInteractionMock do
    def execute_command(command), do: {:ok, {command, 0, ""}}
    def get_system_info, do: {:ok, %{os: :unix, version: "1.0.0"}}
  end

  # Feature mock implementations
  defmodule KeyboardShortcutsMock do
    def register_shortcut(_key, _action), do: :ok
    def unregister_shortcut(_key), do: :ok
    def handle_shortcut(_key), do: :ok
  end

  # Terminal mock implementations
  defmodule SixelGraphicsMock do
    def render_sixel(_data, _position), do: :ok
    def clear_sixel(_position), do: :ok
  end

  defmodule StateMock do
    def get_state, do: %{mode: :normal}
    def set_state(state), do: {:ok, state}
  end

  defmodule ScreenBufferMock do
    def get_buffer, do: {:ok, []}
    def set_buffer(buffer), do: {:ok, buffer}
    def clear_buffer, do: {:ok, []}
  end

  defmodule EmulatorMock do
    def write(_data), do: :ok
    def resize(_width, _height), do: :ok
    def destroy, do: :ok
  end

  # Plugin mock implementations
  defmodule ClipboardPluginMock do
    def init(config), do: {:ok, config}
    def handle_event(_event, state), do: {:ok, state}
    def handle_command(_command, _args, state), do: {:ok, state}
  end

  defmodule PluginEventFilterMock do
    def filter_event(_event), do: {:ok, _event}
    def should_process_event?(_event), do: true
  end

  defmodule PluginCommandDispatcherMock do
    def dispatch_command(_command, _args), do: {:ok, %{}}
    def register_command(_command, _handler), do: :ok
  end

  defmodule PluginReloaderMock do
    def reload_plugin(_module), do: {:ok, _module}
    def reload_all_plugins, do: {:ok, []}
  end

  defmodule PluginCommandHandlerMock do
    def handle_command(_command, _args, state), do: {:ok, state}
    def register_handler(_command, _handler), do: :ok
  end

  defmodule TimerManagerMock do
    def start_timer(_duration, _callback), do: {:ok, self()}
    def stop_timer(_timer), do: :ok
    def reset_timer(_timer), do: {:ok, self()}
  end

  # Rendering mock implementations
  defmodule EngineMock do
    def render(_state), do: {:ok, []}
    def clear, do: :ok
    def update(_changes), do: {:ok, []}
  end

  # Event mock implementations
  defmodule EventManagerMock do
    def publish_event(_event), do: :ok
    def subscribe(_event_type, _handler), do: {:ok, self()}
    def unsubscribe(_subscription), do: :ok
  end

  # Terminal buffer mock implementations
  defmodule BufferManagerMock do
    def get_buffer, do: {:ok, []}
    def set_buffer(buffer), do: {:ok, buffer}
    def clear_buffer, do: {:ok, []}
  end

  defmodule BufferScrollbackMock do
    def get_scrollback, do: {:ok, []}
    def add_to_scrollback(_line), do: {:ok, []}
    def clear_scrollback, do: {:ok, []}
  end

  defmodule BufferScrollRegionMock do
    def get_scroll_region, do: {:ok, {0, 0}}
    def set_scroll_region(_region), do: {:ok, {0, 0}}
  end

  defmodule BufferSelectionMock do
    def get_selection, do: {:ok, nil}
    def set_selection(_selection), do: {:ok, nil}
    def clear_selection, do: {:ok, nil}
  end

  defmodule BufferQueriesMock do
    def get_line(_index), do: {:ok, ""}
    def get_cell(_x, _y), do: {:ok, ""}
    def get_dimensions, do: {:ok, {80, 24}}
  end

  defmodule BufferLineOperationsMock do
    def insert_line(_index, _line), do: {:ok, []}
    def delete_line(_index), do: {:ok, []}
    def move_line(_from, _to), do: {:ok, []}
  end
end
