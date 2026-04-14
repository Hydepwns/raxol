# `Raxol.Terminal.SessionManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager.ex#L1)

Terminal multiplexing system providing tmux-like session management for Raxol.

This module implements comprehensive terminal session multiplexing with:
- Multiple terminal sessions with independent state
- Window and pane management within sessions
- Session persistence across disconnections
- Remote session attachment and detachment
- Session sharing and collaboration features
- Automatic session recovery and state preservation
- Advanced session management (naming, grouping, tagging)

## Features

### Session Management
- Create, destroy, and switch between multiple sessions
- Named sessions with metadata and tags
- Session persistence to disk with state recovery
- Automatic cleanup of orphaned sessions
- Session templates and presets

### Window and Pane Management
- Multiple windows per session
- Split windows into panes (horizontal/vertical)
- Pane resizing and layout management
- Window/pane navigation and switching
- Synchronized input across panes

### Advanced Features
- Session sharing between multiple clients
- Remote session access over network
- Session recording and playback
- Custom session hooks and automation
- Resource monitoring and limits

## Usage

    # Create a new session
    {:ok, session} = SessionManager.create_session("dev-session",
      windows: 3,
      layout: :main_vertical
    )

    # Attach to an existing session
    {:ok, client} = SessionManager.attach_session("dev-session")

    # Create window with panes
    {:ok, window} = SessionManager.create_window(session, "editor",
      panes: [
        %{command: "nvim", directory: "/home/user/project"},
        %{command: "bash", directory: "/home/user/project"}
      ]
    )

    # Detach and session continues running
    SessionManager.detach_client(client)

# `session_config`

```elixir
@type session_config() :: %{
  name: String.t(),
  windows: integer(),
  layout: Raxol.Terminal.SessionManager.Window.layout_type(),
  working_directory: String.t(),
  environment: map(),
  persistence: boolean(),
  resource_limits: map()
}
```

# `attach_session`

Attaches a client to a session.

# `broadcast_input`

Broadcasts input to all panes in a window (synchronized input).

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_session`

Creates a new terminal session.

## Examples

    {:ok, session} = SessionManager.create_session("dev",
      windows: 2,
      layout: :main_vertical,
      working_directory: "/home/user/project"
    )

# `create_window`

Creates a new window in a session.

# `destroy_session`

Destroys a session and all its windows/panes.

# `destroy_window`

Destroys a window and all its panes.

# `detach_client`

Detaches a client from their current session.

# `enable_session_sharing`

Enables session sharing for collaboration.

# `get_session`

Gets detailed information about a session.

# `get_session_stats`

Gets session statistics and resource usage.

# `handle_manager_cast`

# `list_sessions`

Lists all available sessions.

# `resize_pane`

Resizes a pane.

# `restore_session`

Restores session from persistent storage.

# `save_session`

Saves session state to persistent storage.

# `send_input`

Sends input to a specific pane.

# `split_pane`

Splits a pane horizontally or vertically.

# `start_link`

# `switch_pane`

Switches the active pane in a window.

# `switch_window`

Switches the active window in a session.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
