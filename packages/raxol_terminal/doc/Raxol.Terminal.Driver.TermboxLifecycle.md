# `Raxol.Terminal.Driver.TermboxLifecycle`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/driver/termbox_lifecycle.ex#L1)

Termbox NIF initialization, shutdown, and recovery helpers.

# `cleanup_terminal`

Cleans up terminal state during shutdown: kills stdin reader, closes tty port,
restores terminal modes and original stty settings.

# `handle_recovery`

Attempts recovery from a termbox error by shutting down and reinitializing.
Returns {:noreply, state} or {:stop, reason, state}.

# `initialize`

Initializes termbox. Returns :ok or {:error, reason}.

# `terminate`

Shuts down termbox.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
