# `Raxol.Core.Runtime.ProcessStore`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/process_store.ex#L1)

Replacement for Process dictionary usage.
Provides a functional alternative using Agent for state storage.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

Clears all values from the store.

# `delete`

Deletes a value from the store.

# `get`

Gets a value from the store.

# `get_all`

Gets all values from the store.

# `get_and_update`

Gets and updates a value atomically.

# `put`

Puts a value in the store.

# `start_link`

Starts a new process store.

# `update`

Updates a value in the store using a function.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
