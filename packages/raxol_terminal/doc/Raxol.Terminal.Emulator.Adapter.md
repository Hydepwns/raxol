# `Raxol.Terminal.Emulator.Adapter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/adapter.ex#L1)

Adapter module to make EmulatorLite compatible with existing code that
expects the full Emulator struct.

This module provides conversion functions and compatibility shims.

# `ensure_emulator`

```elixir
@spec ensure_emulator(Raxol.Terminal.Emulator.t() | Raxol.Terminal.EmulatorLite.t()) ::
  Raxol.Terminal.Emulator.t()
```

Ensures we have an Emulator struct, converting from EmulatorLite if needed.

This is a compatibility function for code that expects Emulator structs.

# `ensure_lite`

```elixir
@spec ensure_lite(Raxol.Terminal.Emulator.t() | Raxol.Terminal.EmulatorLite.t()) ::
  Raxol.Terminal.EmulatorLite.t()
```

Ensures we have an EmulatorLite struct, converting from Emulator if needed.

This is useful for performance-critical paths that don't need GenServers.

# `from_lite`

```elixir
@spec from_lite(Raxol.Terminal.EmulatorLite.t()) :: Raxol.Terminal.Emulator.t()
```

Converts an EmulatorLite to an Emulator struct for compatibility.

Note: This creates a "hollow" Emulator with nil PIDs for GenServers.
It's suitable for parsing and buffer operations but not for full
terminal emulation with concurrent state management.

# `lite?`

```elixir
@spec lite?(Raxol.Terminal.Emulator.t() | Raxol.Terminal.EmulatorLite.t()) ::
  boolean()
```

Checks if an emulator is the lite version (no GenServers).

# `to_lite`

```elixir
@spec to_lite(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.EmulatorLite.t()
```

Converts a full Emulator to EmulatorLite, discarding GenServer references.

This is useful for extracting just the state without the process overhead.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
