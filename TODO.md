# Raxol Development Roadmap

**Current Version**: v1.4.1 (Ready for Release)
**Last Updated**: 2025-09-23
**Test Status**: 561 tests | 10 failures (reduced from initial failures!)
**Performance**: Parser 3.3μs/op | Memory <2.8MB | Render <1ms
**Compilation**: ZERO warnings achieved
**Code Quality**: 2976 Credo issues (12 warnings, 743 refactoring, 2196 readability)

## v1.4.1 Release Checklist

- [x] Commit all changes
- [x] Tag v1.4.1 in Git
- [x] Push to GitHub
- [x] Fix all documentation warnings
- [ ] Publish to Hex.pm (run `mix hex.publish` and enter password)

## ✅ ScreenBuffer Refactoring (Completed 2025-09-21)

Successfully refactored the terminal buffer system from 47 files and 12,316 lines to a cleaner, more maintainable architecture:

### Achievements
- **67% reduction in delegation targets**: 12 → 4 modules
- **Simplified call chains**: Max 2 levels (was 4)
- **Two focused sub-modules created**:
  - `ScreenBuffer.Operations`: All buffer modifications (erase, insert, delete, scroll)
  - `ScreenBuffer.Attributes`: All state management (cursor, selection, charset, formatting)
- **Core functions**: `new`, `write_char`, `get_cell` now implemented directly in ScreenBuffer
- **All tests passing**: 18/18 ScreenBuffer tests ✅
- **Clean compilation**: Zero warnings

## v1.4.1 Achievements (Completed)

- ✅ **Zero Warnings**: 88 → 0, full `--warnings-as-errors` compliance
- ✅ **ScreenBuffer Refactoring**: 67% reduction in delegation targets (12 → 4 modules)
- ✅ **Code Quality**: 69% reduction in Credo issues (3,102 → 958)
- ✅ **Dialyzer**: 23% reduction in warnings (1764 → 1355)
- ✅ **Major Features**: Type Spec Generator, TOML Config, Enhanced Debug Mode, SSH Support
- ✅ **Memory Benchmarking**: Complete infrastructure with CI/CD integration

## Current Fix Plan Progress

### Phase 1: Breaking Issues (Mostly Complete)
- [x] Reverted generated specs that caused issues
- [x] Fixed KittyProtocol test failures
- [x] Fixed InteractiveTutorial test failure
- [x] Fixed Table component test failures
- [x] Fixed CursorHandler test failures
- [x] Fixed most integration test failures
- [ ] Fix remaining 10 test failures (mostly dependency manager and view tests)

### Phase 2-6: Planned Improvements
- [ ] Fix dialyzer warnings (785 total)
- [ ] Fix Credo warnings (12 high priority)
- [ ] Refactor complex functions (419 functions)
- [ ] Improve spec generator
- [ ] Final documentation

## v1.4.2 - Next Priorities

### Remaining Technical Debt
- **Dialyzer** (785 warnings - reduced from 1355!):
  - Invalid Contracts: ~100 specs
  - Unmatched Returns: ~100 calls
  - Pattern Matching: ~80 warnings
  - Callback Mismatches: ~40 issues

- **Credo** (2976 issues):
  - Warnings: 12 (high priority - potential bugs)
  - Function Complexity: 419 functions (ABC > 30)
  - Line Length: 172 lines too long
  - Missing Specs: ~200 private functions
  - Nested Functions: ~10 exceed depth limit

### Action Items
1. **Publish v1.4.1** - `mix hex.publish`
2. **Dialyzer fixes** - Target most impactful warnings first
3. **Credo cleanup** - Focus on function complexity and missing specs
4. **Documentation** - Add moduledocs to ~50 modules

## v1.5.0 - Performance & Ecosystem (Next Major Release)

### Performance Targets
- Parser <2.5μs (currently 3.3μs)
- Memory <2MB (currently 2.8MB)
- Render <0.5ms (currently <1ms)
- 120fps capability

### Plugin Ecosystem v2
- Hot-reload capabilities
- Dependency management
- Sandbox security
- Plugin marketplace

### Platform Expansion
- WASM target
- Progressive Web App
- React Native bridge
- iOS/Android native

## v2.0 - Distributed & AI-Enhanced (Q2 2025)

### Distributed Terminal
- Session migration across nodes
- Horizontal scaling
- Cloud-native deployment

### IDE Integration
- JetBrains plugin
- VSCode extension enhancement
- Sublime Text package
- Neovim integration

### AI Features
- Intelligent command completion
- Natural language commands
- Code generation assistant

## Commands Reference

### Testing
```bash
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
```

### Quality Checks
```bash
mix raxol.check              # All checks
mix raxol.gen.specs lib      # Generate type specs
mix dialyzer                 # Type checking
mix credo --strict           # Code quality analysis
```

### Benchmarking
```bash
mix raxol.bench              # Run benchmarks
mix raxol.memory.profiler    # Memory profiling
```

## Development Notes

- Always use `TMPDIR=/tmp` and `SKIP_TERMBOX2_TESTS=true` for tests
- The project has zero compilation warnings - maintain this standard
- All new code should have type specs (use the generator)
- Configuration uses TOML format
- Debug mode available for troubleshooting
- Code quality target: Keep Credo issues under 1000
- Use shared utilities in `lib/raxol/utils/` to avoid duplication
- Follow functional programming patterns (pattern matching over conditionals)