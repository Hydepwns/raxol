# `Raxol.Terminal.ControlCodes`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/control_codes.ex#L1)

Handles C0 control codes and simple ESC sequences.

Extracted from Terminal.Emulator for better organization.
Relies on Emulator state and ScreenBuffer for actions.

# `handle_bel`

Handles bell control code.

# `handle_bs`

Handle Backspace (BS)

# `handle_c0`

```elixir
@spec handle_c0(Raxol.Terminal.Emulator.t(), non_neg_integer()) ::
  Raxol.Terminal.Emulator.t()
```

Handles a C0 control code (0-31) or DEL (127).
Delegates to specific handlers based on the codepoint.

# `handle_can`

```elixir
@spec handle_can(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_cr`

Handle Carriage Return (CR)

# `handle_decrc`

```elixir
@spec handle_decrc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_decsc`

```elixir
@spec handle_decsc(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_escape`

```elixir
@spec handle_escape(Raxol.Terminal.Emulator.t(), integer()) ::
  Raxol.Terminal.Emulator.t()
```

Handles simple escape sequences (ESC followed by a single byte).

# `handle_ht`

Handles the Horizontal Tab (HT) action.

# `handle_hts`

```elixir
@spec handle_hts(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_ind`

```elixir
@spec handle_ind(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_lf`

Handle Line Feed (LF), New Line (NL), Vertical Tab (VT)

# `handle_ls1r`

Handle Locking Shift 1 Right (LS1R) - ESC ~
Invokes G1 character set into GR

# `handle_ls2`

Handle Locking Shift 2 (LS2) - ESC n
Invokes G2 character set into GL

# `handle_ls2r`

Handle Locking Shift 2 Right (LS2R) - ESC }
Invokes G2 character set into GR

# `handle_ls3`

Handle Locking Shift 3 (LS3) - ESC o
Invokes G3 character set into GL

# `handle_ls3r`

Handle Locking Shift 3 Right (LS3R) - ESC |
Invokes G3 character set into GR

# `handle_nel`

```elixir
@spec handle_nel(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_ri`

Handle Reverse Index (RI) - ESC M

# `handle_ris`

```elixir
@spec handle_ris(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_si`

```elixir
@spec handle_si(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_so`

```elixir
@spec handle_so(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
```

# `handle_sub`

Handles substitute character control code.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
