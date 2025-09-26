# ASCII Icon Standards

Standardized ASCII replacements for emojis to maintain professional, terse tone.

## Icon Patterns

Use bracketed notation for consistency:

### Status Icons
- `[OK]` - Success, completed
- `[WARN]` - Warning condition
- `[ERROR]` - Error condition
- `[CRIT]` - Critical condition
- `[INFO]` - Informational

### Action Icons
- `[EDIT]` - Edit action
- `[DEL]` - Delete action
- `[SAVE]` - Save action
- `[LOAD]` - Load action
- `[COPY]` - Copy action

### System Icons
- `[SYS]` - System related
- `[CPU]` - CPU related
- `[MEM]` - Memory related
- `[DISK]` - Disk related
- `[NET]` - Network related

### UI Components
- `[BTN]` - Button
- `[FORM]` - Form
- `[TEXT]` - Text
- `[DATA]` - Data display
- `[CHART]` - Chart/graph
- `[NAV]` - Navigation

### Development
- `[TEST]` - Testing related
- `[BENCH]` - Benchmarking
- `[PERF]` - Performance
- `[BUILD]` - Build process

### Workflow/Process
- `[ANALYSIS]` - Analysis process
- `[REPORT]` - Report generation
- `[REGR]` - Regression
- `[IMPR]` - Improvement

## Guidelines

1. Always use uppercase within brackets
2. Keep icons short (3-6 characters)
3. Use descriptive but concise naming
4. Maintain consistency across the codebase
5. Prefer functional over decorative icons

## Examples

### Before
```
🚀 Running benchmarks...
✅ Tests passed
⚠️ Warning: Memory usage high
🔥 Performance critical
```

### After
```
[BENCH] Running benchmarks...
[OK] Tests passed
[WARN] Memory usage high
[CRIT] Performance critical
```