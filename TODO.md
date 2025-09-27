# Development Roadmap

**Version**: v1.5.4 ✅ COMPLETED → v1.5.5 (NEXT)
**Updated**: 2025-09-26
**Tests**: 793/793 passing (100% success rate)
**Performance**: Parser 0.17-1.25μs | Render 265-283μs
**Status**: READY FOR v1.5.4 RELEASE
**Next**: v1.5.5 Quality & Performance

## v1.5.4 - Code Consolidation ✅ COMPLETED

### ✅ All Issues Resolved
- **Charset test failure**: FIXED - Pattern matching reordered in CSIHandler.handle_scs/3
- **Compilation warnings**: FIXED - Zero warnings achieved
- **BaseManager conversions**: ADVANCED - 22+ modules using unified pattern
- **Timer consolidation**: COMPLETED - TimerManager established across core modules
- **Audit.Analyzer**: FIXED - BaseManager conversion with map/keyword support

### Final Changes (2025-09-26)
- **CSIHandler.handle_scs/3**: Fixed charset pattern matching (reordered cases)
- **BaseManager conversions**: 22+ modules converted (Metrics, StateManagementServer, etc.)
- **TimerManager integration**: Core modules using centralized timer management
- **Compilation warnings**: All resolved (zero warnings achieved)
- **Test status**: 793/793 passing (100% success rate)

### v1.5.4 Achievements
- Zero compilation warnings with `--warnings-as-errors`
- Complete test suite passing (793/793)
- Established TimerManager pattern for consistency
- Advanced BaseManager adoption (22% increase)
- Resolved all blocking issues for release

### BaseManager Consolidation Progress
- Created `Raxol.Core.Behaviours.BaseManager` behavior
- Converted 19 modules to BaseManager pattern (7 new today):
  - Terminal.SessionManager (converted)
  - Terminal.MemoryManager (converted)
  - Terminal.Sync.Manager (converted)
  - Core.Runtime.Plugins.PluginManager (already using)
  - Core.Events.EventManager (already using)
  - Plugins.Manager (already using)
  - Terminal.Cursor.CursorManager (already using)
  - Terminal.UnifiedManager (already using)
  - Performance.EtsCacheManager (already using)
  - Terminal.Cursor.OptimizedCursorManager (already using)
  - Core.State.UnifiedStateManager (already using)
  - Core.Config.UnifiedConfigManager (already using)
  - Audit.Logger (converted today)
  - Audit.Storage (converted today)
  - Audit.Analyzer (converted today)
  - Audit.Exporter (converted today)
  - Debug (converted today)
  - Minimal (converted today)
- 69 modules remaining for conversion

### Future Consolidation
- Complete BaseManager conversion (69 remaining modules)
- Logger standardization (791+ calls)
- Timer consolidation (created TimerManager, 3 modules updated, 81+ patterns remaining)

### v1.5.3 - Major Consolidation
- Eliminated duplicate filenames
- Created base behaviors
- Unified state/config systems
- Consolidated error handling
- Reduced duplication

## v1.5.2 - Test Fixes

### Fixes
- VT100 screen clearing on DECCOLM changes
- Scroll region calculations
- CSI handler timeouts
- Plugin dependency parsing
- Audit signature verification (tests)
- Test state isolation
- All tests passing (793/793)

## Previous Versions

### v1.5.1 - Critical Fixes
- 5 test failures resolved
- CSI handlers, plugin dependencies fixed

### v1.5.0 - Plugin System v2.0
- Hot-reload capabilities
- Sandbox security
- WASM support

### v1.4.1 - Quality
- 99.4% test success rate
- Type spec generation
- TOML configuration

### v1.4.0 - Performance
- Parser: <1.25μs/op
- Render: <300μs
- Memory: <2.8MB/session

## Next Priorities

## v1.5.5 Hotfix - Fly.io Deployment Issues (URGENT)

### Critical Issue: Terminal Driver Crashes in Container Environment
**Status**: In Progress
**Impact**: Phoenix app crashes on Fly.io with "Runtime terminating during boot"
**Root Cause**: Raxol terminal driver attempts to access TTY devices that don't exist in Docker containers

### Required Fixes

#### 1. Application Environment Detection
**File**: `lib/raxol/application.ex`
```elixir
# Modify get_terminal_driver_children/0 to detect Fly.io environment
defp get_terminal_driver_children do
  case {IO.ANSI.enabled?(), System.get_env("FLY_APP_NAME"), System.get_env("RAXOL_MODE")} do
    {_, _, "minimal"} -> []
    {_, fly_app, _} when is_binary(fly_app) -> []
    {true, _, _} -> [{Raxol.Terminal.Driver, nil}]
    _ -> []
  end
end
```

#### 2. Conditional NIF Compilation
**File**: `lib/termbox2_nif/termbox2_nif.ex`
```elixir
# Add compile-time flag for headless mode
if System.get_env("RAXOL_HEADLESS") != "true" do
  @on_load :load_nif
  def load_nif do
    # NIF loading logic
  end
else
  # Stub functions for headless mode
  def init(), do: {:ok, :headless}
  def shutdown(), do: :ok
end
```

#### 3. Web-Specific Application Configuration
**File**: `web/lib/raxol_playground/application.ex`
```elixir
# Remove Raxol dependency or make it conditional
defp deps do
  base_deps = [
    {:phoenix, "~> 1.8.0"},
    # ... other deps
  ]

  if System.get_env("INCLUDE_RAXOL") == "true" do
    base_deps ++ [{:raxol, path: "../", runtime: false}]
  else
    base_deps
  end
end
```

#### 4. Graceful Degradation Strategy
- Create `Raxol.Headless` module for web deployments
- Implement mock terminal functions for demos
- Use JavaScript terminal emulator for web UI
- Separate core logic from terminal I/O

### Testing Strategy

#### Local Container Testing
```bash
# Build and test locally before deploying
docker build -f docker/Dockerfile.web -t raxol-web:test .
docker run -p 4000:8080 -e SECRET_KEY_BASE=$(mix phx.gen.secret) raxol-web:test

# Test with production config
docker run -p 4000:8080 \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e PHX_HOST=localhost \
  -e PORT=8080 \
  -e RAXOL_MODE=minimal \
  raxol-web:test
```

#### Fly.io Deployment Testing
```bash
# Set required secrets
fly secrets set RAXOL_MODE=minimal RAXOL_FORCE_TERMINAL=false -a raxol

# Deploy with verbose logging
fly deploy -a raxol --verbose

# Debug crashed instances
fly ssh console -a raxol
cat /app/erl_crash.dump | head -100
/app/bin/raxol_playground foreground

# Monitor logs
fly logs -a raxol --tail
```

### Implementation Timeline
1. **Day 1**: Environment detection fixes
2. **Day 2**: Conditional compilation implementation
3. **Day 3**: Testing and validation
4. **Day 4**: Documentation and deployment

### Success Criteria
- [ ] Phoenix app starts without crashes on Fly.io
- [ ] Web interface accessible at raxol.fly.dev
- [ ] No terminal driver errors in production logs
- [ ] Graceful fallback for terminal features
- [ ] Docker image builds successfully
- [ ] Local container testing passes

### Alternative Deployment Strategies

#### Option A: Separate Web and Terminal Apps
- Split into two separate applications
- `raxol` - Core terminal library
- `raxol_web` - Phoenix web interface
- Deploy only web app to Fly.io
- Advantages: Clean separation, easier maintenance
- Disadvantages: Code duplication, sync challenges

#### Option B: Runtime Feature Detection
- Single codebase with runtime switching
- Detect environment at startup
- Load appropriate modules dynamically
- Advantages: Single source of truth
- Disadvantages: Complex configuration

#### Option C: Build-Time Configuration
- Use Mix configs to exclude terminal features
- Separate release configurations
- `MIX_ENV=prod_web` for web deployments
- Advantages: Smaller deployment size
- Disadvantages: Multiple build configurations

### Recommended Approach
**Option B + Gradual Migration to Option A**
1. Implement runtime detection (immediate fix)
2. Plan separation into distinct apps (long-term)
3. Create shared library for common code
4. Maintain backward compatibility

## v1.5.5 - Quality & Performance (AFTER HOTFIX)

### Priority Actions
1. **Complete BaseManager conversions** (150+ modules remaining)
   - Target: 75+ modules converted (250% increase)
   - Focus on high-impact modules first:
     - Core managers (state, config, event)
     - UI rendering pipeline modules
     - Terminal operations modules
     - Performance monitoring modules

2. **Complete timer consolidation** (64+ lib files remaining)
   - Target: 90% of timer patterns using TimerManager
   - Automated conversion script for batch processing
   - Standardize all `:timer.send_interval` and `Process.send_after` usage

3. **Logger standardization** (791+ calls)
   - Create `Raxol.Core.Utils.Logger` wrapper
   - Standardize log levels and formatting
   - Add structured logging with metadata

4. **Achieve 100% test coverage** (currently 98.7%)
   - Identify uncovered code paths
   - Add property-based tests for critical functions
   - Improve integration test coverage

5. **Performance regression testing**
   - Automated CI performance gates
   - Benchmark tracking and alerting
   - Memory leak detection

### Quality Gates for v1.5.5
- [ ] Zero compilation warnings (maintained)
- [ ] 100% test success rate (maintained)
- [ ] 100% test coverage (target)
- [ ] 75+ BaseManager conversions (target)
- [ ] 90% timer consolidation (target)
- [ ] Performance within 5% of v1.5.4 baselines

### Implementation Plan

#### Phase 1: Foundation (Week 1)
- Complete remaining timer consolidation (64 files)
- Convert 25+ high-impact modules to BaseManager
- Set up automated performance monitoring

#### Phase 2: Standardization (Week 2)
- Logger standardization across codebase
- Convert 25+ additional modules to BaseManager
- Improve test coverage to 99.5%

#### Phase 3: Quality (Week 3)
- Final BaseManager conversions (25+ modules)
- Achieve 100% test coverage
- Performance optimization and regression testing

#### Phase 4: Release (Week 4)
- Final testing and validation
- Documentation updates
- Release preparation

### Automation Tools for v1.5.5

#### BaseManager Conversion Script
```bash
# Automated conversion of GenServer modules to BaseManager
mix raxol.convert.base_manager lib/path/to/module.ex
mix raxol.convert.base_manager lib --batch --dry-run
```

#### Timer Consolidation Script
```bash
# Automated timer pattern conversion
mix raxol.convert.timers lib/path/to/module.ex
mix raxol.convert.timers lib --batch --validate
```

#### Logger Standardization
```bash
# Logger usage analysis and conversion
mix raxol.standardize.logger lib --report
mix raxol.standardize.logger lib --convert
```

#### Quality Gates Integration
```bash
# Automated quality checks for CI
mix raxol.quality.gates --coverage --warnings --performance
mix raxol.quality.report --format json
```

## Current Development - v1.6.0

### v1.6.0 - Plugin Ecosystem
**Status**: In Progress

**Completed Plugins**:
- Command Palette Plugin - Command execution with fuzzy search
- Status Line Plugin - System info and status bar
- File Browser Plugin - Tree navigation with file operations
- Terminal Multiplexer Plugin - Pane and window management
- Rainbow Theme Plugin

**Todo**:
- Git Integration Plugin
- Plugin Development Guide
- Plugin Testing Framework
- Plugin Marketplace UI
- Plugin Templates

## Future Versions

### v2.0 - Platform Expansion (Q2 2025)
- WASM production
- PWA
- Mobile support
- Cloud deployment

### Long-term
- Distributed sessions
- AI completion
- IDE integrations
- Natural language

## Commands Reference

### Testing
```bash
# Standard test run
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

# Run failed tests only
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --failed --max-failures 10

# Run specific test files
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/path/to/file.exs

# Quick test status
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
```

### Development
```bash
# Compile
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile --warnings-as-errors

# Code quality
mix raxol.check
mix format

# Type specs
mix raxol.gen.specs lib --dry-run

# Benchmarks
mix raxol.bench
```

## Development Notes

- Use `TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true`
- Zero Credo warnings
- Type specs required
- Functional patterns
- TOML configuration
- No emojis