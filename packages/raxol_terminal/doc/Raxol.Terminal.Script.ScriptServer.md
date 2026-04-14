# `Raxol.Terminal.Script.ScriptServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/script/script_server.ex#L1)

Unified scripting system for the Raxol terminal emulator.
Handles script execution, management, and integration with the terminal.

REFACTORED: All try/rescue blocks replaced with functional patterns using Task.

# `script_id`

```elixir
@type script_id() :: String.t()
```

# `script_state`

```elixir
@type script_state() :: %{
  id: script_id(),
  name: String.t(),
  type: script_type(),
  source: String.t(),
  config: map(),
  status: :idle | :running | :paused | :error,
  error: String.t() | nil,
  output: [String.t()],
  metadata: map()
}
```

# `script_type`

```elixir
@type script_type() :: :lua | :python | :javascript | :elixir
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `execute_script`

Executes a script with optional arguments.

# `export_script`

Exports a script to a file.

# `get_script_output`

Gets the output of a script.

# `get_script_state`

Gets the state of a script.

# `get_scripts`

Gets all loaded scripts.

# `handle_manager_cast`

# `handle_manager_info`

# `import_script`

Imports a script from a file.

# `load_script`

Loads a script from a file or string source.

# `pause_script`

Pauses a running script.

# `resume_script`

Resumes a paused script.

# `start_link`

# `start_script_manager`

# `stop_script`

Stops a running script.

# `unload_script`

Unloads a script by its ID.

# `update_script_config`

Updates a script's configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
