defmodule Raxol.Test.Support.MockImplementations do
  @moduledoc """
  Provides mock implementations for testing.
  This module contains the actual implementations that Mox will use.
  """

  # Mock implementations for Mox to use
  # These are NOT modules, just functions that Mox will call

  # FileWatcher mock implementation
  def file_watcher_start_link(_opts), do: {:ok, self()}
  def file_watcher_watch(_path), do: :ok
  def file_watcher_unwatch(_path), do: :ok
  def file_watcher_stop(_pid), do: :ok

  # Loader mock implementation
  def loader_load_module(_module), do: {:ok, :loaded}
  def loader_unload_module(_module), do: {:ok, :unloaded}
  def loader_reload_module(_module), do: {:ok, :reloaded}
  def loader_list_modules, do: {:ok, []}

  # Accessibility mock implementation
  def accessibility_enable(_options), do: :ok
  def accessibility_disable, do: :ok
  def accessibility_is_enabled, do: true
  def accessibility_get_settings, do: %{high_contrast: false}

  # Clipboard mock implementation
  def clipboard_copy(_text), do: :ok
  def clipboard_paste, do: {:ok, "mocked clipboard content"}
  def clipboard_clear, do: :ok

  # LifecycleHelper mock implementation
  def lifecycle_helper_start(_module), do: {:ok, self()}
  def lifecycle_helper_stop(_module), do: :ok
  def lifecycle_helper_restart(_module), do: {:ok, self()}

  # DeltaUpdaterSystemAdapter mock implementation
  def delta_updater_system_adapter_apply_delta(_delta), do: {:ok, :applied}
  def delta_updater_system_adapter_revert_delta(_delta), do: {:ok, :reverted}

  # EnvironmentAdapter mock implementation
  def environment_adapter_get_env(_key), do: {:ok, "mocked_value"}
  def environment_adapter_set_env(_key, _value), do: :ok

  # FileSystem mock implementation
  def file_system_read_file(_path), do: {:ok, "mocked file content"}
  def file_system_write_file(_path, _content), do: :ok
  def file_system_delete_file(_path), do: :ok

  # SystemInteraction mock implementation
  def system_interaction_execute_command(_command), do: {:ok, "mocked output"}
  def system_interaction_get_process_info(_pid), do: {:ok, %{memory: 1024}}

  # KeyboardShortcuts mock implementation
  def keyboard_shortcuts_register(_key, _action), do: :ok
  def keyboard_shortcuts_unregister(_key), do: :ok
  def keyboard_shortcuts_handle_key(_key), do: :ok

  # Terminal mock implementations
  def sixel_graphics_render_sixel(_data, _position), do: :ok
  def sixel_graphics_clear_sixel(_position), do: :ok

  def terminal_parser_state_get_state, do: %{mode: :normal}
  def terminal_parser_state_set_state(state), do: {:ok, state}

  def terminal_screen_buffer_get_buffer, do: {:ok, []}
  def terminal_screen_buffer_set_buffer(buffer), do: {:ok, buffer}
  def terminal_screen_buffer_clear_buffer, do: {:ok, []}

  def terminal_emulator_new, do: %{mock: :emulator}
  def terminal_emulator_new(width, height), do: %{mock: :emulator, width: width, height: height}
  def terminal_emulator_new(width, height, opts), do: %{mock: :emulator, width: width, height: height, opts: opts}
  def terminal_emulator_new(width, height, session_id, client_options) do
    {:ok, %{mock: :emulator, width: width, height: height, session_id: session_id, client_options: client_options}}
  end
  def terminal_emulator_get_active_buffer(_emulator), do: %{mock: :screen_buffer}
  def terminal_emulator_update_active_buffer(emulator, _new_buffer), do: emulator
  def terminal_emulator_process_input(emulator, _input), do: {emulator, ""}
  def terminal_emulator_resize(emulator, _new_width, _new_height), do: emulator
  def terminal_emulator_get_cursor_position(_emulator), do: {0, 0}
  def terminal_emulator_get_cursor_visible(_emulator), do: true

  # Plugin mock implementations
  def clipboard_plugin_init(config), do: {:ok, config}
  def clipboard_plugin_handle_event(_event, state), do: {:ok, state}
  def clipboard_plugin_handle_command(_command, _args, state), do: {:ok, state}

  def plugin_event_filter_filter_event(_event), do: {:ok, _event}
  def plugin_event_filter_should_process_event?(_event), do: true

  def plugin_command_dispatcher_dispatch_command(_command, _args), do: {:ok, %{}}
  def plugin_command_dispatcher_register_command(_command, _handler), do: :ok

  def plugin_reloader_reload_plugin(_module), do: {:ok, _module}
  def plugin_reloader_reload_all_plugins, do: {:ok, []}

  def plugin_command_handler_handle_command(_command, _args, state), do: {:ok, state}
  def plugin_command_handler_register_handler(_command, _handler), do: :ok

  def timer_manager_start_timer(_duration, _callback), do: {:ok, self()}
  def timer_manager_stop_timer(_timer), do: :ok
  def timer_manager_reset_timer(_timer), do: {:ok, self()}

  # Rendering mock implementations
  def rendering_engine_render(_state), do: {:ok, []}
  def rendering_engine_clear, do: :ok
  def rendering_engine_update(_changes), do: {:ok, []}

  # Event mock implementations
  def events_manager_publish_event(_event), do: :ok
  def events_manager_subscribe(_event_type, _handler), do: {:ok, self()}
  def events_manager_unsubscribe(_subscription), do: :ok

  # Terminal buffer mock implementations
  def terminal_buffer_manager_get_buffer, do: {:ok, []}
  def terminal_buffer_manager_set_buffer(buffer), do: {:ok, buffer}
  def terminal_buffer_manager_clear_buffer, do: {:ok, []}

  def terminal_buffer_scrollback_get_scrollback, do: {:ok, []}
  def terminal_buffer_scrollback_add_to_scrollback(_line), do: {:ok, []}
  def terminal_buffer_scrollback_clear_scrollback, do: {:ok, []}

  def terminal_buffer_scroll_region_get_scroll_region, do: {:ok, {0, 0}}
  def terminal_buffer_scroll_region_set_scroll_region(_region), do: {:ok, {0, 0}}

  def terminal_buffer_selection_get_selection, do: {:ok, nil}
  def terminal_buffer_selection_set_selection(_selection), do: {:ok, nil}
  def terminal_buffer_selection_clear_selection, do: {:ok, nil}

  def terminal_buffer_queries_get_line(_index), do: {:ok, ""}
  def terminal_buffer_queries_get_lines(_start, _end), do: {:ok, []}
  def terminal_buffer_queries_get_all_lines, do: {:ok, []}

  def terminal_buffer_line_operations_insert_line(_index, _line), do: {:ok, []}
  def terminal_buffer_line_operations_delete_line(_index), do: {:ok, []}
  def terminal_buffer_line_operations_update_line(_index, _line), do: {:ok, []}
end
