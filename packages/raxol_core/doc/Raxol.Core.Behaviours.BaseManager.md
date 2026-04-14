# `Raxol.Core.Behaviours.BaseManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/base_manager.ex#L1)

Base behavior for manager GenServers to reduce code duplication.
Provides common patterns for state management, lifecycle, and error handling.

# `handle_manager_call`
*optional* 

```elixir
@callback handle_manager_call(any(), GenServer.from(), any()) ::
  {:reply, any(), any()} | {:noreply, any()} | {:stop, any(), any(), any()}
```

Called to handle manager-specific requests.

# `handle_manager_cast`
*optional* 

```elixir
@callback handle_manager_cast(any(), any()) :: {:noreply, any()} | {:stop, any(), any()}
```

Called to handle manager-specific casts.

# `handle_manager_info`
*optional* 

```elixir
@callback handle_manager_info(any(), any()) :: {:noreply, any()} | {:stop, any(), any()}
```

Called to handle manager-specific info messages.

# `init_manager`

```elixir
@callback init_manager(term()) :: {:ok, any()}
```

Called to initialize the manager state.
Must return {:ok, state}. For initialization failures, raise an exception
to let the supervisor handle restart logic.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
