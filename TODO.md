# Raxol Development Roadmap

**Current Version**: v1.4.1 (Ready for Release)
**Last Updated**: 2025-09-17
**Test Status**: 2134 tests | 99.8% pass rate
**Performance**: Parser 3.3μs/op | Memory <2.8MB | Render <1ms
**Compilation**: ZERO warnings achieved
**Code Quality**: 958 Credo issues (69% reduction from 3,102)

## v1.4.1 Release Checklist

- [x] Commit all changes
- [x] Tag v1.4.1 in Git
- [x] Push to GitHub
- [x] Fix all documentation warnings
- [ ] Publish to Hex.pm (run `mix hex.publish` and enter password)

## v1.4.1 Achievements

### Zero Warnings Milestone
- Reduced compilation warnings from 88 → 0
- Full `--warnings-as-errors` compliance
- All undefined functions resolved
- All unused variables fixed

### Major Features Added
- **Type Spec Generator**: Automated type specification for 12,000+ functions
- **Unified TOML Config**: Runtime configuration with hot-reload
- **Enhanced Debug Mode**: Four-level debugging with profiling
- **SSH Implementation**: Full keepalive and signal handling support

### Memory Benchmarking Infrastructure (Complete)
- 4-phase implementation completed
- 17 new files, 6,247+ lines of code
- Full CI/CD integration
- Interactive profiling tools

### Code Quality Improvements (2025-09-17)
- **Credo Issues**: Reduced from 3,102 to 958 (69% reduction)
- **Warnings**: Eliminated all 7 critical warnings
- **Readability**: 91% reduction (2,202 → 199 issues)
- **Design Issues**: 26% reduction (35 → 26 issues)
- **Refactoring**: 15% reduction (858 → 733 opportunities)

### Technical Debt Addressed
- **Created Utility Modules**:
  - `Raxol.Utils.ColorConversion` - Centralized color operations
  - `Raxol.Utils.MemoryFormatter` - Unified memory formatting
  - `Raxol.Test.SharedUtilities` - Eliminated test duplication
- **Refactored Complex Functions**: Reduced ABC complexity in 10+ functions
- **Optimized Operations**: Replaced inefficient list operations
- **Fixed Patterns**: Converted `Enum.map |> Enum.join` to `Enum.map_join`
- **Cleaned Up**: Removed obsolete TODO comments and dead code

## v1.4.2 - Code Quality Progress (In Development)

### Recent Improvements (2025-09-17)
- **Enum.map_join Refactoring** (FULLY COMPLETED):
  - Fixed ALL remaining incorrect Enum function patterns
  - Corrected 20+ files with improper Enum.map/3, Enum.filter/3, Enum.reduce/4 usage
  - Achieved ZERO compilation warnings
  - Properly converted to Enum.map_join where appropriate
  - Fixed syntax error in property test file
- **Test Utilities Enhanced**:
  - Added 9 new helper functions to `Raxol.Test.SharedUtilities`
  - Improved test maintainability and reduced duplication
- **Module Documentation**: Started adding missing moduledocs

### Remaining Credo Issues to Address
- **Function Complexity**: ~50 functions with ABC > 30
- **Missing Specs**: ~200 private functions need @spec
- **Nested Functions**: ~10 functions exceed depth limit
- **Long Pipelines**: Several could be broken down
- **Duplicate Code**: ~20 smaller duplications remain

### Next Quick Wins
- ✅ Convert remaining ~924 `Enum.map |> Enum.join` patterns (COMPLETED 2025-09-17)
  - Fixed incorrect Enum function arities across 20+ files
  - Properly converted patterns to Enum.map_join
  - Zero compilation warnings achieved
- Add moduledocs to ~50 remaining modules
- Simplify deeply nested conditionals
- Extract remaining test pattern duplications

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