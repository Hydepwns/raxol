# FileWatcher Module Architecture

## Overview

The FileWatcher module is responsible for monitoring plugin source files and triggering reloads when changes are detected. It has been refactored into a modular architecture to improve maintainability, testability, and separation of concerns.

## Module Structure

### Main Module: `Raxol.Core.Runtime.Plugins.FileWatcher`

The main module serves as the public API and delegates to specialized submodules. It provides a clean interface for:

- Setting up file watching
- Handling file events
- Managing plugin reloads
- Cleaning up resources

### Submodules

#### 1. `FileWatcher.Core`

- **Responsibility**: Core setup and state management
- **Key Functions**:
  - `setup_file_watching/1`: Initializes the file system watcher
  - `update_file_watcher/1`: Maintains the reverse path mapping for plugin files
- **State Management**:
  - Tracks plugin directories
  - Maintains reverse path mappings
  - Manages file watching enabled state

#### 2. `FileWatcher.Events`

- **Responsibility**: Event handling and debouncing
- **Key Functions**:
  - `handle_file_event/2`: Processes file system events
  - `handle_debounced_events/3`: Manages debounced plugin reloads
- **Features**:
  - Path normalization
  - Event debouncing
  - File type validation
  - Timer management

#### 3. `FileWatcher.Reload`

- **Responsibility**: Plugin reloading logic
- **Key Functions**:
  - `reload_plugin/2`: Handles the plugin reload process
- **Process**:
  1. Verifies plugin existence
  2. Unloads the current plugin
  3. Reloads the plugin from source
  4. Handles errors and edge cases

#### 4. `FileWatcher.Cleanup`

- **Responsibility**: Resource cleanup
- **Key Functions**:
  - `cleanup_file_watching/1`: Cleans up file watching resources
- **Features**:
  - Process termination
  - Timer cancellation
  - State cleanup
  - Idempotent operations

## State Management

The FileWatcher maintains the following state:

```elixir
%{
  plugin_dirs: [String.t()],           # List of directories to watch
  plugin_paths: %{String.t() => String.t()},  # Plugin ID to path mapping
  reverse_plugin_paths: %{String.t() => String.t()},  # Path to plugin ID mapping
  file_watcher_pid: pid() | nil,       # File system watcher process
  file_event_timer: reference() | nil,  # Debounce timer reference
  file_watching_enabled?: boolean()    # File watching status
}
```

## Event Flow

1. **File Change Detection**:

   - File system watcher detects changes
   - Event is passed to `handle_file_event/2`

2. **Event Processing**:

   - Path is normalized
   - File type is validated
   - Existing timer is cancelled if present
   - New debounce timer is scheduled

3. **Debounced Reload**:

   - Timer triggers after debounce period
   - `handle_debounced_events/3` is called
   - Plugin is reloaded via `reload_plugin/2`

4. **Cleanup**:
   - Resources are cleaned up on shutdown
   - Processes are terminated
   - Timers are cancelled
   - State is reset

## Error Handling

The module implements comprehensive error handling:

- File access errors
- Plugin not found
- Unload failures
- Load failures
- Unexpected errors during reload

## Testing

Each submodule has its own test suite:

- `CoreTest`: Tests setup and state management
- `EventsTest`: Tests event handling and debouncing
- `ReloadTest`: Tests plugin reloading
- `CleanupTest`: Tests resource cleanup

## Usage Example

```elixir
# Initialize file watching
state = %{
  plugin_dirs: ["plugins"],
  plugin_paths: %{"my_plugin" => "plugins/my_plugin.ex"},
  file_watching_enabled?: false
}

# Setup file watching
{pid, enabled?} = FileWatcher.setup_file_watching(state)
state = %{state | file_watcher_pid: pid, file_watching_enabled?: enabled?}

# Update file watcher with new paths
state = FileWatcher.update_file_watcher(state)

# Cleanup on shutdown
state = FileWatcher.cleanup_file_watching(state)
```

## Best Practices

1. **State Management**:

   - Always update state atomically
   - Use immutable state updates
   - Handle all state transitions explicitly

2. **Error Handling**:

   - Use pattern matching for error cases
   - Provide detailed error messages
   - Log errors appropriately

3. **Resource Management**:

   - Clean up resources promptly
   - Handle cleanup failures gracefully
   - Ensure idempotent cleanup operations

4. **Testing**:
   - Test all error cases
   - Verify state transitions
   - Mock external dependencies
   - Test concurrent operations
