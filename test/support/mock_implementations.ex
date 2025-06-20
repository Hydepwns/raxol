defmodule Raxol.Test.Support.MockImplementations do
  @moduledoc """
  Provides default implementations for all mocks used in tests.
  These implementations provide basic functionality that can be overridden
  in individual tests as needed.
  """

  # Core mock implementations
  defmodule FileWatcherMock do
    @behaviour Raxol.Core.Runtime.Plugins.FileWatcher.Behaviour

    @impl true
    def setup_file_watching(state),
      do: {self(), true}

    @impl true
    def handle_file_event(_path, state), do: {:ok, state}

    @impl true
    def handle_debounced_events(state), do: {:ok, state}

    @impl true
    def update_file_watcher(state), do: state

    @impl true
    def cleanup_file_watching(state), do: state
  end

  defmodule LoaderMock do
    @behaviour Raxol.Core.Runtime.Plugins.LoaderBehaviour

    @impl true
    def load_plugin(_plugin_path), do: {:ok, :mock_plugin}

    @impl true
    def unload_plugin(_plugin), do: :ok

    @impl true
    def reload_plugin(_plugin), do: {:ok, :mock_plugin}

    @impl true
    def get_loaded_plugins, do: [:mock_plugin]

    @impl true
    def is_plugin_loaded?(_plugin), do: true
  end

  defmodule AccessibilityMock do
    @behaviour Raxol.Core.Accessibility.Behaviour

    @impl true
    def set_large_text(_enabled, _user_preferences_pid_or_name), do: :ok

    @impl true
    def get_focus_history, do: []

    # Additional functions that exist in the real Accessibility module
    def enable(_options \\ [], _user_preferences_pid_or_name \\ nil), do: :ok
    def disable(_user_preferences_pid_or_name \\ nil), do: :ok
  end

  defmodule ClipboardMock do
    @behaviour Raxol.Core.Clipboard.Behaviour

    @impl true
    def copy(_content), do: :ok

    @impl true
    def paste, do: {:ok, ""}
  end

  # Runtime plugin mock implementations
  defmodule LifecycleHelperMock do
    @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour

    @impl true
    def load_plugin(
          plugin_id_or_module,
          config,
          plugins,
          metadata,
          plugin_states,
          load_order,
          command_table,
          plugin_config
        ) do
      {:ok, %{}}
    end

    @impl true
    def unload_plugin(
          plugin_id,
          plugins,
          metadata,
          plugin_states,
          load_order,
          command_table
        ) do
      {:ok, %{}}
    end

    @impl true
    def reload_plugin(
          plugin_id,
          plugins,
          metadata,
          plugin_states,
          load_order,
          command_table,
          plugin_config
        ) do
      {:ok, %{}}
    end

    @impl true
    def initialize_plugins(
          plugin_specs,
          manager_pid,
          plugin_registry,
          command_registry_table,
          api_version,
          app_config,
          env
        ) do
      {:ok, {[], []}}
    end

    @impl true
    def reload_plugin_from_disk(
          plugin_id,
          current_state,
          plugin_spec,
          manager_pid,
          plugin_registry,
          command_registry_table,
          api_version,
          loaded_plugins_paths
        ) do
      {:ok, %{}}
    end

    @impl true
    def load_plugin_by_module(
          plugin_module,
          config,
          plugins,
          metadata,
          plugin_states,
          load_order,
          command_table,
          plugin_config
        ) do
      {:ok, %{}}
    end

    @impl true
    def init_plugin(module, opts) do
      {:ok, opts}
    end

    @impl true
    def terminate_plugin(plugin_id, state, reason) do
      :ok
    end

    @impl true
    def cleanup_plugin(plugin_id, state) do
      :ok
    end

    @impl true
    def handle_state_transition(plugin_id, transition, state) do
      {:ok, state}
    end
  end

  # System mock implementations
  defmodule DeltaUpdaterSystemAdapterMock do
    @behaviour Raxol.System.DeltaUpdaterSystemAdapterBehaviour

    @impl true
    def httpc_request(method, url_with_headers, http_options, stream_options) do
      {:ok, {{~c"HTTP/1.1", 200, ~c"OK"}, [], ~c"test content"}}
    end

    @impl true
    def os_type, do: {:unix, :darwin}

    @impl true
    def system_tmp_dir, do: {:ok, "/tmp"}

    @impl true
    def system_get_env(varname), do: "test_value"

    @impl true
    def system_argv, do: []

    @impl true
    def system_cmd(command, args, options) do
      {"", 0}
    end

    @impl true
    def file_mkdir_p(path), do: :ok

    @impl true
    def file_rm_rf(path), do: :ok

    @impl true
    def file_chmod(path, mode), do: :ok

    @impl true
    def updater_do_replace_executable(current_exe, new_exe, platform), do: :ok

    @impl true
    def current_version, do: "0.1.0"

    @impl true
    def http_get(url), do: {:ok, "test content"}
  end

  defmodule EnvironmentAdapterMock do
    @behaviour Raxol.Terminal.Config.EnvironmentAdapterBehaviour

    @impl true
    def get_env(key), do: {:ok, "test_value"}

    @impl true
    def set_env(key, value), do: :ok

    @impl true
    def get_all_env, do: {:ok, %{}}

    @impl true
    def get_terminal_config, do: {:ok, %{}}

    @impl true
    def update_terminal_config(config), do: :ok

    @impl true
    def get_terminal_type, do: {:ok, "xterm-256color"}

    @impl true
    def supports_feature?(_feature), do: true
  end

  defmodule FileSystemMock do
    @behaviour FileSystem.Behaviour

    @impl true
    def start_link(dirs: dirs) do
      {:ok, self()}
    end

    @impl true
    def subscribe(pid) do
      :ok
    end
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
    @behaviour Raxol.Core.Runtime.Plugins.SixelGraphics.Behaviour

    @impl true
    def render_sixel(_data, _position), do: :ok

    @impl true
    def clear_sixel(_position), do: :ok
  end

  defmodule StateMock do
    @behaviour Raxol.Core.Runtime.Plugins.State.Behaviour

    @impl true
    def get_state, do: %{mode: :normal}

    @impl true
    def set_state(state), do: {:ok, state}
  end

  defmodule ScreenBufferMock do
    @behaviour Raxol.Core.Runtime.Plugins.ScreenBuffer.Behaviour

    @impl true
    def get_buffer, do: {:ok, []}

    @impl true
    def set_buffer(buffer), do: {:ok, buffer}

    @impl true
    def clear_buffer, do: {:ok, []}
  end

  defmodule EmulatorMock do
    @behaviour Raxol.Terminal.EmulatorBehaviour

    @impl true
    def new(), do: %{mock: :emulator}

    @impl true
    def new(width, height), do: %{mock: :emulator, width: width, height: height}

    @impl true
    def new(width, height, opts),
      do: %{mock: :emulator, width: width, height: height, opts: opts}

    @impl true
    def new(width, height, session_id, client_options) do
      {:ok,
       %{
         mock: :emulator,
         width: width,
         height: height,
         session_id: session_id,
         client_options: client_options
       }}
    end

    @impl true
    def get_active_buffer(_emulator), do: %{mock: :screen_buffer}

    @impl true
    def update_active_buffer(emulator, _new_buffer), do: emulator

    @impl true
    def process_input(emulator, _input), do: {emulator, ""}

    @impl true
    def resize(emulator, _new_width, _new_height), do: emulator

    @impl true
    def get_cursor_position(_emulator), do: {0, 0}

    @impl true
    def get_cursor_visible(_emulator), do: true
  end

  # Plugin mock implementations
  defmodule ClipboardPluginMock do
    @behaviour Raxol.Core.Runtime.Plugins.ClipboardPlugin.Behaviour

    @impl true
    def init(config), do: {:ok, config}

    @impl true
    def handle_event(_event, state), do: {:ok, state}

    @impl true
    def handle_command(_command, _args, state), do: {:ok, state}
  end

  defmodule PluginEventFilterMock do
    @behaviour Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour

    @impl true
    def filter_event(_event), do: {:ok, _event}

    @impl true
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
    @behaviour Raxol.Core.Runtime.Plugins.EventManager.Behaviour

    @impl true
    def publish_event(_event), do: :ok

    @impl true
    def subscribe(_event_type, _handler), do: {:ok, self()}

    @impl true
    def unsubscribe(_subscription), do: :ok
  end

  # Terminal buffer mock implementations
  defmodule BufferManagerMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferManager.Behaviour

    @impl true
    def get_buffer, do: {:ok, []}

    @impl true
    def set_buffer(buffer), do: {:ok, buffer}

    @impl true
    def clear_buffer, do: {:ok, []}
  end

  defmodule BufferScrollbackMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferScrollback.Behaviour

    @impl true
    def get_scrollback, do: {:ok, []}

    @impl true
    def add_to_scrollback(_line), do: {:ok, []}

    @impl true
    def clear_scrollback, do: {:ok, []}
  end

  defmodule BufferScrollRegionMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferScrollRegion.Behaviour

    @impl true
    def get_scroll_region, do: {:ok, {0, 0}}

    @impl true
    def set_scroll_region(_region), do: {:ok, {0, 0}}
  end

  defmodule BufferSelectionMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferSelection.Behaviour

    @impl true
    def get_selection, do: {:ok, nil}

    @impl true
    def set_selection(_selection), do: {:ok, nil}

    @impl true
    def clear_selection, do: {:ok, nil}
  end

  defmodule BufferQueriesMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferQueries.Behaviour

    @impl true
    def get_line(_index), do: {:ok, ""}

    @impl true
    def get_cell(_x, _y), do: {:ok, ""}

    @impl true
    def get_dimensions, do: {:ok, {80, 24}}
  end

  defmodule BufferLineOperationsMock do
    @behaviour Raxol.Core.Runtime.Plugins.BufferLineOperations.Behaviour

    @impl true
    def insert_line(_index, _line), do: {:ok, []}

    @impl true
    def delete_line(_index), do: {:ok, []}

    @impl true
    def move_line(_from, _to), do: {:ok, []}
  end
end
