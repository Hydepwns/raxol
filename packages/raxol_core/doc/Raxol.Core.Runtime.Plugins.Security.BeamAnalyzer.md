# `Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/security/beam_analyzer.ex#L1)

BEAM bytecode analyzer for detecting security-sensitive operations.

This module analyzes the abstract syntax tree (AST) of compiled BEAM modules
to detect potentially dangerous operations such as:

- File system access
- Network access
- Code injection / dynamic evaluation
- System command execution
- Process spawning with external commands

## Usage

    {:ok, capabilities} = BeamAnalyzer.analyze_module(MyPlugin)
    # => {:ok, %{file_access: true, network_access: false, code_injection: false}}

# `analysis_error`

```elixir
@type analysis_error() :: :no_abstract_code | :unknown_beam_format | beam_lib_error()
```

# `analysis_result`

```elixir
@type analysis_result() :: {:ok, capabilities()} | {:error, analysis_error()}
```

# `beam_lib_error`

```elixir
@type beam_lib_error() ::
  {:beam_lib_error,
   {:not_a_beam_file, list()}
   | {:file_error
      | :invalid_beam_file
      | :invalid_chunk
      | :key_missing_or_invalid
      | :missing_backend
      | :missing_chunk
      | :unknown_chunk, list(), atom() | list() | non_neg_integer()}
   | {:chunk_too_big, list(), list(), non_neg_integer(), non_neg_integer()}}
```

# `capabilities`

```elixir
@type capabilities() :: %{
  file_access: boolean(),
  network_access: boolean(),
  code_injection: boolean(),
  system_commands: boolean()
}
```

# `capability`

```elixir
@type capability() ::
  :file_access | :network_access | :code_injection | :system_commands
```

# `analyze_module`

```elixir
@spec analyze_module(module()) ::
  {:ok,
   %{
     file_access: boolean(),
     network_access: boolean(),
     code_injection: boolean(),
     system_commands: boolean()
   }}
  | {:error,
     :no_abstract_code
     | :unknown_beam_format
     | {:beam_lib_error,
        {:not_a_beam_file, [any()]}
        | {:file_error
           | :invalid_beam_file
           | :invalid_chunk
           | :key_missing_or_invalid
           | :missing_backend
           | :missing_chunk
           | :unknown_chunk, [any()], atom() | [...] | non_neg_integer()}
        | {:chunk_too_big, [any()], [...], non_neg_integer(), non_neg_integer()}}}
```

Analyzes a module's BEAM bytecode to detect security-sensitive operations.

Returns a map of capability flags indicating what the module can do.

# `has_code_injection_risk?`

```elixir
@spec has_code_injection_risk?(module()) :: boolean()
```

Checks if a module has code injection capabilities.

# `has_file_access?`

```elixir
@spec has_file_access?(module()) :: boolean()
```

Checks if a module has file system access capabilities.

# `has_network_access?`

```elixir
@spec has_network_access?(module()) :: boolean()
```

Checks if a module has network access capabilities.

# `has_system_command_access?`

```elixir
@spec has_system_command_access?(module()) :: boolean()
```

Checks if a module has system command execution capabilities.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
