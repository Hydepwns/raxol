# `Raxol.Core.Utils.GenServerHelpers`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/genserver_helpers.ex#L1)

Common GenServer patterns and utilities to reduce code duplication.
Provides standardized handlers for common operations like state retrieval,
metrics collection, and configuration management.

# `ensure_started`

```elixir
@spec ensure_started(atom(), (-&gt; {:ok, pid()} | {:error, term()})) :: :ok
```

Ensures a named process is running. Starts it via `start_fun` if not found.

The `start_fun` is a zero-arity function that should return `{:ok, pid}`.

## Examples

    ensure_started(MyServer, fn -> MyServer.start_link(name: MyServer) end)

# `handle_get_field`

Standard handler for getting specific state fields.

# `handle_get_metrics`

Standard handler for getting metrics from state.

# `handle_get_state`

Standard handler for getting state information.

# `handle_get_status`

Standard handler for getting status information.

# `handle_reset_metrics`

Standard handler for resetting metrics.

# `handle_update_config`

Standard handler for updating configuration.

# `increment_metric`

Utility to increment a metric counter.

# `init_default_state`

Initialize default state with common fields.

# `split_server_opts`

```elixir
@spec split_server_opts(keyword() | map() | term()) :: {keyword(), keyword() | term()}
```

Splits a keyword list into GenServer server options and init args.

Server options (`:name`, `:timeout`, `:debug`, `:spawn_opt`) are
separated from the remaining application-specific options.

## Examples

    iex> split_server_opts(name: MyServer, timeout: 5000, foo: :bar)
    {[name: MyServer, timeout: 5000], [foo: :bar]}

    iex> split_server_opts(%{name: MyServer})
    {[name: MyServer], []}

# `update_metric`

Utility to update a metric value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
