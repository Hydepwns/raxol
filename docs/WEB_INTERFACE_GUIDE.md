---
title: Raxol Web Interface Guide
description: Guide to building and deploying web-based terminal applications
date: 2025-08-10
author: Raxol Team
section: documentation
tags: [web, interface, phoenix, liveview, guide]
---

# Raxol Web Interface Guide

## Overview

Raxol's web interface enables you to access terminal applications through any modern web browser. Built on Phoenix LiveView, it provides real-time, bidirectional communication between the browser and your terminal application with support for multiple users, collaboration features, and persistent sessions.

## Key Features

- **Real-Time Synchronization**: Changes in the terminal are instantly reflected in all connected browsers
- **Multi-User Support**: Multiple users can connect to the same session simultaneously
- **Collaborative Features**: Shared cursors, synchronized state, and presence tracking
- **Session Persistence**: Terminal sessions survive browser refreshes and reconnections
- **Full Terminal Emulation**: Complete ANSI/VT100+ support in the browser
- **Responsive Design**: Works on desktop, tablet, and mobile devices

## Architecture

```
Browser <-> Phoenix LiveView <-> WebSocket <-> Terminal Session
                                      |
                                 Session Manager
                                      |
                              Terminal Emulator Instance
```

## Getting Started

### 1. Dependencies

Add the required web dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    {:raxol, "~> 0.8.0"},
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},
    {:phoenix_pubsub, "~> 2.1"},
    {:plug_cowboy, "~> 2.5"},
    {:jason, "~> 1.4"}
  ]
end
```

### 2. Configuration

Configure Phoenix and Raxol in `config/config.exs`:

```elixir
# Phoenix configuration
config :my_app, MyAppWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base-here",
  render_errors: [view: MyAppWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

# Raxol configuration
config :raxol,
  web_enabled: true,
  terminal: [
    default_width: 80,
    default_height: 24,
    scrollback_lines: 1000
  ],
  session: [
    timeout: 30_000,  # 30 seconds
    persistence: true
  ]
```

### 3. Router Setup

Configure your Phoenix router in `lib/my_app_web/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MyAppWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    live "/", TerminalLive, :index
    live "/terminal/:session_id", TerminalLive, :show
  end
end
```

### 4. LiveView Implementation

Create a LiveView module for your terminal in `lib/my_app_web/live/terminal_live.ex`:

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  alias RaxolWeb.TerminalLive

  @impl true
  def mount(params, session, socket) do
    # Delegate to Raxol's terminal LiveView
    RaxolWeb.TerminalLive.mount(params, session, socket)
  end

  @impl true
  def handle_event(event, params, socket) do
    RaxolWeb.TerminalLive.handle_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="terminal-container">
      <RaxolWeb.TerminalLive.render assigns={assigns} />
    </div>
    """
  end
end
```

## Advanced Features

### Authentication

Protect your terminal sessions with authentication:

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  
  def mount(_params, %{"user_id" => user_id} = session, socket) do
    if authorized_user?(user_id) do
      {:ok, assign(socket, :user_id, user_id)}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end
  
  defp authorized_user?(user_id) do
    # Your authorization logic here
    Raxol.Accounts.get_user(user_id) != nil
  end
end
```

### Custom Terminal Configuration

Configure terminal settings per session:

```elixir
def mount(params, session, socket) do
  terminal_config = %{
    width: params["width"] || 80,
    height: params["height"] || 24,
    theme: session["theme"] || "dark",
    font_size: session["font_size"] || 14
  }
  
  {:ok, assign(socket, :terminal_config, terminal_config)}
end
```

### Collaborative Features

Enable real-time collaboration:

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end

# In your LiveView
def mount(_params, session, socket) do
  session_id = generate_session_id()
  topic = "terminal:#{session_id}"
  
  # Track user presence
  {:ok, _} = Presence.track(self(), topic, socket.assigns.user_id, %{
    joined_at: System.system_time(:second),
    cursor: %{x: 0, y: 0}
  })
  
  # Subscribe to presence updates
  Phoenix.PubSub.subscribe(MyApp.PubSub, topic)
  
  {:ok, assign(socket, :presence, %{})}
end
```

### Session Persistence

Save and restore terminal sessions:

```elixir
def handle_event("save_session", _params, socket) do
  session_data = %{
    terminal_state: socket.assigns.terminal_state,
    scrollback: socket.assigns.scrollback,
    timestamp: DateTime.utc_now()
  }
  
  case Raxol.Sessions.save(socket.assigns.session_id, session_data) do
    {:ok, _} ->
      {:noreply, put_flash(socket, :info, "Session saved")}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to save session")}
  end
end

def handle_event("restore_session", %{"session_id" => session_id}, socket) do
  case Raxol.Sessions.get(session_id) do
    {:ok, session_data} ->
      {:noreply, assign(socket, terminal_state: session_data.terminal_state)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Session not found")}
  end
end
```

## Client-Side Integration

### JavaScript Hooks

Add custom JavaScript hooks for enhanced functionality:

```javascript
// assets/js/terminal_hooks.js
export const TerminalHooks = {
  Terminal: {
    mounted() {
      // Handle terminal resize
      const resizeObserver = new ResizeObserver(entries => {
        for (let entry of entries) {
          const {width, height} = entry.contentRect;
          this.pushEvent("resize", {width, height});
        }
      });
      resizeObserver.observe(this.el);
      
      // Handle keyboard input
      this.el.addEventListener("keydown", (e) => {
        this.pushEvent("key", {
          key: e.key,
          modifiers: {
            ctrl: e.ctrlKey,
            alt: e.altKey,
            shift: e.shiftKey,
            meta: e.metaKey
          }
        });
        e.preventDefault();
      });
    }
  }
}
```

### CSS Styling

Style your terminal with CSS:

```css
/* assets/css/terminal.css */
.terminal-container {
  background-color: #1e1e1e;
  color: #d4d4d4;
  font-family: 'Fira Code', 'Consolas', monospace;
  font-size: 14px;
  line-height: 1.5;
  padding: 10px;
  height: 100vh;
  overflow: hidden;
}

.terminal-cursor {
  background-color: #ffffff;
  animation: blink 1s infinite;
}

@keyframes blink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0; }
}

.terminal-selection {
  background-color: #264f78;
}
```

## Performance Optimization

### Efficient Rendering

Minimize re-renders with targeted updates:

```elixir
def handle_info({:terminal_update, changes}, socket) do
  # Only update changed regions
  socket = 
    socket
    |> assign(:damage_regions, changes.damage_regions)
    |> push_event("patch_terminal", %{patches: changes.patches})
  
  {:noreply, socket}
end
```

### Bandwidth Optimization

Compress terminal data for large sessions:

```elixir
def handle_event("get_terminal_state", _params, socket) do
  compressed = 
    socket.assigns.terminal_state
    |> :erlang.term_to_binary()
    |> :zlib.compress()
    |> Base.encode64()
  
  {:reply, %{state: compressed}, socket}
end
```

### Connection Management

Handle connection drops gracefully:

```elixir
def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
  # Reconnection logic
  Process.send_after(self(), :reconnect, 5000)
  {:noreply, assign(socket, :connected, false)}
end

def handle_info(:reconnect, socket) do
  case RaxolWeb.Session.reconnect(socket.assigns.session_id) do
    {:ok, state} ->
      {:noreply, assign(socket, connected: true, terminal_state: state)}
    {:error, _} ->
      Process.send_after(self(), :reconnect, 5000)
      {:noreply, socket}
  end
end
```

## Security Considerations

### Input Sanitization

Always sanitize user input:

```elixir
def handle_event("terminal_input", %{"data" => data}, socket) do
  sanitized = RaxolWeb.InputSanitizer.sanitize(data)
  
  case RaxolWeb.TerminalSession.process_input(socket.assigns.session_id, sanitized) do
    {:ok, response} ->
      {:noreply, push_event(socket, "terminal_output", response)}
    {:error, :invalid_input} ->
      {:noreply, socket}
  end
end
```

### Rate Limiting

Prevent abuse with rate limiting:

```elixir
def handle_event(event, params, socket) do
  case RaxolWeb.RateLimiter.check_rate(socket.assigns.user_id) do
    :ok ->
      process_event(event, params, socket)
    {:error, :rate_limited} ->
      {:noreply, put_flash(socket, :error, "Too many requests")}
  end
end
```

### Session Security

Implement secure session handling:

```elixir
defmodule RaxolWeb.SessionSecurity do
  def generate_session_token do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
  
  def validate_session_token(token, user_id) do
    # Validate token belongs to user
    # Check token expiry
    # Verify token signature
  end
end
```

## Troubleshooting

### Common Issues

1. **WebSocket Connection Failures**
   - Check firewall settings
   - Verify WebSocket protocol is allowed
   - Ensure correct Phoenix endpoint configuration

2. **Performance Issues**
   - Enable terminal caching
   - Reduce scrollback buffer size
   - Implement virtual scrolling

3. **Rendering Problems**
   - Verify browser compatibility
   - Check font availability
   - Test with different terminal themes

### Debug Mode

Enable debug logging:

```elixir
config :logger, level: :debug

config :raxol, 
  debug_mode: true,
  log_terminal_events: true
```

## Best Practices

1. **Always use HTTPS in production** for secure WebSocket connections
2. **Implement proper authentication** before exposing terminal access
3. **Set resource limits** to prevent DoS attacks
4. **Monitor performance metrics** using Raxol's built-in telemetry
5. **Test across different browsers** and devices
6. **Implement graceful degradation** for older browsers
7. **Use CDN for static assets** to improve load times

## Next Steps

- Explore [Plugin Development](PLUGIN_SYSTEM_GUIDE.md) to extend web functionality
- Read about [Enterprise Features](../examples/guides/06_enterprise/) for production deployments
- Check out [Example Applications](../examples/) for real-world implementations