# Raxol Roadmap

**Version**: 1.2.0 Development
**Last Updated**: 2025-09-11

## Current Sprint: Advanced Checks & Metrics (Phase 5-6)

### In Progress
- [x] Dialyzer integration with PLT caching - Complete with enhanced mix tasks & CI integration
- [x] Security scanning for vulnerabilities - Sobelow & mix_audit integrated with custom task
- [ ] Performance metrics tracking
- [x] CI/CD integration with GitHub Actions - Multiple workflows already configured

## Completed Milestones

### v1.1.0 Released + Sprints 22-29
- **Functional Programming**: 97.1% try/catch reduction, 99.9% if elimination
- **Codebase Cleanup**: 154+ duplicates → 0, standardized naming
- **Pre-commit System**: 92x speedup (5.7s → 62ms), caching, config system
- **Developer Experience**: Progress indicators, enhanced errors, hook management
- **Test Coverage**: 98.7% maintained, all accessibility tests passing

## Next Sprint Options

### Next: v1.2.0 Release
- [x] Address remaining process-based tests (~10) - Fixed CommandHelper & Web.Supervisor tests
- [x] Fix Parser module reference warning
- [ ] Update CHANGELOG
- [ ] Release to Hex.pm

### Future: v2.0.0 Planning
- [ ] Breaking changes evaluation
- [ ] Architecture improvements
- [ ] Performance optimizations
- [ ] Enterprise features

## Technical Debt

### Recently Completed (Sprint 27)
- [x] Process dictionary migration (20 files) - Migrated to ProcessStore
- [x] Generated config consolidation - Unified configuration system  
- [x] Archive development scripts - 20 scripts organized into archived/

### Performance Targets
- Parser: 3.3μs/operation ✓
- Render: <1ms full screen ✓
- Memory: 2.8MB baseline ✓
- Throughput: 10K ops/sec ✓

## Quick Links

- [Development Guide](docs/development.md)
- [API Reference](docs/api-reference.md)
- [Quick Reference](docs/QUICK_REFERENCE.md)
- [ADRs](docs/adr/)