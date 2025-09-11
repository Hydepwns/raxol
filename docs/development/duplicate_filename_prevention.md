# Duplicate Filename Prevention System

**Version:** v1.2.0  
**Date:** 2025-01-09  
**Purpose:** Maintain code organization and prevent navigation issues caused by duplicate filenames

## Overview

The Raxol project includes comprehensive tooling to detect and prevent duplicate filenames that can cause navigation issues and reduce code maintainability.

## The Problem

Having multiple files with identical names creates several issues:
- **Navigation difficulties** in IDEs and editors
- **Ambiguous search results** when looking for specific functionality  
- **Code review confusion** when discussing files
- **Reduced discoverability** of related modules
- **Maintenance overhead** when updating or debugging

### Example Problematic Pattern

```bash
# Before - Confusing duplicate names
lib/raxol/terminal/buffer/manager.ex      # Which manager?
lib/raxol/terminal/cursor/manager.ex      # Which manager? 
lib/raxol/core/config/manager.ex          # Which manager?
lib/raxol/core/events/manager.ex          # Which manager?

# After - Clear, contextual names  
lib/raxol/terminal/buffer/buffer_manager.ex    # Clear: buffer management
lib/raxol/terminal/cursor/cursor_manager.ex    # Clear: cursor management
lib/raxol/core/config/config_manager.ex        # Clear: config management
lib/raxol/core/events/event_manager.ex         # Clear: event management
```

## Tools Provided

### 1. Standalone Script
**Location:** `scripts/quality/check_duplicate_filenames.exs`

```bash
# Basic check
mix run scripts/quality/check_duplicate_filenames.exs

# With rename suggestions  
mix run scripts/quality/check_duplicate_filenames.exs --fix-suggestions
```

**Features:**
- Scans `lib/` and `test/` directories
- Categorizes duplicates by severity (🔴 CRITICAL, 🟡 WARNING, 🔵 INFO)
- Provides contextual rename suggestions
- Exit codes for CI/CD integration

### 2. Mix Task
**Location:** `lib/mix/tasks/raxol.check.duplicates.ex`

```bash
# Basic usage
mix raxol.check.duplicates

# Show suggested fixes
mix raxol.check.duplicates --suggest-fixes

# Strict mode (fails build on duplicates)
mix raxol.check.duplicates --strict

# Exclude specific files
mix raxol.check.duplicates --exclude "mix.exs,README.md"
```

**Features:**
- Integrated with Mix task system
- Configurable exclusions
- Multiple output modes
- Better error handling

### 3. Credo Integration
**Location:** `lib/raxol/credo/duplicate_filename_check.ex`

```bash
# Run as part of Credo checks
mix credo

# Run only duplicate filename check
mix credo --only Raxol.Credo.DuplicateFilenameCheck
```

**Features:**
- Integrated into existing linting workflow
- Configurable severity levels
- Part of standard code quality checks
- IDE integration through Credo

## Configuration

### Credo Configuration
In `.credo.exs`:

```elixir
{Raxol.Credo.DuplicateFilenameCheck, [
  exclude_files: ["mix.exs", "README.md", ".gitignore"],
  max_duplicates: 1,
  include_tests: true
]}
```

### Options
- **`exclude_files`** - Files to ignore (default: `["mix.exs", "README.md", ".gitignore"]`)
- **`max_duplicates`** - Maximum allowed duplicates before flagging (default: `1`)
- **`include_tests`** - Whether to check test files (default: `true`)

## Problematic Patterns

The system flags these commonly duplicated filenames:

### Critical Patterns (🔴)
Files that almost always cause navigation issues:
- `manager.ex`
- `handler.ex` 
- `server.ex`
- `supervisor.ex`
- `renderer.ex`
- `processor.ex`
- `validator.ex`
- `buffer.ex`
- `parser.ex`
- `state.ex`
- `types.ex`
- `config.ex`
- `client.ex`
- `worker.ex`

### Warning Patterns (🟡)
Files with 4+ duplicates regardless of name.

### Info Patterns (🔵)  
Files with 2-3 duplicates (may be acceptable depending on context).

## Naming Conventions

### Recommended Pattern: `{context}_{function}.ex`

Instead of generic names, use domain-specific prefixes:

```elixir
# Generic (problematic)
manager.ex
handler.ex
server.ex

# Contextual (better)
buffer_manager.ex
event_handler.ex
focus_server.ex
```

### Naming Examples

| Generic Name | Context | Suggested Name |
|--------------|---------|----------------|
| `manager.ex` | `terminal/buffer/` | `buffer_manager.ex` |
| `handler.ex` | `core/events/` | `event_handler.ex` |
| `server.ex` | `ui/focus/` | `focus_server.ex` |
| `processor.ex` | `terminal/ansi/` | `ansi_processor.ex` |
| `validator.ex` | `terminal/config/` | `config_validator.ex` |

## Integration with Development Workflow

### Pre-commit Hook
Add to `.git/hooks/pre-commit`:

```bash
#!/bin/sh
mix raxol.check.duplicates --strict
```

### CI/CD Integration
Add to your CI pipeline:

```bash
# In your CI script
mix raxol.check.duplicates --strict
if [ $? -ne 0 ]; then
  echo "❌ Duplicate filename check failed"
  exit 1
fi
```

### Editor Integration
Most editors support Credo integration, so the duplicate filename check will appear inline as you develop.

## Example Output

```bash
🔍 Checking for duplicate filenames...
Scanning directories: lib, test

🔴 CRITICAL - 'validator.ex' (2 files):
  • lib/raxol/terminal/extension/validator.ex
  • lib/raxol/terminal/config/validator.ex
  📝 Suggested renames:
    lib/raxol/terminal/extension/validator.ex → extension_validator.ex
    lib/raxol/terminal/config/validator.ex → config_validator.ex

🟡 WARNING - 'manager_test.exs' (21 files):
  • test/raxol/core/runtime/plugins/manager_test.exs
  • test/raxol/core/events/manager_test.exs
  • test/raxol/terminal/split/manager_test.exs
  [... more files ...]

🔵 INFO - 'schema.ex' (2 files):
  • lib/raxol/config/schema.ex
  • lib/raxol/terminal/config/schema.ex
```

## Benefits

### Immediate Benefits
- **Improved navigation** - Unique filenames in search results
- **Clearer context** - File names indicate their purpose
- **Better IDE experience** - Autocomplete and quick-open work better
- **Reduced confusion** - Less ambiguity in code discussions

### Long-term Benefits
- **Maintainability** - Easier to locate and update specific functionality
- **Onboarding** - New developers can understand the codebase structure faster
- **Code quality** - Forces thoughtful naming and organization
- **Scalability** - System remains navigable as codebase grows

## Implementation Status

As of v1.2.0:
- ✅ Standalone script implemented
- ✅ Mix task created
- ✅ Credo integration complete
- ✅ Documentation written
- ⏳ Historical duplicates being resolved gradually

## Troubleshooting

### Common Issues

1. **False positives** - Add files to `exclude_files` list
2. **Performance concerns** - Large codebases may take longer to scan
3. **Legacy code** - Use `--exclude` option while refactoring

### Debugging

Enable verbose output:
```bash
mix raxol.check.duplicates --suggest-fixes
```

This will show all duplicates with contextual rename suggestions.

## Contributing

When adding new files:
1. Check if similar functionality exists
2. Use descriptive, contextual names
3. Run duplicate check before committing
4. Consider the navigation impact on other developers

## Future Enhancements

Planned improvements:
- **Auto-fixing** - Automated renaming with reference updates
- **IDE plugins** - Real-time duplicate detection in editors
- **Metrics tracking** - Monitor duplicate reduction over time
- **Smart suggestions** - ML-based naming recommendations