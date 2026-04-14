# `Raxol.Terminal.EventHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/event_handler.ex#L1)

Handles various terminal events including mouse, keyboard, and focus events.
This module is responsible for processing and responding to user interactions.

# `handle_focus_event`

```elixir
@spec handle_focus_event(Raxol.Terminal.Emulator.t(), atom()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Processes a focus event.
Returns {:ok, updated_emulator} or {:error, reason}.

# `handle_keyboard_event`

```elixir
@spec handle_keyboard_event(Raxol.Terminal.Emulator.t(), map()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Processes a keyboard event.
Returns {:ok, updated_emulator} or {:error, reason}.

# `handle_mouse_event`

```elixir
@spec handle_mouse_event(Raxol.Terminal.Emulator.t(), map()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Processes a mouse event.
Returns {:ok, updated_emulator} or {:error, reason}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
