# `Raxol.Core.Runtime.Plugins.FileWatcherBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/file_watcher_behaviour.ex#L1)

Behavior for file watcher plugins.

# `handle_file_change`

```elixir
@callback handle_file_change(file_path :: String.t(), change_type :: atom()) ::
  :ok | {:error, term()}
```

Callback for handling file change events.

# `start_watching`

```elixir
@callback start_watching(paths :: [String.t()], opts :: keyword()) ::
  {:ok, pid()} | {:error, term()}
```

Callback for starting the file watcher.

# `stop_watching`

```elixir
@callback stop_watching(watcher_pid :: pid()) :: :ok
```

Callback for stopping the file watcher.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
