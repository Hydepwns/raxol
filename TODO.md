# Raxol Development Roadmap

**Current Version**: v1.4.1 (Ready for Release)
**Last Updated**: 2025-09-16
**Test Status**: 2134 tests | 99.8% pass rate
**Performance**: Parser 3.3μs/op | Memory <2.8MB | Render <1ms
**Compilation**: ZERO warnings achieved

## v1.4.1 Release Checklist

- [ ] Commit all changes
- [ ] Tag v1.4.1 in Git
- [ ] Push to GitHub
- [ ] Publish to Hex.pm

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

### Memory Benchmarking Infrastructure (Complete)
- 4-phase implementation completed
- 17 new files, 6,247+ lines of code
- Full CI/CD integration
- Interactive profiling tools

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