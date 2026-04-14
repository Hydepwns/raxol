# `Raxol.Terminal.Capabilities.Types`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/capabilities/capabilities_types.ex#L1)

Defines types and structures for terminal capabilities management.

# `capability`

```elixir
@type capability() :: atom()
```

# `capability_map`

```elixir
@type capability_map() :: %{required(capability()) =&gt; capability_value()}
```

# `capability_query`

```elixir
@type capability_query() :: {capability(), capability_value()}
```

# `capability_response`

```elixir
@type capability_response() :: {:ok, capability_value()} | {:error, term()}
```

# `capability_value`

```elixir
@type capability_value() :: term()
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Capabilities.Types{
  cached: capability_map(),
  enabled: capability_map(),
  supported: capability_map()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
