# `Raxol.Terminal.Session.Serializer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session/serializer.ex#L1)

Handles serialization and deserialization of terminal session state.

Refactored version with pure functional error handling patterns.
All try/catch blocks have been replaced with with statements and proper error tuples.

# `deserialize`

```elixir
@spec deserialize(map()) :: {:ok, Raxol.Terminal.Session.t()} | {:error, term()}
```

Deserializes a session state from a map.

# `serialize`

```elixir
@spec serialize(Raxol.Terminal.Session.t()) :: {:ok, map()} | {:error, term()}
```

Serializes a session state to a map that can be stored and later restored.

# `serialize!`

```elixir
@spec serialize!(Raxol.Terminal.Session.t()) :: map()
```

Serializes a session state to a map, returning the map directly for backward compatibility.
Falls back to empty session data on error.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
