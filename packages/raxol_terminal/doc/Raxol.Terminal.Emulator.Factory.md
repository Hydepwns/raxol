# `Raxol.Terminal.Emulator.Factory`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/factory.ex#L1)

Emulator construction helpers: creates full (GenServer) and basic (struct-only) emulators.

# `create_basic`

Creates a basic emulator without GenServer processes (optimized for performance).

# `create_full`

Creates a full-featured emulator with GenServer processes.
Falls back to basic emulator on failure.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
