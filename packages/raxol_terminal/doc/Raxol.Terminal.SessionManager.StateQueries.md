# `Raxol.Terminal.SessionManager.StateQueries`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/state_queries.ex#L1)

State query helpers for SessionManager: finding panes/windows and building summaries.

# `find_pane`

Finds a pane by session_id, window_id, and pane_id within the manager state.
Returns {:ok, session, window, pane} or {:error, reason}.

# `find_pane_in_window`

Finds a pane by id within a window.

# `find_window_in_session`

Finds a window by id within a session.

# `session_summary`

Builds a summary map for a session.

# `update_window_in_session`

Updates a window within a session in the manager state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
