# `Raxol.Terminal.Parser.StateBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/state_behaviour.ex#L1)

Defines the behaviour for parser states.

# `emulator`

```elixir
@type emulator() :: Raxol.Terminal.Emulator.t()
```

# `state`

```elixir
@type state() :: any()
```

# `handle`

```elixir
@callback handle(emulator(), state(), binary()) ::
  {:continue, emulator(), state(), binary()}
  | {:finished, emulator(), state()}
  | {:incomplete, emulator(), state()}
```

# `handle_apc_string`

```elixir
@callback handle_apc_string(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_byte`

```elixir
@callback handle_byte(byte(), emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_control_sequence`

```elixir
@callback handle_control_sequence(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_dcs_string`

```elixir
@callback handle_dcs_string(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_escape`

```elixir
@callback handle_escape(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_osc_string`

```elixir
@callback handle_osc_string(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_pm_string`

```elixir
@callback handle_pm_string(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_sos_string`

```elixir
@callback handle_sos_string(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

# `handle_unknown`

```elixir
@callback handle_unknown(emulator(), state()) ::
  {:ok, emulator(), state()} | {:error, atom(), emulator(), state()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
