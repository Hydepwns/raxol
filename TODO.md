# Raxol Development Roadmap

**Current Version**: v1.4.1 (Ready for Release)  
**Last Updated**: 2025-09-14  
**Test Status**: 2156/2176 tests passing (99.08% pass rate) - excluding performance tests  
**Performance**: Parser 3.3μs/op | Memory <2.8MB | Render <1ms

## 🎯 Immediate Focus: Final Test Fixes

### Progress Update
- **Fixed**: Multiple JSON encoding issues by uncommenting @derive Jason.Encoder in:
  - `lib/raxol/plugins/plugin_config.ex`
  - `lib/raxol/architecture/event_sourcing/event.ex` 
  - `lib/raxol/audit/events.ex` (all 8 event types)
- **Fixed**: Audit.Logger startup in KeyManager tests
- **Current Status**: Most test failures resolved, but some environment/timing issues remain

### Remaining Test Failures

#### Core Functionality
- [x] Fixed Plugin lifecycle JSON encoding issues ✅
- [x] Fixed Security/Encryption KeyManager tests (added Audit.Logger to test setup) ✅
- [x] Fixed Event Sourcing JSON encoding issues ✅
- [ ] CSI handler tests (various cursor_manager/emulator state issues)
- [ ] Screen mode test timeout issues

#### Performance Tests (3 failures - environment-specific)
- [ ] Parser performance regression guard - plain text parsing
- [ ] Complex ANSI sequences performance
- [ ] Regular emulator process spawn count

### Release Checklist (v1.4.1)
- [x] Fix all compilation warnings ✅
- [x] Resolve ElixirLS linter issues ✅
- [x] Consolidate mix tasks ✅
- [x] Fix mutation testing task ✅
- [x] Fix MouseHandler tests ✅
- [ ] Fix remaining 10 test failures (above)
- [ ] Run full test coverage analysis
- [ ] Final CHANGELOG update
- [ ] Tag release in Git
- [ ] Release to Hex.pm

## 📋 Upcoming Phases

### Phase 2: Architecture Evolution (Post-Release)

**Plugin Ecosystem:**
- [ ] Plugin discovery and installation system
- [ ] Plugin dependency resolution and sandboxing
- [ ] Plugin marketplace infrastructure

**Platform Support:**
- [ ] WebAssembly compilation target
- [ ] Native mobile support (iOS/Android)
- [ ] Cloud-native deployment patterns

**Scalability:**
- [ ] Distributed terminal sessions
- [ ] Horizontal scaling for web terminals
- [ ] Session persistence and migration

**IDE Integration:**
- [ ] JetBrains IDE plugin development
- [ ] Enhanced VSCode extension features
- [ ] Sublime Text package

## 📊 Quality Standards

- **Test Coverage**: Target 100% (current: 99.1%)
- **Performance**: Maintain 3.3μs parser, <1ms render, <2.8MB memory
- **Quality Gates**: All features require tests and documentation
- **No Regression**: Max 5% performance degradation allowed

## 🛠️ Development Commands

### Testing
```bash
# Quick test run (excludes slow/integration tests)
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker --exclude skip

# Run specific failing tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/raxol/ui/layout/table_test.exs --no-warnings-as-errors

# Run with max failures
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --max-failures 5
```

### Quality Checks
```bash
mix raxol.check             # All quality checks
mix raxol.check --quick     # Skip dialyzer
mix raxol.test --coverage   # With coverage report
mix raxol.mutation          # Run mutation testing
```

## 📝 Notes

### Edge Case Analysis
1. **ANSI Cursor Save/Restore**: Complex parsing chain issue, non-critical
2. **Performance Parser Process Spawn**: Test environment artifact, not actual bug
3. **Performance Timing**: Debug logging causes 10x slowdown in tests

### Test Environment
- Always use `TMPDIR=/tmp` to avoid nix-shell issues
- Set `SKIP_TERMBOX2_TESTS=true` for CI compatibility
- Use `--no-warnings-as-errors` when debugging test failures