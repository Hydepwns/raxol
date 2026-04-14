# `Raxol.Core.Behaviours.BaseServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/base_server.ex#L1)

Base behavior for general-purpose GenServers to reduce code duplication.
Provides common patterns for server lifecycle, error handling, and state management.

# `handle_shutdown`
*optional* 

```elixir
@callback handle_shutdown(any()) :: :ok
```

Called to handle server shutdown gracefully.

# `init_server`

```elixir
@callback init_server(keyword()) :: {:ok, any()} | {:error, any()}
```

Called to initialize the server state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
