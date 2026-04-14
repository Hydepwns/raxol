# `Raxol.Terminal.Window.Manager.StateOps`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/manager/state_ops.ex#L1)

Pure functional state operations for the WindowManagerServer.

Handles window CRUD, property updates, and Z-order management
without GenServer concerns.

# `apply_move_to_back`

Moves a window to the back of the Z-order.
Returns {:reply, result, new_state}.

# `apply_move_to_front`

Moves a window to the front of the Z-order.
Returns {:reply, result, new_state}.

# `apply_set_active_window`

Updates all window states when a new active window is set.
Returns {:reply, :ok, new_state} or {:reply, {:error, :not_found}, state}.

# `build_child_window`

Builds a child Window struct from a config, parent ID, and window ID.

# `build_legacy_state`

Builds the legacy-format state map for get_state.

# `build_window`

Builds a new Window struct from a config and assigns an ID.

# `calculate_split_size`

Calculates split size for a child window.

# `maybe_activate_first_window`

Optionally activates window_id if no active window exists yet.

# `update_active_after_destroy`

Determines the new active window after a window is destroyed.

# `update_window_by_id`

Updates a window property by ID. Takes a function that transforms the window.
Returns {:ok, updated_window, new_state} or {:error, :not_found}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
