# `Raxol.Terminal.Buffer.BufferServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/buffer_server.ex#L1)

Buffer server stub for test compatibility.

This module provides a GenServer-based interface for terminal buffer operations
to maintain compatibility with legacy tests during the architecture transition.

# `atomic_operation`

Performs an atomic operation on the buffer.

# `batch_operations`

Performs a batch of operations atomically.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_damage_regions`

Clears damage regions.

# `flush`

Flushes pending operations.

# `get_cell`

Gets a cell at the given coordinates.

# `get_content`

Gets buffer content as string.

# `get_damage_regions`

Gets damage regions that need repainting.

# `get_dimensions`

Gets buffer dimensions.

# `get_memory_usage`

Gets memory usage information.

# `get_metrics`

Gets buffer metrics.

# `handle_manager_call`

# `handle_manager_cast`

# `handle_manager_info`

# `resize`

Resizes the buffer.

# `set_cell`

Sets a cell at the given coordinates asynchronously.

# `set_cell_sync`

Sets a cell at the given coordinates synchronously.

# `start_link`

# `stop`

Stops the buffer server.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
