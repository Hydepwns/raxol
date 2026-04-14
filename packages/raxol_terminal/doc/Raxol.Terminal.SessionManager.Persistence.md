# `Raxol.Terminal.SessionManager.Persistence`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/persistence.ex#L1)

Session persistence: save/restore sessions to/from disk.

# `init`

Initializes the persistence manager with a directory path.

# `restore_all`

Restores all persisted sessions from disk.
Returns a map of session_id => session.

# `restore_from_file`

Restores a single session from a file path.

# `save_session`

Saves a session to disk if persistence is enabled.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
