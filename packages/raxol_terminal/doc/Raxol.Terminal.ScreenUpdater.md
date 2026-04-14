# `Raxol.Terminal.ScreenUpdater`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_updater.ex#L1)

Handles screen update operations for the terminal.

This module manages updating the terminal screen content,
including batched updates and differential rendering.

# `batch_update_screen`

```elixir
@spec batch_update_screen([Raxol.Terminal.ScreenBuffer.t()], map()) ::
  :ok | {:error, term()}
```

Performs a batched screen update for efficiency.

# `clear_screen`

```elixir
@spec clear_screen() :: :ok
```

Clears the screen.

# `refresh_screen`

```elixir
@spec refresh_screen(Raxol.Terminal.ScreenBuffer.t()) :: :ok | {:error, term()}
```

Refreshes the entire screen.

# `scroll_screen`

```elixir
@spec scroll_screen(integer()) :: :ok
```

Scrolls the screen content.

# `update_region`

```elixir
@spec update_region(
  Raxol.Terminal.ScreenBuffer.t(),
  integer(),
  integer(),
  integer(),
  integer()
) :: :ok | {:error, term()}
```

Updates a specific region of the screen.

# `update_screen`

```elixir
@spec update_screen(Raxol.Terminal.ScreenBuffer.t(), map()) :: :ok | {:error, term()}
```

Updates the screen with new buffer content.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
