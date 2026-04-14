# `Raxol.Terminal.Commands.Processor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/processor.ex#L1)

Handles command processing for the terminal emulator.
This module is responsible for parsing, validating, and executing terminal commands.

# `execute_command`

```elixir
@spec execute_command(Raxol.Terminal.Emulator.t(), map()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Executes a parsed command on the emulator.
Returns {:ok, updated_emulator} or {:error, reason}.

# `handle_command_error`

```elixir
@spec handle_command_error(Raxol.Terminal.Emulator.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Handles command execution errors.
Returns {:ok, updated_emulator} with error state or {:error, reason}.

# `process_command`

```elixir
@spec process_command(Raxol.Terminal.Emulator.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.t()} | {:error, String.t()}
```

Processes a command string and executes it on the emulator.
Returns {:ok, updated_emulator} or {:error, reason}.

# `validate_parameters`

```elixir
@spec validate_parameters(Raxol.Terminal.Emulator.t(), list(), atom()) ::
  {:ok, list()} | {:error, String.t()}
```

Validates command parameters against the emulator's current state.
Returns {:ok, validated_params} or {:error, reason}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
