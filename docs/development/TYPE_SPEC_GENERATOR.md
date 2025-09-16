# Type Spec Generator

## Overview

The Raxol Type Spec Generator (`mix raxol.gen.specs`) is an automated tool that generates type specifications for private functions in Elixir modules. It uses intelligent pattern matching and naming conventions to infer appropriate types, dramatically reducing the manual effort required to add type specs to a large codebase.

## Installation

The generator is included with Raxol v1.4.1+ and requires no additional installation.

## Usage

### Basic Usage

Generate specs for a single file:
```bash
mix raxol.gen.specs lib/raxol/terminal/buffer.ex
```

Generate specs for all files in a directory:
```bash
mix raxol.gen.specs lib/raxol/terminal --recursive
```

### Options

- `--dry-run` - Preview what specs would be generated without modifying files
- `--recursive` - Process all `.ex` files in a directory recursively
- `--filter PATTERN` - Only generate specs for functions matching the pattern
- `--interactive` - Prompt for confirmation before adding each spec
- `--backup` - Create `.backup` files before modifying originals

### Examples

#### Preview Changes (Dry Run)
```bash
mix raxol.gen.specs lib/raxol/core/state.ex --dry-run

# Output:
# [DRY RUN] Would add 15 specs to lib/raxol/core/state.ex:
#   handle_state_change/2: @spec handle_state_change(map(), any()) :: {:ok, map()} | {:error, any()}
#   validate_transition/2: @spec validate_transition(map(), atom()) :: boolean()
#   ...
```

#### Target Specific Functions
```bash
# Only generate specs for validation functions
mix raxol.gen.specs lib/raxol --recursive --filter validate_

# Only generate specs for parsing functions
mix raxol.gen.specs lib/raxol --recursive --filter parse_
```

#### Interactive Mode
```bash
mix raxol.gen.specs lib/raxol/ui/components.ex --interactive

# For each function, you'll see:
# Function: render_button/2
# Generated spec: @spec render_button(map(), keyword()) :: String.t()
# Add this spec? [Y/n]
```

#### Safe Mode with Backups
```bash
# Creates .backup files before modifying
mix raxol.gen.specs lib/raxol/critical_module.ex --backup

# Restore if needed:
cp lib/raxol/critical_module.ex.backup lib/raxol/critical_module.ex
```

## Type Inference Rules

The generator uses several strategies to infer types:

### 1. Function Name Patterns

| Pattern | Inferred Return Type |
|---------|---------------------|
| `validate_*` | `{:ok, any()} \| {:error, any()}` |
| `parse_*` | `{:ok, any()} \| {:error, any()}` |
| `is_*` | `boolean()` |
| `has_*` | `boolean()` |
| `get_*` | `any() \| nil` |
| `set_*` | `any()` |
| `update_*` | `any()` |
| `handle_*` | `{:ok, any()} \| {:error, any()} \| {:reply, any(), any()} \| {:noreply, any()}` |
| `format_*` | `String.t()` |
| `build_*` | `any()` |
| `create_*` | `any()` |
| `*?` | `boolean()` |
| `*!` | `any() \| no_return()` |

### 2. Argument Name Patterns

| Pattern | Inferred Type |
|---------|--------------|
| `state` | `map()` |
| `buffer` | `Raxol.Terminal.ScreenBuffer.t()` |
| `cursor` | `Raxol.Terminal.Cursor.t()` |
| `opts` | `keyword()` |
| `config` | `map()` |
| `metadata` | `map()` |
| `errors` | `[String.t()]` |
| `path` | `String.t()` |
| `x`, `y` | `non_neg_integer()` |
| `width`, `height` | `pos_integer()` |
| `count`, `size`, `index` | `non_neg_integer()` |
| `is_*`, `has_*` | `boolean()` |
| `pid` | `pid()` |
| `ref` | `reference()` |

### 3. Special Handling

#### Guard Clauses
The generator correctly handles functions with guard clauses:
```elixir
# Input
defp validate(x) when is_integer(x) and x > 0, do: :ok

# Generated spec
@spec validate(integer()) :: :ok
```

#### Pattern Matching
Recognizes common patterns in function arguments:
```elixir
# Input
defp process(%State{} = state, opts \\ [])

# Generated spec
@spec process(State.t(), keyword()) :: any()
```

## Limitations

1. **Generic Types**: Complex return types default to `any()`
2. **Custom Types**: May not recognize all domain-specific types
3. **Overwriting**: Won't add specs to functions that already have them
4. **Macros**: Doesn't generate specs for macros

## Best Practices

### 1. Review Generated Specs
Always review generated specs, especially for critical modules:
```bash
# Use dry-run first
mix raxol.gen.specs lib/critical.ex --dry-run

# Review, then apply
mix raxol.gen.specs lib/critical.ex --backup
```

### 2. Incremental Adoption
Start with high-value modules:
```bash
# Core modules first
mix raxol.gen.specs lib/raxol/core --recursive

# Then expand to other areas
mix raxol.gen.specs lib/raxol/terminal --recursive
```

### 3. Validate with Dialyzer
After adding specs, validate them:
```bash
mix dialyzer
```

### 4. Customize for Your Domain
The generator can be extended with project-specific patterns by modifying the `infer_single_arg_type/3` function in `lib/mix/tasks/raxol.gen.specs.ex`.

## Integration with CI/CD

Add to your CI pipeline to ensure new code has specs:

```yaml
# .github/workflows/specs.yml
- name: Generate missing specs
  run: mix raxol.gen.specs lib --recursive --dry-run

- name: Check spec coverage
  run: mix dialyzer
```

## Statistics

Track your spec coverage progress:

```bash
# Count functions with specs
grep -r "@spec" lib/raxol | wc -l

# Count all private functions
grep -r "defp " lib/raxol | wc -l

# Generate coverage report
mix raxol.gen.specs lib/raxol --recursive --dry-run | grep "Would add" | awk '{sum += $3} END {print "Missing specs:", sum}'
```

## Troubleshooting

### Compilation Errors After Generation

If specs cause compilation errors:
```bash
# Restore from backup
cp module.ex.backup module.ex

# Or manually fix the problematic spec
```

### Incorrect Type Inference

For better results:
1. Use consistent naming conventions
2. Add explicit type annotations for complex types
3. Consider using `@type` definitions for domain types

### Performance

For large codebases:
```bash
# Process in batches
find lib -name "*.ex" -type f | head -100 | xargs -I {} mix raxol.gen.specs {}
```

## Contributing

To improve type inference, edit the inference rules in:
- `lib/mix/tasks/raxol.gen.specs.ex`
- Functions: `infer_single_arg_type/3` and `infer_return_type/1`

Submit improvements as pull requests to the Raxol repository.