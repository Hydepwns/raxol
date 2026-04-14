# `Raxol.Terminal.Session.Storage`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session/storage.ex#L1)

Handles persistence of terminal sessions.

# `delete_session`

```elixir
@spec delete_session(String.t()) :: :ok | {:error, term()}
```

Deletes a saved session.

# `list_sessions`

```elixir
@spec list_sessions() :: {:ok, [String.t()]} | {:error, term()}
```

Lists all saved sessions.

# `load_session`

```elixir
@spec load_session(String.t()) :: {:ok, Raxol.Terminal.Session.t()} | {:error, term()}
```

Loads a session state from persistent storage.

# `save_session`

```elixir
@spec save_session(Raxol.Terminal.Session.t()) :: :ok | {:error, term()}
```

Saves a session state to persistent storage.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
