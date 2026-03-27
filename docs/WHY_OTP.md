# Why OTP for TUIs

Most TUI frameworks fight their runtime. They implement crash recovery with try/catch, state management with global stores, concurrency with goroutines or async/await, distribution with gRPC. Raxol doesn't implement any of that. It gets it from OTP.

## The Natural Mapping

| OTP concept   | TUI equivalent            | What you get                                                     |
| ------------- | ------------------------- | ---------------------------------------------------------------- |
| GenServer     | Elm update loop           | `init/1 -> update/2 -> view/1`, managed by the runtime           |
| Process       | Component                 | Each widget can run in its own process                           |
| Supervisor    | Crash recovery            | A widget crashes, it restarts. The rest of the UI doesn't notice |
| Hot code swap | Live reload               | Change `view/1`, save, running app updates. No restart           |
| `:ssh`        | SSH serving               | Built into Erlang. No dep, no daemon, just `:ssh.daemon`         |
| `libcluster`  | Node discovery            | Gossip, DNS, Tailscale. Nodes find each other automatically      |
| `send/2`      | Inter-component messaging | No event bus library. Just processes sending messages            |
| ETS           | State management          | Fast shared state without serialization overhead                 |

This isn't an analogy. These are the actual implementations.

## What This Means in Practice

### Crash isolation is real

In Ratatui or Bubble Tea, if a component panics, your whole app dies. In Raxol:

```elixir
# This widget runs in its own process.
# If it crashes, it restarts. The rest of the UI keeps rendering.
process_component(UnstableWidget, %{path: "/dev/random"})
```

The supervisor notices, restarts the component, and renders the next frame. No try/catch pyramid, no error boundaries, no manual recovery code. This is what OTP was built for.

### Hot reload without restart

Erlang's code server supports hot code swapping at the module level. In Raxol, when you save a file, the running app picks up the new `view/1` function on the next render cycle. No WebSocket reconnection, no state loss, no dev server restart.

This is the same mechanism that lets telecom switches upgrade without dropping calls. It works for TUIs too.

### SSH serving without dependencies

Erlang ships with a full SSH server implementation. Raxol wraps it:

```elixir
Raxol.SSH.serve(MyApp, port: 2222)
# That's it. Each connection gets a supervised process.
```

No OpenSSH configuration, no PAM modules, no external daemon. The SSH server runs inside your BEAM node. Each connection gets its own Lifecycle process with its own state. One crashes, the others continue.

Textual added SSH support in 2024 via `textual-serve`, which wraps an external SSH library. Bubble Tea and Ratatui have community wrappers. Raxol's SSH support is 4 modules totaling ~400 lines, because the hard part is in Erlang's `:ssh` module.

### Distribution is built in

The BEAM was designed for distributed systems. Nodes connect, send messages, monitor each other. Raxol's swarm module builds on this:

```elixir
# Nodes discover each other via Tailscale
Raxol.Swarm.Discovery.start_link(strategy: :tailscale, node_basename: "raxol")

# CRDT state syncs automatically
Raxol.Swarm.TacticalOverlay.update_entity(:unit_1, %{position: {10.0, 20.0, 0.0}})
```

No gRPC, no Redis, no message queue. Nodes are BEAM nodes. Messages are Erlang messages. CRDTs merge with pure functions.

### Same code, three targets

A TEA app is `init/1`, `update/2`, `view/1`. The rendering target is a runtime decision:

- **Terminal**: Lifecycle renders to a screen buffer, diffs, writes ANSI
- **Browser**: `Raxol.LiveView.TEALive` hosts the same module in Phoenix, bridges events
- **SSH**: `Raxol.SSH.Session` wraps Lifecycle per-connection

You don't write three versions of your app. You write one, and the runtime handles the output.

### AI agents are just processes

An agent in Raxol is a TEA app where input comes from LLMs instead of a keyboard. Same `init/update/view`. Same supervision. Same crash isolation. The "agent framework" is ~300 lines of code because most of it is just OTP:

- `Agent.Session` is a GenServer wrapping Lifecycle
- `Agent.Team` is a Supervisor
- `Agent.Comm` is `GenServer.call` and `GenServer.cast` with Registry lookups
- `Agent.Backend.HTTP` is `Stream.resource` over SSE

There's no agent runtime to install, no message queue to configure, no orchestration layer. Agents are processes. Teams are supervision trees. That's it.

## The Tradeoff

Raxol is slower per-operation than Rust (Ratatui) or Go (Bubble Tea). Buffer creation is 25us vs 0.5us. That's 50x. But a full frame still completes in 2.1ms, leaving 87% of the 60fps budget for your code.

The tradeoff is: you give up raw speed on microbenchmarks, and you get crash isolation, hot reload, distribution, SSH serving, and multi-target rendering. For dashboards, agent cockpits, monitoring tools, and anything that needs to stay up -- it's worth it.

## Further Reading

- [Architecture](core/ARCHITECTURE.md) -- how the render pipeline works
- [Agent Framework](features/AGENT_FRAMEWORK.md) -- AI agents as TEA apps
- [Distributed Swarm](features/DISTRIBUTED_SWARM.md) -- CRDTs and node discovery
- [SSH Deployment](cookbook/SSH_DEPLOYMENT.md) -- serving apps over SSH
