# `Raxol.Terminal.Capabilities.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/capabilities/capabilities_manager.ex#L1)

Manages terminal capabilities including detection, negotiation, and caching.

# `state`

```elixir
@type state() :: Raxol.Terminal.Capabilities.Types.t()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `detect_capability`

```elixir
@spec detect_capability(atom(), term(), atom() | nil) :: :ok | {:error, term()}
```

Detects and registers a new capability.

# `enable_capability`

```elixir
@spec enable_capability(atom(), atom() | nil) :: :ok | {:error, term()}
```

Enables a capability if supported.

# `handle_manager_cast`

# `handle_manager_info`

# `query_capability`

```elixir
@spec query_capability(atom(), atom() | nil) ::
  Raxol.Terminal.Capabilities.Types.capability_response()
```

Queries if a capability is supported.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
